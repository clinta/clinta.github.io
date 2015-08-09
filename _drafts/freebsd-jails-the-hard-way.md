There are many great options for managing FreeBSD Jails. iocage, warden and ez-jail aim to streamline the process and make it quick an easy to get going. But sometimes the tools built right into the OS are overlooked.

This is called "Jails the hard way", but it's not really true, managing jails without additional tools isn't very hard, especially with the jail.conf configuration file.

For this guide, I'm going to be putting my jails in `/usr/local/jails`.

I'll start with a very simple, isolated jail. Then I'll go over how to use ZFS snapshots, and lastly nullfs mounts to share the FreeBSD base files with multiple jails.

I'll also show some examples of how to use the templating power of jail.conf to apply similar settings to all your jails.

## Full Jail

1. Make a directory for the jail, or a zfs dataset if you prefer.
```sh
mkdir -p /usr/local/jails/fulljail1
## or
zfs create -o mountpoint=/usr/local/jails zroot/jails
zfs create zroot/jails/fulljail1
```

2. Download the FreeBSD base files, and any other parts you want, in this example I'll include the 32 bit libraries as well.

```sh
fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/10.1-RELEASE/base.txz -o /tmp/base.txz
tar -xvf /tmp/base.txz -C /usr/local/jails/fulljail1
fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/10.1-RELEASE/lib32.txz -o /tmp/lib32.txz
tar -xvf /tmp/lib32.txz -C /usr/local/jails/fulljail1
```

3. Make sure you jail has the right timezone and dns servers and a hostname in rc.conf.

```sh
cp /etc/resolv.conf /usr/local/jails/fulljail1/etc/resolv.conf
cp /etc/localtime /usr/local/jails/fulljail1/etc/localtime
echo hostname=\"fulljail1\" > /usr/local/jails/fulljail1/etc/rc.conf
```

4. Edit jail.conf with the details about your jail.

```
# /etc/jail.conf

# Global settings applied to all jails.

exec.start = "/bin/sh /etc/rc";
exec.stop = "/bin/sh /etc/rc.shutdown";
exec.clean;
mount.devfs;

# The jail definition for fulljail1
fulljail1 {
    host.hostname = "fullname1.domain.local";
    path = "/usr/local/jails/fulljail1";
    interface = "lagg0";
    ip4.addr = 10.0.0.15;
}
```

5. Start and login to your jail.

```sh
jail -c fulljail1
jexec fulljail1 csh
```

11 commands and a config file, but this is the most tedious way to make a jail. With a little bit of templating it can be even easier. So I'll start by making a template. Making a template is basically the same as steps 1, 2 and 3 above, but with a different destination folder, I'll condense them here.

## Creating a template

1. Create a template or a ZFS dataset. If you'd like to use the zfs clone method of deploying templates, you'll need to create a zfs dataset instead of a folder.

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

2. Optionally, update your template with `freebsd-update`.

```sh
freebsd-update -b /usr/local/jails/tempaltes/10-1-Release fetch
freebsd-update -b /usr/local/jails/tempaltes/10-1-Release install
```

And that's it, now you have a fully up to date jail template. If you've made this template with zfs, you can easily deploy it using zfs snapshots.

## Deploying a template with ZFS snapshots

1. Create a snapshot. My last freebsd-update to my template brought it to patch level 17, so I'll call my snapshot p17.

```sh
zfs snapshot zroot/jails/templates/10-1-Release@p17
```

2. Clone the snapshot to a new jail.

```sh
zfs clone zroot/jails/templates/10-1-Release@p17 zroot/jails/zjail1
```

3. Configure the jail hostname.

```sh
echo hostname=\"zjail1\" > /usr/local/jails/zjail1/etc/rc.conf
```

4. Add the jail definition to jail.conf, make sure you have the global jail settings from jail.conf listed in the fulljail example.

```sh
# The jail definition for fulljail1
zjail1 {
    host.hostname = "fullname1.domain.local";
    path = "/usr/local/jails/fulljail1";
    interface = "lagg0";
    ip4.addr = 10.0.0.15;
}
```

5. Start the jail.

```sh
jail -c zjail1
```

The downside with the zfs approach is that each jail is now a fully independent, and if you want need to update your jails, you have to update them all. By sharing a template using nullfs mounts you can have only one copy of the base system that only needs to be updated once.

## Thin jails using NullFS mounts.

```sh
```
