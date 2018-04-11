---
layout: single
title: Installing Ubuntu 18.04 on an APU2
date: 2018-04-09
slug: bionic-on-apu2
draft: true
---

Talk a little about the APU2 and provide a link. Some notes for installing over
serial, updating the bios ect...

Install the heat cooler correctly: https://www.pcengines.ch/apucool.htm

Use putty, set console to 115200,8n1

Download tinycore from http://pcengines.ch/howto.htm#bios http://pcengines.ch/howto.htm#TinyCoreLinux

Download bios from https://pcengines.github.io/

Mount the tinycore usb, copy bios to it.

Run `flashrom -w path_to_bios.rom -p internal:boardmismatch=force`
try without mismatch, if you get a message about the bios mismatching, just make
sure both are APU2.

Download ubuntu netboot.img, dd to disk

edit the boot option, remove vga= and add console=ttyS0,115200n8
