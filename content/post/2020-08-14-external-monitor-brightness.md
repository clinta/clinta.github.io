---
layout: single
title: Control External Monitor Brightness
date: 2020-08-14
slug: external-monitor-brightness
---

External monitors can be controlled from linux via the
[DDC/CI](https://en.wikipedia.org/wiki/Display_Data_Channel#DDC.2FCI) interface.
There is some great guidence on doing this in in the
[ArchWiki](https://wiki.archlinux.org/index.php/backlight#External_monitorshttps://wiki.archlinux.org/index.php/backlight#External_monitors),
but there are some problems on Nvidia that can be solved with workarounds listed
in this
[issue](https://gitlab.com/ddcci-driver-linux/ddcci-driver-linux/-/issues/7).


Here's a step by step to getting it working on Arch.

1. Install [ddcutil](https://www.archlinux.org/packages/?name=ddcutil) and [ddcci-driver-linux-dkms](https://aur.archlinux.org/packages/ddcci-driver-linux-dkms/).
2. Add `i2c-dev` to `/etc/modules-load.d/modules.conf`.
3. Add a ddcci service by creating the following in
   `/etc/systemd/system/ddcci@.service`:
```
[Unit]
Description=ddcci handler
After=graphical.target
Before=shutdown.target
Conflicts=shutdown.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo Trying to attach ddcci to %i && success=0 && i=0 && id=$(echo %i | cut -d "-" -f 2) && while ((success < 1)) && ((i++ < 5)); do /usr/bin/ddcutil getvcp 10 -b $id && { success=1 && echo ddcci 0x37 /sys/bus/i2c/devices/%i/new_device && echo "ddcci attached to %i"; } || sleep 5; done'
Restart=no
```
4. Add a udev rule to load this service on attachment of the Nvidida i2c adapter
   by creating `/etc/udev/rules.d/99-ddcci.rules` with the following content:

```
SUBSYSTEM=="i2c-dev", ACTION=="add",\
	ATTR{name}=="NVIDIA i2c adapter*",\
	TAG+="ddcci",\
	TAG+="systemd",\
	ENV{SYSTEMD_WANTS}+="ddcci@$kernel.service"
```
5. Reload udev rules `sudo udevadm control --reload-rules && sudo udevadm trigger`

If this worked you should now have devices in `/sys/class/backlight` and any
tool that controls backlights should work.

But some tools do not work well with multiple monitors. If you want a script
that can be mapped to a hotkey to increase or decrease brightness, keep reading.

Install [brightnessctl](https://www.archlinux.org/packages/?name=brightnessctl)
then map the following to your preferred hotkeys.

Increase brightness: `bash -c 'brightnessctl -l -c backlight -m | cut -d , -f1 |
while IFS= read -r dev; do  brightnessctl -d $dev s 5+; done'`

Decrease brightness: `bash -c 'brightnessctl -l -c backlight -m | cut -d , -f1 | while IFS= read -r dev; do  brightnessctl -d $dev s 5-; done'`
