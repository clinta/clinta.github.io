---
layout: single
title: Getting Started with systemd-nspawnd
date: 2018-04-09
slug: getting-started-with-systemd-nspawnd
draft: true
---

I love container technologies. One of my most popular blog posts to date is my
  guide on [FreeBSD Jails the Hard Way](/freebsd-jails-the-hard-way/). This
  guide aims to be similar, but for creating containers on linux using
  systemd-nspawnd. Many people immediately think docker when they think linux
  container, but docker has a very specific vision for containers. Docker aims
  to build a collection of microservices where only a single process is running
  in a container. For anyone familiar with FreeBSD Jails, or familiar with
  deploying VMs these microservice containers can be unfamiliar. Systemd-nspawnd
  on the other hand is much more like running a vm in a container. The container
  runs an init process and generally isn't as effemeral as a docker container.
  If you want a more basic guide on the differences between containers, VMs and
  docker, check out my last post [VMs, Containers and
  Docker](/vms-containers-and-docker/).

  At the time of this writing, there isn't a whole lot of information about
  nspawnd outside of the man pages, many people don't even know this technology
  exists. This guide will get you quickly up and running with some Ubuntu
  containers so you can determine if this container technology might help you
  solve some problems.

This guide will assume you're running on an Ubuntu 18.04 host, but these
instructions will work on any modern linux distribution with a new enough
version of systemd.

### Installing

The first step is to setup a directory and install Ubuntu. I like to start by
creating a releases directory to hold templates which I will later copy to make
my containers.

```bash
# mkdir -p /var/lib/machines/releases/xenial
# cd /var/lib/machines/releases
```

Make sure you have `debootstrap` installed, then install Ubuntu into your
directory.

```bash
# debootstrap xenial xenial http://archive.ubuntu.com/ubuntu
```

And now some cleanup. debootstrap will have added your hostname to
`/etc/hostname` in the container. You will want to delete this file so that the
container keeps the hostname that nspawnd assigns it.

```bash
# rm xenial/etc/hostname
```

deboostrap will only have the main repo in `/etc/sources.list`, you may want to
add additional ubuntu repositories now.

```bash
cat <<EOF > xenial/etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu/ xenial main restricted
deb http://archive.ubuntu.com/ubuntu/ xenial-updates main restricted
deb http://archive.ubuntu.com/ubuntu/ xenial universe
deb http://archive.ubuntu.com/ubuntu/ xenial-updates universe
deb http://archive.ubuntu.com/ubuntu/ xenial multiverse
deb http://archive.ubuntu.com/ubuntu/ xenial-updates multiverse
deb http://security.ubuntu.com/ubuntu xenial-security main restricted
deb http://security.ubuntu.com/ubuntu xenial-security universe
deb http://security.ubuntu.com/ubuntu xenial-security multiverse
EOF
```

Now it's time to set a root password, since Ubuntu will not properly boot
without one.

```bash
# systemd-nspawn -D xenial
Spawning container xenial on /var/lib/machines/releases/xenial.
Press ^] three times within 1s to kill container.
root@xenial:~# passwd
Enter new UNIX password: 
Retype new UNIX password: 
passwd: password updated successfully
root@xenial:~# exit
logout
Container xenial exited successfully.
```

Now it's time to boot the container and install upgrades.

```bash
# systemd-nspawn -M xenial -b -D xenial
[...]
Ubuntu 16.04 LTS xenial console

xenial login: root
Password: 
Last login: Mon Apr  9 16:07:55 EDT 2018 on console
Welcome to Ubuntu 16.04 LTS (GNU/Linux 4.15.15-1-ARCH x86_64)

 * Documentation:  https://help.ubuntu.com/
root@xenial:~#
```

First though, we need a dns server.

```bash
root@xenial:~# echo "nameserver 8.8.8.8" > /etc/resolv.con
```

And now the updates. Be warned, you will see an error here, we will solve it in
the next step.

```bash
root@xenial:~# apt update
Get:1 http://security.ubuntu.com/ubuntu xenial-security InRelease [102 kB]
[...]
91 packages can be upgraded. Run 'apt list --upgradable' to see them.
root@xenial:~# apt dist-upgrade
[...]
Setting up makedev (2.3.1-93ubuntu2~ubuntu16.04.1) ...
mknod: mem-: Operation not permitted
makedev mem c 1 1 root kmem 0640: failed
mknod: kmem-: Operation not permitted
makedev kmem c 1 2 root kmem 0640: failed
mknod: port-: Operation not permitted
makedev port c 1 4 root kmem 0640: failed
mknod: ram0-: Operation not permitted
makedev ram0 b 1 0 root disk 0660: failed
mknod: ram1-: Operation not permitted
makedev ram1 b 1 1 root disk 0660: failed
[...]
Errors were encountered while processing:
 makedev
 ubuntu-minimal
```

The errors above are a result of this
[bug](https://bugs.launchpad.net/ubuntu/+source/makedev/+bug/1675163). The bug
has a fix released, but that fix is only for LXC containers. If you look at the
[patch](http://launchpadlibrarian.net/312139838/makedev_2.3.1-93ubuntu1_2.3.1-93ubuntu2~ubuntu16.04.1.diff.gz)
to the post install script, you'll see that it works by exiting early if an LXC
container is detected. We need to modify this patch so that it does the same for
systemd-nspawnd containers too. There are many great
[guides](https://raphaelhertzog.com/2011/07/04/how-to-prepare-patches-for-debian-packages/) out there on how to
package debian packages, if you follow one the only change you need to make is
changing the line in `/debian/postinst` from `if grep -q container=lxc
/proc/1/environ` to `if grep -q container=[lxc\|systemd-nspawn]
/proc/1/environ`. If you trust me, and github, and your ISP, and want to install
an unsigned package at your own risk, you can download a patched makedev from
[here](todo-link). Copy the patched deb into your container and install it.

(in another shell, that is not in the container)
```bash
# cp makedev_2.3.1-93ubuntu3\~ubuntu16.04.2_all.deb
/var/lib/machines/xenial/root/
```

(and back in the container)
```bash
root@xenial:~# dpkg -i makedev_2.3.1-93ubuntu3~ubuntu16.04.2_all.deb 
(Reading database ... 10463 files and directories currently installed.)
Preparing to unpack makedev_2.3.1-93ubuntu3~ubuntu16.04.2_all.deb ...
Unpacking makedev (2.3.1-93ubuntu3~ubuntu16.04.2) over (2.3.1-93ubuntu2~ubuntu16.04.1) ...
Setting up makedev (2.3.1-93ubuntu3~ubuntu16.04.2) ...
LXC container detected, aborting due to LXC managed /dev.
root@xenial:~# apt dist-upgrade
Reading package lists... Done
Building dependency tree       
Reading state information... Done
Calculating upgrade... Done
0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
1 not fully installed or removed.
After this operation, 0 B of additional disk space will be used.
Do you want to continue? [Y/n] y
Setting up ubuntu-minimal (1.361.1) ...
```

We need to install dbus. Dbus is used by systemd to communicate with the container, and `machinectl login` will
not work without it.

```bash
root@xenial:~# apt install dbus
```

And we need to edit `/etc/securetty` to permit root to login via `/dev/pts/0`

```bash
root@xenial:~# echo "pts/0" >> /etc/securetty
```

And that's it, we can now shut down this container and copy the template to
begin using it. To exit the login prompt press `ctrl+]` three times.


```bash
root@xenial:~# exit
logout

Ubuntu 16.04.4 LTS xenial console

xenial login:   
Container xenial terminated by signal KILL.
#
```
