---
layout: post
title: Automated Ubuntu Installation with PXE, Preseeds and Apt-Cacher-NG (and UEFI compatible)
date: 2015-01-28 09:13:00
aliases:
  - /posts/2015-01-28-Automated-PXE-Ubuntu-Installs
  - /posts/2015-1-28-Automated-PXE-Ubuntu-Installs
---

Doing repetitive installs can be a pain, and figuring out how to make it easier can be even more of a pain since everybody has their own preferred system. Most searching for how to do this for Ubuntu will lead you to Cobbler. Cobbler isn't a bad tool, but it's not a good fit for me. It takes away most of the ability to customize pxelinux without learning their templating language. And it is built with the assumption that you'll be defining system roles and doing configuration management through Cobbler. I don't need that, I'm using Salt for configuration management. For unattended installations I need something simpler. Putting together a few simple tools I was able to get an installation system I'm very happy with.

Another complication that's not addressed in most existing guides is getting this to work with both BIOS and EFI based computers. Ignoring EFI and setting everything to boot in legacy mode isn't a long term solution, and not one I'm willing to accept.

The first thing we need is a tftp server. 

```bash
apt-get install tftpd-hpa
```

Now we need syslinux. Syslinux contains a set of kernels that can be downloaded via tftp and booted by the client. It's really just a set of files, no services that will be run, so I'll be skipping the normal ubuntu syslinux packages and getting the latest and greatest from the source.

```bash
wget https://www.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz
tar -xvf syslinux-6.03.tar.gz
```

Now create some directories and copy the necessary syslinux files to the tftp root directory. Since we're wanting to boot legacy bios clients and x64 based EFI clients. Technically 32 bit EFI clients might exist, but I don't have any, so I'm not bothering to configure those. 

```bash
mkdir /var/lib/tftpboot/bios
cp syslinux-6.03/bios/core/pxelinux.0 /var/lib/tftpboot/bios/
cp syslinux-6.03/bios/com32/elflink/ldlinux/ldlinux.c32 /var/lib/tftpboot/bios/
cp syslinux-6.03/bios/com32/lib/libcom32.c32 /var/lib/tftpboot/bios/
cp syslinux-6.03/bios/com32/libutil/libutil.c32 /var/lib/tftpboot/bios/
cp syslinux-6.03/bios/com32/menu/vesamenu.c32 /var/lib/tftpboot/bios/
cp syslinux-6.03/bios/com32/modules/pxechn.c32 /var/lib/tftpboot/bios/
```

```bash
mkdir /var/lib/tftpboot/efi64
cp syslinux-6.03/efi64/efi/syslinux.efi /var/lib/tftpboot/efi64/
cp syslinux-6.03/efi64/com32/elflink/ldlinux/ldlinux.e64 /var/lib/tftpboot/efi64/
cp syslinux-6.03/efi64/com32/lib/libcom32.c32 /var/lib/tftpboot/efi64/
cp syslinux-6.03/efi64/com32/libutil/libutil.c32 /var/lib/tftpboot/efi64/
cp syslinux-6.03/efi64/com32/menu/vesamenu.c32 /var/lib/tftpboot/efi64/
cp syslinux-6.03/efi64/com32/modules/pxechn.c32 /var/lib/tftpboot/efi64/
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

With this in place, our clients can now pxe boot, but they'll just get an error saying that the configuraiton file can't be found. They need a configuration to tell them what to do. pxelinux looks for a configuration file in the pxelinux.cfg directory. You can create configuration files for individual machines by creating files with a fliename that matches the MAC address of the booting client. Any client that doesn't have a matching config will use the default file. In this example, we're just going to make the default file.

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
wget -O ubuntu-14.04-x64-mini.iso http://archive.ubuntu.com/ubuntu/dists/trusty/main/installer-amd64/current/images/netboot/mini.iso
mkdir /mnt/iso
mount ubuntu-14.04-x64-mini.iso /mnt/iso
mkdir -p /var/lib/tftpboot/images/ubuntu/14.04/
cp -r /mnt/iso /var/lib/tftpboot/images/ubuntu/14.04/amd64
umount /mnt/iso
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
  APPEND vga=788 initrd=tftp://192.168.1.1/images/ubuntu/14.04/amd64/initrd.gz
  TEXT HELP
  Boot to the Ubuntu 14.04 64-bit automatic installation
  ENDTEXT
```

At this point you can PXE boot and run an interactive installation using the mini installer. The system will be installed fully up to date, with all packages pulled direct from the internet. All the installer questions will be asked normally just like if you had booted from the CD.

Next step is to begin automating the installation. In Debian and Ubuntu, automation is done via preseed files. This [example](https://help.ubuntu.com/lts/installation-guide/example-preseed.txt) is fairly well documented in the comments and will serve as a good starting point. Start by putting this file in your tftp directory.

```bash
mkdir /var/lib/tftpboot/preseeds
wget -O /var/lib/tftpboot/preseeds/ubuntu.preseed https://help.ubuntu.com/lts/installation-guide/example-preseed.txt
```

Edit this preseed file to your liking, using the in-line comments as a guide. I modified mine to do things like use normal partitioning rather than lvm, I commented out the hostname parameter to make the installer prompt for a hostname, and I set the tasksel property to none, then put openssh-server and salt-minion as additional packages to install.

Once you have this file configured as you like it, you need to modify your PXE options so that it will be used. Notice the append line added below.

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
  APPEND auto=true priority=high vga=788 initrd=tftp://192.168.1.1/images/ubuntu/14.04/amd64/initrd.gz locale=en_US.UTF-8 kdb-chooser/method=us netcfg/choose_interface=auto url=tftp://192.168.1.1/preseeds/ubuntu.preseed
  TEXT HELP
  Boot to the Ubuntu 14.04 64-bit automatic installation
  ENDTEXT
```

Notice a couple of things here. The first thing added is `auto=true`, this is what tells the installer to attempt to automatically complete. `priority=high` instructs the installer to skip asking any questoins with a priority of less than high. Many guides will instruct adding `priority=critical` which will only ask questions that the installer cannot possibly complete without. I choose high, because I want to be prompted for a hostname by the installer, and that is not a critical priority question. The locale must be passed to the kernel, because the locale and keyboard layout is asked before the preseed is actually downloaded. `netcfg/choose_interface=auto` should not be necessary if the same parameter is specified in the preseed file, but due to a [bug](https://bugs.launchpad.net/ubuntu/+source/netcfg/+bug/713385), this property only works if passed as a kernel option. And lastly `url=tftp://192.168.1.1/preseeds/ubuntu.preseed` is the tftp path to the preseed file you just customized.

At this point you now have either a fully or semi-automated pxe installer for Ubuntu. However, because we're using the mini cd, it's probably a fair bit slower that you'd like, pulling packages from the internet for every install. Now it's time to setup your apt proxy to speed this up.

In this demo I'm going to install it on the same server that is doing DHCP, but this can be on any server you want. Start by installing apt-cacher-ng.

```bash
apt-get install apt-cacher-ng
```

After install apt-cacher-ng will be running automatically on port 3142. You can visit http://<apt-cacher-ip>:3142 for instructions on configuring apt, as well as a link to view the cache statistics. To use this for during the install process, you need to add a line to your preseed configuration.

```
# /var/lib/tftpboot/preseeds/ubuntu.preseed
[...]
d-i mirror/http/proxy string http://192.168.1.1:3142/
```

If you watch the statistics page while doing another install, you'll notice an almost 100% miss rate. But once you do the second install it will go much faster and you'll see more packages hitting the cache. Now that you have a cache setup, you should probably follow the instructions for configuring your clients to utilize it for faster updates.

Now is when I ran into one more [bug](https://bugs.launchpad.net/ubuntu/+source/debian-installer/+bug/568704) that frustrated things though. While this setting should only be setting a proxy for apt, it sets the proxy for all http, which means if you use any scripts in your preseed file that require http, they will be proxied and probably will not work. One place I had to work around this was adding a PPA as a source for an additional package to be installed. Because the signing key could not be pulled over http, I had to download the key and serve it via tftp.

At this point you should have a fairly robust system for performing Ubuntu installations via PXE.

One last tip is how to add entries for other PXE servers you may have on your network. Perhaps a Windows Deployment server, or a FOG server. To enable chain booting you can add these simple menu entries to your `pxelinux.cfg/default` file.

```
LABEL Fog
  COM32 pxechn.c32
  APPEND 192.168.1.2::/pxelinux.0
```
