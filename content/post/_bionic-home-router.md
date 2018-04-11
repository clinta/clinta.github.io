---
layout: single
title: Building a sweet home router on Ubuntu 18.04
date: 2018-04-09
slug: bionic-home-router
draft: true
---

After installation delete the netplan.yaml file. Create systemd-networkd units instead.

Enable IP Forwarding

Install FireHol and configure

Install dnsmasq and unbound

Configure dnsmasq to listen to dns on alt port

configure unbound, with forward to dnsmasq for local domain.

configure dns-over-tls forwarding in unbound

Install netdata

Stuff for a later post: Authoritative split-view dnssec with nsd
