---
layout: post
title: Ubuntu Semi-Automated Installation with PXE, Preseeds and Apt-Cacher-NG
---

Doing repetitive installs can be a pain, and figuring out how to make it easier can be even more of a pain since everybody has their own preferred system. Most searching for how to do this for Ubuntu will lead you to Cobbler. Cobbler isn't a bad tool, but it's not a good fit for me. It basically precludes any customization to pxelinux without doing so using their templating language. And it is built with the assumption that you'll be defining system roles and doing configuraiton management through Cobbler. I don't need that, I'm using Salt for configuraiton management. For unattended installtions I need something simpler. Putting together a few simple tools I was able to get an installation system I'm very happy with.

Another complicaiton that's not addressed in most existing guides is getting this to work with both BIOS and EFI based computers. Ignoring EFI and setting everything to boot in legacy mode isn't a long term solution, and not one I'm willing to accept.

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

Now that our boot kernels are in place, configure DHCP to pass the kernel to the clients. This can be tricky, and the method will depend on your DHCP server. When a client sends a DHCP request, it includes information about itself. Option 93 includes the arcitecture of the client. 0 indicates a bios client, 9 and 7 indicate a 64 bit EFI client. 6 identifies an ia64 client, but I don't have any of those either. Using the DHCP templates provided on the [syslinux wiki](http://www.syslinux.org/wiki/index.php/PXELINUX#UEFI), I've cusbytomized my dhcp server.

```
# /etc/dhcp/dhcpd.conf
authoritative;
option architecture-type code 93 = unsigned integer 16;
subnet 192.168.1.0 netmask 255.255.255.0 {
  option tftp-server-name "192.168.1.1";                        # The IP address of the tftp server
  next-server 192.168.1.1;                                      # IP Address of the tftp server again
  range 192.168.1.100 192.168.1.200;
  default-lease-time 120;
  option routers 192.168.1.1;
  option ip-forwarding off;
  option broadcast-address 192.168.1.255;
  option subnet-mask 255.255.255.0;
  option domain-name-servers 192.168.137.1;
  next-server 192.168.1.1;
  option domain-name "local.lan";
  option domain-search "local.lan";
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
