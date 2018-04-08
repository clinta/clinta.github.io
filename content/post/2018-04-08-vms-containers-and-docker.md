---
layout: single
title: VMs Containers and Docker
date: 2018-04-08
slug: vms-containers-and-docker
---

This post is an explanation of what containers are, how they compare to vms,
and where specific container technologies like docker, nspawn, and FreeBSD
jails fit. This post is mostly to clarify terminology and help to to bring
anyone who is unfamiliar with these concepts up to speed. This explanation is
based on my experience over the last several years using these technologies and
writing programs to make use of them. Though many parts of this are simplified,
my hope is that it is all technically accurate. If you find something that
isn't please open an [issue](https://github.com/clinta/clinta.github.io/issues)
and I'd love to discuss it and learn more.


## What is a computer? ##

Since containers and vms all try to simulate a computer, it seems appropriate
to start with a simplified answer to the question "What is a computer?" For our
purposes, a computer is a device that is capable of running software written in
x86 machine code. Lets look at what code it runs, step by step.

### Firmware ###

The first bit of software that any computer runs is the firmware. This software
is burned onto a chip on the motherboard. It's purpose is to provide a common
interface that an operating system can use to talk to the hardware in the
computer. On older systems the interface that this software provides is the
BIOS. On newer systems it is EFI.

### Bootloader ###

After a computer boots and the firmware initializes the devices it searches for
a bootloader on the configured boot device. When this bootloader is found it is
executed. This bootloader is a very small piece of software, it's only job is
to load the operating system kernel.

### Kernel ###

The kernel is the core of the computers operating system. It is responsible for
dividing cpu time between the various user processes that are running in the
operating system and it provides an interface for user processes to talk to
hardware.

### User Processes ###

All other processes on the computer are user processes. They cannot run unless
the kernel schedules time for them on the CPU. They cannot access
hardware unless the kernel gives them access. Most user processes don't access
hardware directly. When a user process wants to write a file, it typically does
not access the hard disk directly, instead it asks the kernel to write it. The
kernel knows what filesystem is on the disk and how to send the right commands
to the disk. When a user process wants to talk on the network, it does not send
data directly to the network card, and process incoming packets, it asks the
kernel for a socket and the kernel does the hard work of determining which
packets need to be sent back to this process and which packets go elsewhere.

### Init ###

On unix based systems there is a special user process called init. It is the
first process executed by the kernel and it is responsible for launching all
other user processes.

### Operating System ###

An operating system is a kernel and a collection of user processes that runs on
a computer.

Now that we have established the basics of what a computer is, we can talk
about how different technologies simulate a computer.


## What is a Virtual Machine? ##

A virtual machine is a simulation of an entire computer.

A hypervisor is the software that runs the simulation. A type 1 hypervisor is
an operating system who's entire purpose is to run VMs. VMWare Vsphere is an
example of a type 1 hypervisor. A type 2 hypervisor is a program that runs vms
and runs on an existing operating system. VirtualBox is an example of a type 2
hypervisor.

When a hypervisor starts a VM it is very similar to starting a physical
computer. The hypervisor has simulated hardware, including a virtual NIC and a
virtual hard drive. It has it's own virtual firmware which provides interfaces
to these virtual devices. The virtual firmware searches for a bootloader on the
virtual disk, and when it finds a bootloader it executes it, which then loads a
kernel inside this virtual machine.

If we are running one VM on a hypervisor, the physical hardware is executing
two kernels, one for the hypervisor, and one for the VM. And the hypervisor
must schedule access on the CPU so that the virtual machine's kernel can run,
then the virtual machine's kernel must schedule access for the user processes
in the VM to run.

When a user process in a VM wants to write a file, it must ask the VM kernel to
write the file. The VM kernel sends scsi commands to the virtual disk which are
received by the hypervisor. Since the virtual disk is really a file, the
hypervisor must then ask it's kernel to write the file. The hypervisor kernel
then sends scsi commands to the physical disk.

This is a non-trivial amount of overhead, especially if you only have the VM
because you want to run a specific user process in it. To avoid this overhead,
while still providing a level of isolation, containers are a good solution.

## What is a container? ##

In normal operation, user processes running on a computer can communicate with
one another through a variety of different methods, and they can all manipulate
the hardware of the computer in a way that can affect one another. Containers
are a way of isolating user processes to prevent this. If a process is not in a
container, it is able to read and write any file it has permissions to. It can
open network connections using the computers IP address. It can communicate
with other processes using the inter-process communication capabilities
provided by the kernel.

Containers can prevent some or all of this behavior depending on the
configuration. This is how containers can provide the isolation benefits of a
VM without the overhead of running two kernels. Different container
technologies do this in different ways.

### chroot ###

[Chroot](https://www.freebsd.org/cgi/man.cgi?chroot(8)) is the oldest container
technology. In unix the root is the highest directory level accessible. Chroot
changes the root for the current process to be some lower level directory,
which prevents access to any files outside of the chroot. Note that this only
contains filesystem access, it does nothing to limit network access, or other
kernel APIs that processes in the chroot can call.


### FreeBSD Jails ###

FreeBSD jails build on chroot to create more complete container isolation. By
default they limit the kernel APIs that jailed processes can call and they
isolate jailed processes to only utilizing permitted IP addresses on the NIC.
Jails expect to have an operating system in the jail with everything except the
kernel. When the jail starts, init will be launched which will launch other
processes.

### Linux Namespaces ###

[Linux Namespaces](https://en.wikipedia.org/wiki/Linux_namespaces) provide
isolation for specific resources. By putting a process into a namespace, it no
longer has visibility to the resources in other namespaces. The mount namespace
prevents access to mountpoints in other namespaces. The pid namespace prevents
visibility to process IDs running in other namespaces. The network namespace
prevents visibility of network devices in other namespaces. By combining
different namespaces the level of containerization for a process can be
customized.

#### systemd-nspawnd ####

[Systemd-nspawnd](https://www.freedesktop.org/software/systemd/man/systemd-nspawn.html)
starts a container in a directory using linux namespaces to provide isolation.
Like FreeBSD jails, nspawnd expects to run an init process inside the container
which will launch other processes.

#### Docker ####

Docker also uses linux namespaces for isolation, but the typical docker
container does not run an init process. Instead docker is intended to run
microservices where only a single process in the container is running. If you
are running a docker container running nginx for example, the only process
likely running in the container is nginx. While an nspawnd container would be
running init which runs nginx.

Docker also provides many convenient tools for running containers quickly with
minimal configuration. By default docker will configure iptables to
automatically nat outbound network access from inside a container. The docker
command also provides switches for forwarding ports from the host's network
interface into the container. Docker also provides an repository of pre-built
images which can be run with a single command.
