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
fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/10.2-RELEASE/base.txz -o /tmp/base.txz
tar -xvf /tmp/base.txz -C /usr/local/jails/fulljail1
fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/10.2-RELEASE/lib32.txz -o /tmp/lib32.txz
tar -xvf /tmp/lib32.txz -C /usr/local/jails/fulljail1
fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/10.2-RELEASE/ports.txz -o /tmp/ports.txz
tar -xvf /tmp/ports.txz -C /usr/local/jails/fulljail1
```

3\. Update your FreeBSD base install.

```sh
env UNAME_r=10.2-RELEASE freebsd-update -b /usr/local/jails/fulljail fetch install
```

4\. Verify your download. We're downloading these archives over FTP after all, we should confirm that this download is valid and not tampered with. The `freebsd-update IDS` command verifies the installation using a PGP key which is in your base system, which was presumably installed with an ISO that you verified using the FreeBSD [signed checksums](https://www.freebsd.org/releases/10.2R/signatures.html). Admittedly this step is a bit of paranoia, but I think it's prudent.

```sh
env UNAME_r=10.2-RELEASE freebsd-update -b /usr/local/jails/fulljail IDS
```

5\. Make sure you jail has the right timezone and dns servers and a hostname in rc.conf.

```sh
cp /etc/resolv.conf /usr/local/jails/fulljail1/etc/resolv.conf
cp /etc/localtime /usr/local/jails/fulljail1/etc/localtime
echo hostname=\"fulljail1\" > /usr/local/jails/fulljail1/etc/rc.conf
```

6\. Edit jail.conf with the details about your jail.

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

7\. Start and login to your jail.

```sh
jail -c fulljail1
```

11 commands and a config file, but this is the most tedious way to make a jail. With a little bit of templating it can be even easier. So I'll start by making a template. Making a template is basically the same as steps 1, 2 and 3 above, but with a different destination folder, I'll condense them here.

## Creating a template

1\. Create a template or a ZFS dataset. If you'd like to use the zfs clone method of deploying templates, you'll need to create a zfs dataset instead of a folder.

```sh
mkdir -p /usr/local/jails/releases/10.2-RELEASE
## or 
zfs create -p zroot/jails/releases/10.2-RELEASE

fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/10.2-RELEASE/base.txz -o /tmp/base.txz
tar -xvf /tmp/base.txz -C /usr/local/jails/releases/10.2-RELEASE
fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/10.2-RELEASE/lib32.txz -o /tmp/lib32.txz
tar -xvf /tmp/lib32.txz -C /usr/local/jails/releases/10.2-RELEASE
fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/10.2-RELEASE/ports.txz -o /tmp/ports.txz
tar -xvf /tmp/ports.txz -C /usr/local/jails/releases/10.2-RELEASE
cp /etc/resolv.conf /usr/local/jails/releases/10.2-RELEASE/etc/resolv.conf
cp /etc/localtime /usr/local/jails/releases/10.2-RELEASE/etc/localtime
```

2\. Update your template with `freebsd-update`.

```sh
env UNAME_r=10.2-RELEASE freebsd-update -b /usr/local/jails/releases/10.2-RELEASE fetch install
```

3\. Verify your install

```sh
env UNAME_r=10.2-RELEASE freebsd-update -b /usr/local/jails/releases/10.2-RELEASE IDS
```

And that's it, now you have a fully up to date jail template. If you've made this template with zfs, you can easily deploy it using zfs snapshots.

## Deploying a template with ZFS snapshots

1\. Create a snapshot. My last freebsd-update to my template brought it to patch level 17, so I'll call my snapshot p10.

```sh
zfs snapshot zroot/jails/releases/10.2-RELEASE@p10
```

2\. Clone the snapshot to a new jail.

```sh
zfs clone zroot/jails/releases/10.2-RELEASE@p10 zroot/jails/zjail1
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

This section has changed. [details](https://github.com/clinta/clinta.github.io/commit/2b28a7d626eff467e44ce18dd1000aa2c279a329) 

This method is a little bit more tricky, because you have to take notes of which directories are local to your jails and which are universal to FreeBSD. Fortunately FreeBSD's directory structure is stable and predictable and the benefits of this method are that it allows you to update your base image and your ports tree once for all jails.

1\. This method requires a slightly different template than the ZFS method, so either copy the template created in the previous instructions, or use ZFS and clone it.

```sh
cp -R /usr/local/jails/releases/10.2-RELEASE /usr/local/jails/templates/base-10.2-RELEASE
# or
zfs create zroot/jails/templates
zfs clone zroot/jails/releases/10.2-RELEASE@p10 zroot/jails/templates/base-10.2-RELEASE
```

2\. In addition to your base template, you need to create a skeleton template which will hold all the directories that are local to your jail. We're going to copy these directories from the template to the skeleton.

```sh
mkdir -p /usr/local/jails/templates/skeleton-10.2-RELEASE
# or
zfs create -p zroot/jails/templates/skeleton-10.2-RELEASE

mkdir -p /usr/local/jails/templates/skeleton-10.2-RELEASE/usr/ports/distfiles /usr/local/jails/templates/skeleton-10.2-RELEASE/home /usr/local/jails/templates/skeleton-10.2-RELEASE/portsbuild
mv /usr/local/jails/templates/base-10.2-RELEASE/etc /usr/local/jails/templates/skeleton-10.2-RELEASE/etc
mv /usr/local/jails/templates/base-10.2-RELEASE/usr/local /usr/local/jails/templates/skeleton-10.2-RELEASE/usr/local
mv /usr/local/jails/templates/base-10.2-RELEASE/tmp /usr/local/jails/templates/skeleton-10.2-RELEASE/tmp
mv /usr/local/jails/templates/base-10.2-RELEASE/var /usr/local/jails/templates/skeleton-10.2-RELEASE/var
mv /usr/local/jails/templates/base-10.2-RELEASE/root /usr/local/jails/templates/skeleton-10.2-RELEASE/root
```

3\. The skeleton directory is what is going to be copied for each new jail. It is going to be mounted in `/skeleton/` inside the jail. So in the read-only base template we need to create symlink from all the expected locations to the appropriate directories inside the `/skeleton/` directory. It is very important to cd into your jail directory and create these symlinks with relative paths. That way they will always link to the correct location no matter where the base template ends up mounted.

```sh
cd /usr/local/jails/templates/base-10.2-RELEASE
mkdir skeleton
ln -s skeleton/etc etc
ln -s skeleton/home home
ln -s skeleton/root root
ln -s skeleton/usr/local usr/local
ln -s skeleton/usr/ports/distfiles usr/ports/distfiles
ln -s skeleton/tmp tmp
ln -s skeleton/var var
```

4\. Edit make.conf so that your ports workdirectory is located inside the skeleton directory.

```sh
echo "WRKDIRPREFIX?=  /skeleton/portbuild" >> /usr/local/jails/templates/skeleton-10.2-RELEASE/etc/make.conf
```

5\. Copy your skeleton for your jail. You can use plain old copy or ZFS snapshots.

```sh
zfs snapshot zroot/jails/templates/skeleton-10.2-RELEASE@skeleton
zfs create zroot/jails/thinjails
zfs clone zroot/jails/templates/skeleton-10.2-RELEASE@skeleton zroot/jails/thinjails/thinjail1
# or
mkdir /usr/local/jails/thinjails
cp -R /usr/local/jails/templates/skeleton-10.2-RELEASE /usr/local/jails/thinjails/thinjail1
```

6\. Add the hostname to the jails rc.conf

```sh
echo hostname=\"thinjail1\" > /usr/local/jails/thinjails/thinjail1/etc/rc.conf
```

7\. Make the jail directory where the base template and skeleton folder will be mounted.

```sh
mkdir -p /usr/local/jails/thinjail1
```

8\. Create the jail entry in `/etc/jail.conf`, be sure and include the global jail configs listed in the fulljail example.

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

9\. Create the jail fstab.

```
# /usr/local/jails/thinjail1.fstab

/usr/local/jails/templates/base-10.2-RELEASE  /usr/local/jails/thinjail1/ nullfs   ro          0 0
/usr/local/jails/thinjails/thinjail1     /usr/local/jails/thinjail1/skeleton nullfs  rw  0 0
```

10\. Start the jail.

```sh
jail -c thinjail1
```

Now if you create dozens of thinjails, you can run `env UNAME_r=10.2-RELEASE freebsd-update -b /usr/local/jails/templates/base-10.2-RELEASE fetch install` once and all your jails will be updated. You can run `portsnap -p /usr/local/jails/templates/base-10.2-RELEASE/usr/ports auto` and your ports tree for all jails is updated. And you have one easy place to backup to save all your jails customizations: `/usr/local/jails/thinjails/`.

## Simplifying jail.conf

[Jail.conf](https://www.freebsd.org/cgi/man.cgi?query=jail.conf&sektion=5&manpath=FreeBSD+10.2-RELEASE) is actually a fairly powerfull tool if you take advantage of it's features. The man page goes in more detail of how to use variables, but the examples below should give enough details to see how it can be useful. Any option that can be specified in the [jail](https://www.freebsd.org/cgi/man.cgi?query=jail&sektion=8&apropos=0&manpath=FreeBSD+10.2-RELEASE) command can be included in jail.conf.

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
host.hostname = "$name.domain.local";
path = "/usr/local/jails/$name";
ip4.addr = 10.0.0.$ip;
mount.fstab = "/usr/local/jails/$name.fstab";

exec.start = "/bin/sh /etc/rc";
exec.stop = "/bin/sh /etc/rc.shutdown";
exec.clean;
mount.devfs;

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
