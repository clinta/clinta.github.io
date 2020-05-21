---
layout: single
title: Run a SystemD service on IP Address Change
date: 2020-05-21
slug: run-service-on-ip-change
---

Ever needed to run a command anytime an IP address changes? IP addresses don't
change often on IPv4 networks, but IPv6 changes things and makes addresses more
dynamic, so the ability to run a command every time your machine gets a new IP
address can be very useful on dual stack networks. Here's how I accomplished
this with a simple SystemD service and target.

```
# /etc/systemd/system/ip-change-mon.service

[Unit]
Description=IP Change Monitor
Wants=network.target
After=network-online.target

[Service]
ExecStart=:/bin/bash -c "ip mon addr | sed -nu -r
\'s/.*[[:digit:]]+:[[:space:]]+([^[:space:]]+).*/\\1/p\' | while read iface; do
systemctl restart ip-changed@${iface}.target; done"

[Install]
WantedBy=multi-user.target default.target
```

That command is a little cryptic because of the layers of escaping to make it
work well with systemd. Written as a bash script it'd look something like this:


```bash
#/bin/bash

ip mon addr | sed -nu -r \'s/.*[[:digit:]]+:[[:space:]]+([^[:space:]]+).*/\\1/p\' | while read iface; do
  systemctl restart ip-changed@${iface}.target
done
```

`ip monitor address` is a the command watching for ip address changes. If you
run this command by itself you get output that looks like this:

```
1: eth0    inet 192.168.10.15/24 scope global secondary eth0
       valid_lft forever preferred_lft forever
Deleted 7: eth0    inet 192.168.10.15/24 scope global secondary eth0
       valid_lft forever preferred_lft forever
```

The sed command strips out everything except the interface name. Then read loops
over each event and restarts a target for that interface.

The target file is very simple and exists to be used by other units.

```
# /etc/systemd/system/ip-changed@.target 

[Unit]
Description=IP Address changed on %i
```

Now just enable and start the monitor:

```bash
# systemctl enable --now ip-change-mon.service
```

Now in any systemd unit you want to run when the IP changes simply add these
options to the `[Unit]` section.

```
PartOf=ip-changed@eth0.target
Before=ip-changed@eth0.target
```

Whenever ip-change-mon detects and ip address change it will restart the target,
and because the unit you want to run is `PartOf` that target, your unit will
restart too.
