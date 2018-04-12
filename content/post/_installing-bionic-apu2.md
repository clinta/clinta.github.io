---
layout: single
title: Installing Ubuntu 18.04 on an APU2
date: 2018-04-12
slug: bionic-on-apu2
draft: true
---

The [PC Engines APU2](https://www.pcengines.ch/apu2.htm) is a great little board
to build a router on. We've used several of them at work for branch offices, and
I'm using one for my home router now.

But with no video, these devices can be a bit intimidating to get setup for a
new user. This guide will take you step-by-step through updating the firmware
and installing Ubuntu 18.04 on one.

Before installing any software make sure you assemble the APU2 properly, pay
special attention to how you install the CPU cooler. Follow the instructions at
 https://www.pcengines.ch/apucool.htm.

Once your box is built, get your serial cable plugged in and fire up putty. Set
your serial console speed to 115200.

Download the latest firmware from https://pcengines.github.io/ and download
tinycorelinux from http://pcengines.ch/howto.htm#bios
http://pcengines.ch/howto.htm#TinyCoreLinux.

Extract the tinycore image and copy it to a usb drive. For this guide I'm using
a linux workstation to setup the USB drive which is /dev/sdb. Double check your
own drive before proceeding.

```console
$ gunzip apu2-tinycore6.4.img.gz
$ sudo dd if=apu2-tinycore6.4.img of=/dev/sdb bs=1M
```

Now you need to mount the drive and add the bios files to it.

```console
$ sudo mkdir /dev/usb
$ sudo mount /dev/sdb /mnt/usb
$ cd /mnt/usb
$ sudo tar -xvf ~/Downloads/apu2_v4.6.7.rom.tar.gz
$ cd ~
$ sudo umount /mnt/usb
$ sync
```

Now you can plug the usb drive into your apu2 and boot it up. In your putty
terminal you should see the boot up to tinycorelinux. In that shell you can use
flashrom to update the bios on your apu2.

```console
# cd /media/SYSLINUX
# flashrom -w path_to_bios.rom -p internal
```

At this point you may get an error that the board does not match. At some point
the board was renamed from just `APU2` to `PC Engines APU2`. So long as both say
`APU2` it is safe to force a flash by running

```console
# flashrom -w path_to_bios.rom -p internal:boardmismatch=force
```

Once the flash completes you can power down the board and flash the USB drive
with an ubuntu mini install image. Download it from
[here](http://archive.ubuntu.com/ubuntu/dists/bionic/main/installer-amd64/current/images/netboot/boot.img.gz).

Gunzip the image and copy it to the usb drive just like you did with the
tinycorelinux image.

```console
$ gunzip netboot.img.gz
$ sudo dd if=netboot.img of=/dev/sdb bs=1M
$ sudo mount /dev/sdb /mnt/usb
```

Edit `/mnt/usb/txt.cfg` to change the append line

change
```
	append vga=788 initrd=initrd.gz --- quiet 
```

to
```
	append initrd=initrd.gz --- console=tty0 console=ttyS0,115200n8
```

Then unmount and put your usb drive into the apu2.

```console
$ sudo umount /mnt/usb
```

Then mount the usb so that you can edit the grub line and enable the serial
console. Boot your APU2 from this USB drive and you will be greeted with a
familiar ubuntu install.

After installation you can need to re-enable the serial console in the installed
OS. You can do this by executing a shell after the installer runs, or you can
ssh into the APU2 after it reboots into the installed OS. However you do it, you
need to edit `/etc/default/grub`. Make sure these options are set:

```
# /etc/default/grub
GRUB_CMDLINE_LINUX_DEFAULT="console=tty0 console=ttyS0,115200n8"

GRUB_TERMINAL=serial
GRUB_SERIAL_COMMAND="serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1"
```

That's it. In future posts I'll be detailing how to build a great home router
with this little box.
