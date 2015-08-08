There are many great options for managing FreeBSD Jails. iocage, warden and ez-jail aim to streamline the process and make it quick an easy to get going. But sometimes the tools built right into the OS are overlooked.

This is called "Jails the hard way", but it's not really true, managing jails without additional tools isn't very hard, especially with the jail.conf configuration file.

For this guide, I'm going to be putting my jails in `/usr/local/jails`.

I'll start with a very simple, isolated jail. Then I'll go over how to use ZFS snapshots, and lastly nullfs mounts to share the FreeBSD base files with multiple jails.

I'll also show some examples of how to use the templating power of jail.conf to apply similar settings to all your jails.

## Full Jail

1. Make a directory for the jail.
`mkdir -p /usr/local/jails/fulljail1`

2. Download the FreeBSD base files, and any other parts you want, in this example I'll include the 32 bit libraries as well.

```sh
fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/10.1-RELEASE/base.txz -o /tmp/base.txz
tar -xvf /tmp/base.txz -C /usr/local/jails/fulljail1
fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/10.1-RELEASE/lib32.txz -o /tmp/lib32.txz
tar -xvf /tmp/lib32.txz -C /usr/local/jails/fulljail1
```

3. Edit jail.conf with the details about your jail.

```
# /etc/jail.conf

# Global settings applied to all jails.
# $name is an automatic variable that matches the jail's name.

host.hostname = "$name.domain.local";
path = "/usr/local/jails/$name";
interface = "lagg0";

exec.start = "/bin/sh /etc/rc";
exec.stop = "/bin/sh /etc/rc.shutdown";
exec.clean;

# The jail definition for fulljail1
fulljail1 {
    ip4.addr = 10.0.0.$jid;
}
```
