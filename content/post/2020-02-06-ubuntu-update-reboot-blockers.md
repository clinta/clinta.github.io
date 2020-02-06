---
layout: single
title: Preventing disrupting reboots with Ubuntu automatic updates
date: 2020-02-06
slug: preventing-distrupting-reboots
---

Keeping your systems up to date is important, and Ubuntu makes this fairly easy.
It's also easy to enable automatic reboots when required for an update. The
downside is that these updates can happen when they shouldn't. With some custom
SystemD services you can replace the built in automatic-reboot functionaly with
a system that waits until conditions are appropriate to reboot.

Start by [enabling automatic
updates](https://help.ubuntu.com/lts/serverguide/automatic-updates.html), but
make sure `Unattended-Upgrade::Automatic-Reboot' is set to `"false"`.

When a reboot is needed Ubuntu places a file in `/var/run/reboot-required`. Make
a service that reboots the system only if this file exists.

`/etc/systemd/system/reboot-for-upgrades.service`

```
[Unit]
Description=Reboot if updates require it
ConditionPathExists=/var/run/reboot-required

[Service]
Type=oneshot
ExecStart=/bin/true
ExecStop=/bin/systemctl reboot
```

This service's start action does nothing, but it's stop action reboots the
machine. This is important for proper ordering with the services we want to
delay or prevent a reboot.

This service needs to run after apt-daily-upgrade runs. So use a SystemD
override to make this happen.

`/etc/systemd/system/apt-daily-upgrade.service.d/override.conf`

```
[Unit]
Requires=reboot-for-upgrades.service
Before=reboot-for-upgrades.service
```

Now make a SystemD service that will run before reboot-for-upgrades, which can
ensure that the system is ready to reboot. In my case, I do not want a machine
to reboot if the Citrix ICA Client is running, because this means a user is
actively using this machine. This service will wait for the process to finish
for up to 12 hours before allowing the reboot to complete.

`/etc/systemd/system/wait-for-icaclient.service`

```
[Unit]
Description=Wait for ICAClient to stop

[Service]
Type=oneshot
ExecStart=/bin/true
ExecStop=-/bin/sh -c 'tail --pid=$(pidof wfica) -f /dev/null'
TimeoutStopSec=12h
```

Again, the interesting work is done in ExecStop. In this case, `tail`'s --pid
feature is used to block until the wfica process exits. ExecStop is prefixed
with a `-` so that if the command fails (which it will if wfica is not running)
the service is still considered successfully stopped.

The dependency is created in an override for `reboot-for-upgrades.service`.

`/etc/systemd/system/reboot-for-upgrades.service.d/wait-for-icaclient.conf`

```
[Unit]
Requires=wait-for-icaclient.service
After=wait-for-icaclient.service
```

Now `reboot-for-upgrades.service` depends on `wait-for-icaclient.service` and
should start after it. Because SystemD inverts ordering for stopping services,
this means that `wait-for-icaclient.service` will complete it's ExecStop command
before `reboot-for-upgrades.service` can run it's ExecStop command.
