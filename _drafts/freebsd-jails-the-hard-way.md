There are many great options for managing FreeBSD Jails. iocage, warden and ez-jail aim to streamline the process and make it quick an easy to get going. But sometimes the tools built right into the OS are overlooked.

This is called "Jails the hard way", but it's not really true, managing jails without additional tools isn't very hard, especially with the jail.conf configuration file.

For this guide, I'm going to be putting my jails in `/usr/local/jails`.

I'll start with a very simple, isolated jail. Then I'll go over how to use ZFS snapshots, and lastly nullfs mounts to share the FreeBSD base files with multiple jails.

## Full Jail

1. Make a directory for the jail.
`mkdir -p /usr/local/jails/fulljail1`

2. Download the FreeBSD base files, and any other parts you want, in this example I'll include the 32 bit libraries as well.
`fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/10.1-RELEASE/base.txz -o /tmp/base.txz`
`tar -xvf /tmp/base.txz -C /usr/local/jails/fulljail1`
`fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/10.1-RELEASE/lib32.txz -o /tmp/lib32.txz`
`tar -xvf /tmp/lib32.txz -C /usr/local/jails/fulljail1`
