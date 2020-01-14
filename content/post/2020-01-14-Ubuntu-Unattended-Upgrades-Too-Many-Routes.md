---
layout: single
title: Ubuntu Unattended Upgrades Hangs With Too Many Routes
date: 2020-01-14
slug: ubuntu-unattended-upgrades-too-many-routes
---

I recently discovered an issue on some of our routers running Ubuntu 16.04 where
they would have a stuck `unattended-updates` process consuming 100% of a CPU
core.

This issue only appears on routers wich are retrieving full route table from the
internet, (at this time about 800k routes). I tracked the issue down to
unattended-upgrades default setting of trying to determine if it's running on
a metered connection.

This function relies on pygobjects `NetworkManger.GetDefault()`, and this
function hangs indefinately when run on a machine with 800k routes.

A simple work around is to disable metered conection detecing in Apt.

```
// /etc/apt/apt.conf.d/99-unattended-upgrades

Unattended-Upgrade::Skip-Updates-On-Metered-Connections "false";
```

This bug has been reported to Ubuntu and is being tracked
[here](https://bugs.launchpad.net/ubuntu/+source/pygobject/+bug/1859080).
