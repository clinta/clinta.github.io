---
layout: post
title: Ubuntu Semi-Automated Installation with PXE, Preseeds and Apt-Cacher-NG
---

Doing repetitive installs can be a pain, and figuring out how to make it easier can be even more of a pain since everybody has their own preferred system. Most searching for how to do this for Ubuntu will lead you to Cobbler. Cobbler isn't a bad tool, but it's not a good fit for me. It basically precludes any customization to pxelinux without doing so using their templating language. And it is built with the assumption that you'll be defining system roles and doing configuration management through Cobbler. I don't need that, I'm using Salt for configuration management. For unattended installations I need something simpler. Putting together a few simple tools I was able to get an installation system I'm very happy with.

Another complication that's not addressed in most existing guides is getting this to work with both BIOS and EFI based computers. Ignoring EFI and setting everything to boot in legacy mode isn't a long term solution, and not one I'm willing to accept.

The first thing we need is a tftp server. 

```bash
root@tftp-svr:~# apt-get install tftpd-hpa
```

Now we need syslinux. Syslinux contains a set of kernels that can be downloaded via tftp and booted by the client. It's really just a set of files, no services that will be run, so I'll be skipping the normal ubuntu syslinux packages and getting the latest and greatest from the source.

```bash
root@tftp-svr:~# wget https://www.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz
root@tst-pxe1:~# tar -xvf syslinux-6.03.tar.gz
```

Now create some directories and copy the necessary syslinux files to the tftp root directory. Since we're wanting to boot legacy bios clients and x64 based EFI clients. Technically 32 bit EFI clients might exist, but I don't have any, so I'm not bothering to configure those. 

```bash
mkdir /var/lib/tftpboot/bios
cp syslinux-6.03/bios/core/pxelinux.0 /var/lib/tftpboot/bios/
cp syslinux-6.03/bios/com32/elflink/ldlinux/ldlinux.c32 /var/lib/tftpboot/bios/
cp syslinux-6.03/bios/com32/lib/libcom32.c32 /var/lib/tftpboot/bios/
cp syslinux-6.03/bios/com32/libutil/libutil.c32 /var/lib/tftpboot/bios/
cp syslinux-6.03/bios/com32/menu/vesamenu.c32 /var/lib/tftpboot/bios/
syslinux-6.03/bios/com32/modules/pxechn.c32 /var/lib/tftpboot/bios/
```

```bash
mkdir /var/lib/tftpboot/efi64
cp syslinux-6.03/efi64/efi/syslinux.efi /var/lib/tftpboot/efi64/
cp syslinux-6.03/efi64/com32/elflink/ldlinux/ldlinux.e64 /var/lib/tftpboot/efi64/
cp syslinux-6.03/efi64/com32/lib/libcom32.c32 /var/lib/tftpboot/efi64/
cp syslinux-6.03/efi64/com32/libutil/libutil.c32 /var/lib/tftpboot/efi64/
cp syslinux-6.03/efi64/com32/menu/vesamenu.c32 /var/lib/tftpboot/efi64/
cp syslinux-6.03/efi64/com32/modules/pxechn.c32/var/lib/tftpboot/efi64/
```

Now that our boot kernels are in place, configure DHCP to pass the kernel to the clients. This can be tricky, and the method will depend on your DHCP server. When a client sends a DHCP request, it includes information about itself. Option 93 includes the architecture of the client. 0 indicates a bios client, 9 and 7 indicate a 64 bit EFI client. 6 identifies an ia64 client, but I don't have any of those either. Using the DHCP templates provided on the [syslinux wiki](http://www.syslinux.org/wiki/index.php/PXELINUX#UEFI), I've customized my DHCP server.

```
# /etc/dhcp/dhcpd.conf
authoritative;
option architecture-type code 93 = unsigned integer 16;
subnet 192.168.1.0 netmask 255.255.255.0 {
  ##
  ## … All your normal DHCP options go here
  ##
  option tftp-server-name "192.168.1.1";                        # The IP address of the tftp server
  next-server 192.168.1.1;                                      # IP Address of the tftp server again
  # Below are the conditions to send the correct kernel depending on if the client is EFI or not.
  if option architecture-type = 00:00 {
   filename "bios/pxelinux.0";
   } elsif option architecture-type = 00:09 {
   filename "efi64/syslinux.efi";                               
   } elsif option architecture-type = 00:07 {
   filename "efi64/syslinux.efi";
   } else {
   filename "bios/pxelinux.0";
  }
}
```

With this in place, our clients can now pxe boot, but they'll just boot to a blank screen and do nothing. They need a configuration to tell them what to do. pxelinux looks for a configuration file in the pxelinux.cfg directory. You can create configuration files for individual machines by creating files with a fliename that matches the MAC address of the booting client. Any client that doesn't have a matching config will use the default file. In this example, we're just going to make the default file.

```bash
mkdir /var/lib/tftpboot/bios/pxelinux.cfg
```

Edit the file `/var/lib/tftpboot/bios/pxelinux.cfg/default`.

```
# /var/lib/tftpboot/bios/pxelinux.cfg/default
DEFAULT vesamenu.c32
TIMEOUT 600
ONTIMEOUT BootLocal
PROMPT 0
MENU TITLE PXE Menu
NOESCAPE 1
LABEL BootLocal
  localboot 0
  TEXT HELP
  Boot to the local hard disk
  ENDTEXT
```

I haven't found a nice way to make tftpd-hpa follow symlinks, so this directory must be copied both to the bios and the efi directory.

```bash
cp -r /var/lib/tftpboot/bios/pxelinux.cfg /var/lib/tftpboot/efi64
```

Now try and PXE boot. You will get a sparse menu with only one option. We'll be adding more later. Right now the only option in the menu is to continue booting to the local disk. If you wish to take a break to customize the look of this menu, you can do so by customizing options like `MENU BACKGROUND` and `MENU COLOR`. Read more about these options on the [syslinux wiki](http://www.syslinux.org/wiki/index.php/Menu#MENU_COLOR).

Now it's time to add the Ubuntu mini CD. I like to stick with LTS releases of Ubuntu, which means that the normal server ISO will have packages that are 2 years old by the time it's replaced. This makes them almost useless as the first apt-get upgrade will download nearly as much as the original ISO had on it in the first place. The mini iso contains only what's necessary to boot, then pulls all the packages from the internet. This would make the installation pretty slow, but we're going to supercharge it with an Apt Cache later on in this guide.

Grab the mini ISO and extract the files into your tftpboot directory. I choose to maintain a pretty strict hierarchy so that I can add more distributions later.

```bash
wget -o ubuntu-14.04-x64-mini.iso http://archive.ubuntu.com/ubuntu/dists/trusty/main/installer-amd64/current/images/netboot/mini.iso
mkdir /mnt/iso
mount ubuntu-14.04-x64-mini.iso /mnt/iso
mkdir -p /var/lib/tftpboot/images/ubuntu/14.04/
cp -r /mnt/iso /var/lib/tftpboot/images/ubuntu/14.04/amd64
```

Now we can add an option to our PXE Configuraiton to boot to this image.

```
# /var/lib/tftpboot/bios/pxelinux.cfg/default
DEFAULT vesamenu.c32
TIMEOUT 600
ONTIMEOUT BootLocal
PROMPT 0
MENU TITLE PXE Menu
NOESCAPE 1
LABEL BootLocal
  localboot 0
  TEXT HELP
  Boot to the local hard disk
  ENDTEXT
LABEL Ubuntu 14.04 (64-bit)
  KERNEL tftp://192.168.1.1/images/ubuntu/14.04/amd64/linux
  TEXT HELP
  Boot to the Ubuntu 14.04 64-bit automatic installation
  ENDTEXT
```

At this point you can PXE boot and run an interactive installation using the mini installer. The system will be installed fully up to date, with all packages pulled direct from the internet. All the installer questions will be asked normally just like if you had booted from the CD.

```
# /var/lib/tftpboot/bios/pxelinux.cfg/default
DEFAULT vesamenu.c32
TIMEOUT 600
ONTIMEOUT BootLocal
PROMPT 0
MENU TITLE PXE Menu
NOESCAPE 1
LABEL BootLocal
  localboot 0
  TEXT HELP
  Boot to the local hard disk
  ENDTEXT
LABEL Ubuntu 14.04 (64-bit)
  KERNEL tftp://192.168.1.1/images/ubuntu/14.04/amd64/linux
  APPEND auto=true priority=high vga=788 initrd=tftp://192.168.1.1/images/ubuntu/14.04/amd64/initrd.gz locale=en_US.UTF-8 kdb-chooser/method=us netcfg/choose_interface=auto url=tftp://192.168.1.1/preseed/ubuntu-14.04.preseed
  TEXT HELP
  Boot to the Ubuntu 14.04 64-bit automatic installation
  ENDTEXT
```
