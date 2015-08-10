---
layout: post
title: FreeBSD Jails the hard way
date: 2015-08-09
---

There are many great options for managing FreeBSD Jails. iocage, warden and ez-jail aim to streamline the process and make it quick an easy to get going. But sometimes the tools built right into the OS are overlooked.

This post goes over what is involved in creating and managing jails using only the tools built into FreeBSD.

For this guide, I'm going to be putting my jails in `/usr/local/jails`.

I'll start with a very simple, isolated jail. Then I'll go over how to use ZFS snapshots, and lastly nullfs mounts to share the FreeBSD base files with multiple jails.

I'll also show some examples of how to use the templating power of jail.conf to apply similar settings to all your jails.

## Full Jail

1\. Make a directory for the jail, or a zfs dataset if you prefer.

```sh
mkdir -p /usr/local/jails/fulljail1
## or
zfs create -o mountpoint=/usr/local/jails zroot/jails
zfs create zroot/jails/fulljail1
```

2\. Download the FreeBSD base files, and any other parts of FreeBSD you want. In this example I'll include the 32 bit libraries as well.

```sh
fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/10.1-RELEASE/base.txz -o /tmp/base.txz
tar -xvf /tmp/base.txz -C /usr/local/jails/fulljail1
fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/10.1-RELEASE/lib32.txz -o /tmp/lib32.txz
tar -xvf /tmp/lib32.txz -C /usr/local/jails/fulljail1
```

3\. Make sure you jail has the right timezone and dns servers and a hostname in rc.conf.

```sh
cp /etc/resolv.conf /usr/local/jails/fulljail1/etc/resolv.conf
cp /etc/localtime /usr/local/jails/fulljail1/etc/localtime
echo hostname=\"fulljail1\" > /usr/local/jails/fulljail1/etc/rc.conf
```

4\. Edit jail.conf with the details about your jail.

```
# /etc/jail.conf

# Global settings applied to all jails.

exec.start = "/bin/sh /etc/rc";
exec.stop = "/bin/sh /etc/rc.shutdown";
exec.clean;
mount.devfs;

# The jail definition for fulljail1
fulljail1 {
    host.hostname = "fulljail1.domain.local";
    path = "/usr/local/jails/fulljail1";
    interface = "lagg0";
    ip4.addr = 10.0.0.15;
}
```

5\. Start and login to your jail.

```sh
jail -c fulljail1
```

11 commands and a config file, but this is the most tedious way to make a jail. With a little bit of templating it can be even easier. So I'll start by making a template. Making a template is basically the same as steps 1, 2 and 3 above, but with a different destination folder, I'll condense them here.

## Creating a template

1\. Create a template or a ZFS dataset. If you'd like to use the zfs clone method of deploying templates, you'll need to create a zfs dataset instead of a folder.

```sh
mkdir -p /usr/local/jails/templates/10-1-Release
## or 
zfs create -p zroot/jails/templates/10-1-Release

fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/10.1-RELEASE/base.txz -o /tmp/base.txz
tar -xvf /tmp/base.txz -C /usr/local/jails/templates/10-1-Release
fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/10.1-RELEASE/lib32.txz -o /tmp/lib32.txz
tar -xvf /tmp/lib32.txz -C /usr/local/jails/templates/10-1-Release
cp /etc/resolv.conf /usr/local/jails/templates/10-1-Release/etc/resolv.conf
cp /etc/localtime /usr/local/jails/templates/10-1-Release/etc/localtime
```

2\. Optionally, update your template with `freebsd-update`.

```sh
freebsd-update -b /usr/local/jails/tempaltes/10-1-Release fetch
freebsd-update -b /usr/local/jails/tempaltes/10-1-Release install
```

And that's it, now you have a fully up to date jail template. If you've made this template with zfs, you can easily deploy it using zfs snapshots.

## Deploying a template with ZFS snapshots

1\. Create a snapshot. My last freebsd-update to my template brought it to patch level 17, so I'll call my snapshot p17.

```sh
zfs snapshot zroot/jails/templates/10-1-Release@p17
```

2\. Clone the snapshot to a new jail.

```sh
zfs clone zroot/jails/templates/10-1-Release@p17 zroot/jails/zjail1
```

3\. Configure the jail hostname.

```sh
echo hostname=\"zjail1\" > /usr/local/jails/zjail1/etc/rc.conf
```

4\. Add the jail definition to jail.conf, make sure you have the global jail settings from jail.conf listed in the fulljail example.

```
# The jail definition for zjail1
zjail1 {
    host.hostname = "zjail1.domain.local";
    path = "/usr/local/jails/zjail1";
    interface = "lagg0";
    ip4.addr = 10.0.0.16;
}
```

5\. Start the jail.

```sh
jail -c zjail1
```

The downside with the zfs approach is that each jail is now a fully independent, and if you need to update your jails, you have to update them all individually. By sharing a template using nullfs mounts you can have only one copy of the base system that only needs to be updated once.

## Thin jails using NullFS mounts.

1\. Make a directory to store the read-write area of the jail.

```sh
mkdir -p /usr/local/jails/thinjails/thinjail1
# or
zfs create -p zroot/jails/thinjails/thinjail1
```

2\. Add the hostname to the jails rc.conf

```sh
mkdir -p /usr/local/jails/thinjails/thinjail1/etc
echo hostname=\"thinjail1\" > /usr/local/jails/thinjails/thinjail1/etc/rc.conf
```

3\. Make the jail directory where the template and rw folder will be mounted.

```sh
mkdir -p /usr/local/jails/thinjail1
```

4\. Create the jail entry in `/etc/jail.conf`, be sure and include the global jail configs listed in the fulljail example.

```
# The jail definition for thinjail1
thinjail1 {
    host.hostname = "thinjail1.domain.local";
    path = "/usr/local/jails/thinjail1";
    interface = "lagg0";
    ip4.addr = 10.0.0.17;
    mount.fstab = "/usr/local/jails/thinjail1.fstab";
}
```

5\. Create the jail fstab.

```
# /usr/local/jails/thinjail1.fstab

/usr/local/jails/templates/10-1-Release  /usr/local/jails/thinjail1/ nullfs   ro          0 0
/usr/local/jails/thinjails/thinjail1     /usr/local/jails/thinjail1/ unionfs  rw,noatime  0 0
```

6\. Start the jail.

```sh
jail -c thinjail1
```

Now if you create dozens of thinjails, you can run `freebsd-update` once against the template and all your jails will be updated. You also have one easy place to backup to save all your jails customizations: `/usr/local/jails/thinjails/`.

## Simplifying jail.conf

[Jail.conf](https://www.freebsd.org/cgi/man.cgi?query=jail.conf&sektion=5&manpath=FreeBSD+10.1-RELEASE) is actually a fairly powerfull tool if you take advantage of it's features. The man page goes in more detail of how to use variables, but the examples below should give enough details to see how it can be useful. Any option that can be specified in the [jail](https://www.freebsd.org/cgi/man.cgi?query=jail&sektion=8&apropos=0&manpath=FreeBSD+10.1-RELEASE) command can be included in jail.conf.

If you've followed all three examples, your jail.conf is looking something like this:

```
# /etc/jail.conf

# Global settings applied to all jails.

exec.start = "/bin/sh /etc/rc";
exec.stop = "/bin/sh /etc/rc.shutdown";
exec.clean;
mount.devfs;

# The jail definition for fulljail1
fulljail1 {
    host.hostname = "fulljail1.domain.local";
    path = "/usr/local/jails/fulljail1";
    interface = "lagg0";
    ip4.addr = 10.0.0.15;
}

# The jail definition for zjail1
zjail1 {
    host.hostname = "zjail1.domain.local";
    path = "/usr/local/jails/zjail1";
    interface = "lagg0";
    ip4.addr = 10.0.0.16;
}

# The jail definition for thinjail1
thinjail1 {
    host.hostname = "thinjail1.domain.local";
    path = "/usr/local/jails/thinjail1";
    interface = "lagg0";
    ip4.addr = 10.0.0.17;
    mount.fstab = "/usr/local/jails/thinjail1.fstab";
}
```

This can be greatly simplified using some of the inheritence features of jail.conf. The first low hanging fruit is that the interface is the same for every jail, so it can be moved up to the global settings and be applied to every jail.

```
# Global settings applied to all jails

interface = "lagg0";
```

The hostnames and paths are slightly differnet, but all based on the name of the jail. In jail.conf, the name of a jail is accessable via a variable $name. So that can also be moved to the global settings.


```
# Global settings applied to all jails

interface = "lagg0";
hostname = "$name.domain.local";
path = "/usr/local/jails/$name";
```

The IPv4 address is also nearly the same, just varying by one number, we can use custom variables to simplify this and allow us to change the subnet of all our jails in one config if we need to move this server to a new network in the future.


```
# Global settings applied to all jails

interface = "lagg0";
hostname = "$name.domain.local";
path = "/usr/local/jails/$name";
ip4.addr = 10.0.0.$ip;
```

Lastly the mount.fstab line. Lets assume that all the future jails we're going to create will have fstabs at `/usr/local/jails/$name.fstab`, but the first three we created won't. We can do that by defining the fstab as a global setting then removing it for the first two jails.

Simplified, the new jail.conf looks like this, and new jails require only 3 lines of config and an fstab.

```
# Global settings applied to all jails

interface = "lagg0";
hostname = "$name.domain.local";
path = "/usr/local/jails/$name";
ip4.addr = 10.0.0.$ip;
mount.fstab = "/usr/local/jails/$name.fstab";

# The jail definition for fulljail1
fulljail1 {
    $ip = 15;
    mount.fstab = "";
}

# The jail definition for zjail1
zjail1 {
    $ip = 16;
    mount.fstab = "";
}

# The jail definition for thinjail1
thinjail1 {
    $ip = 17;
}
```

Hopefully this has helped you understand the process of how to create and manage FreeBSD jails without tools that abstract away all the details. Those tools are often quite useful, but there is always benefit in learning to do things the hard way. And in this case, the hard way doesn't seem to be that hard afteall.
