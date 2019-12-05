---
layout: single
title: Bug with systemd bonds and DHCP MTU
date: 2019-12-05
slug: systemd-dhcp-mtu-bug
---

After a recent update to systemd on Ubuntu 19.04 I ran into a bug which I was
unable to find anybody talking about.

I use systemd-networkd to create lacp bonds. Then these lacp bonds get an IP
address via dhcp. These bonds are also configured to set their MTU based on the
dhcp options. This is done with the following files.

'''
#/etc/systemd/network/eno.network 
[Match]
Name=eno[1,2]

[Network]
Bond=bond0
DHCP=no
LinkLocalAddressing=no
IPv4LLRoute=no
'''

'''
#/etc/systemd/network/bond0.netdev 
[NetDev]
Name=bond0
Kind=bond
MACAddress=XX:XX:XX:XX:XX:XX

[Bond]
Mode=802.3ad
TransmitHashPolicy=layer3+4
MIIMonitorSec=0.1s
LACPTransmitRate=fast
'''

'''
# cat /etc/systemd/network/bond0.network 
[Match]
Name=bond0

[Network]
DHCP=yes

[DHCP]
UseMTU=true
UseDomains=true
'''

I also run these servers with the HWE kernel, currently 5.0.

This has worked fine for several years, until last weeks update to systemd systemd 237-3ubuntu10.33.
Last week my servers would boot up and repeatedly log messages like this:

```
speed changed to 0 for port eno2
speed changed to 0 for port eno1
```

Looking in the kernel logs showed some more details:

```
tg3 0000:02:00.1 eno2: Link is up at 1000 Mbps, full duplex
tg3 0000:02:00.1 eno2: Flow control is off for TX and off for RXDec 05 07:25:32 dc1-cls01 kernel: tg3 0000:02:00.1 eno2: EEE is enabled
bond0: link status definitely up for interface eno2, 1000 Mbps full dup
bond0: first active interface up!
tg3 0000:02:00.0 eno1: Link is up at 1000 Mbps, full duplexDec 05 07:25:32 dc1-cls01 kernel: tg3 0000:02:00.0 eno1: Flow control is off for TX and off for RX
tg3 0000:02:00.0 eno1: EEE is enabledDec 05 07:25:32 dc1-cls01 kernel: bond0: link status definitely up for interface eno1, 1000 Mbps full dup
tg3 0000:02:00.1 eno2: Link is down
tg3 0000:02:00.0 eno1: Link is down
tg3 0000:02:00.1 eno2: speed changed to 0 for port eno2
tg3 0000:02:00.0 eno1: speed changed to 0 for port eno1
```

The bond would come up, but then as soon as it did both interfaces would go
down. There appears to be a bug now with getting the MTU from DHCP on a bond
device.

I added the following to `/etc/systemd/network/bond0.network` and the problem is
gone.

```
[Link]
MTUBytes=9000
```

I'll be filling a bug with Ubuntu, but I wanted to publish this so that anyone
else facing this can find a quick answer.
