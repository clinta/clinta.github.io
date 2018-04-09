---
layout: single
title: Embracing Binary for Beautiful Networks
date: 2015-03-07T11:30:00-05:00
slug: Embracing-Binary-for-Beautiful-Networks
aliases:
  - 2015-03-07-Embracing-Binary-for-Beautiful-Networks
  - 2015-3-07-Embracing-Binary-for-Beautiful-Networks
  - 2015-3-7-Embracing-Binary-for-Beautiful-Networks
---

During my time working for an MSP I got to see many different networks with many different techniques for mapping vlan numbers to subnets, but all of them left me dissatisfied. The biggest problem was that they were always designed to try to make some sense to people looking at the numbers as they're most commonly written. Vlan numbers in decimal and IP addresses in dotted decimal. But these are just incompatible. Sure you can make it look pretty if Vlan `10` is `10.10.0.0/16` and Vlan `20` is `10.20.0.0/16`, but once you need to start subnetting those /16 networks things get messy and you have to have all sorts of special rules for what happens to vlans over 255.

In my new network design I sought to tackle this inconsistency head on. I started with the idea that we should make all of our IPV4 networks /24. Broadcast domains don't scale well with more than 254 hosts anyway, and with proper planning we don't need to preserve private IP space by subnetting smaller than that. The second idea that I considered to make this possible is that 4096 vlans is enough that we can have every network in our organizaiton be unique. This may not be true for very large organizations, but it is for us, and designing our networks so that every vlan is unique can avoid a lot of management headaches.

With that in place a simple vlan to subnet mapping becomes possible. A vlan is a 12 bit integer, the network address of a /24 IPv4 network is a 24 bit integer. All of our private space will be /24 networks in the `10.0.0.0/8` network. This leaves us with a 16 bit number that identifies the network. As I said above, we don't need more than 4096 networks, so we can cut this number down to 12 bits. Our private netowork range is now `10.0.0.0/12`. And the vlan number is always the least significant network bits.

See the table below for some examples for how this works.

|IP Addresss   |Network      |Network Bits              |Least Significant 12 Network Bits|Base 10 VLAN|
|:-------------|:------------|:------------------------:|:-------------------------------:|-----------:|
|10.0.4.254/24 |10.0.4.0/24  |00001010.00000000.00000100|0000.00000100                    |4           |
|10.4.25.2/24  |10.4.25.0/24 |00001010.00000100.00011001|0100.00011001                    |1049        |
|10.15.64.55/24|10.15.64.0/24|00001010.00001111.01000000|1111.01000000                    |3904        |

Now here's the shortcut. Multiply the second octet by 256 and add the 3rd octet to get the vlan.

|IP Addresss   |2nd octet * 256|+ 3rd octet     |
|:-------------|--------------:|---------------:|
|10.0.4.254/24 |0 * 256 = 0    |0 + 4 = 4       |
|10.4.25.2/24  |4 * 256 = 1024 |1024 + 25 = 1049|
|10.15.64.55/24|15 * 256 = 3840|3840 + 64 = 3904|

Now at this point the astute reader may have noticed that there is no vlan `0`. And you're correct. `10.0.0.0/24` must be given as a sacrifice to the network gods. Or at least used for a network which does not need a vlan. In our case we'll be using it for router loopback addresses.

Now that the vlan to network mapping is solved, the rest of this post is just a geeky dive into subnetting that may provide inspiration to others designing new networks. Our network consists of 2 datacenters and around 100 branch offices. Trying to keep our design open for future growth we've allocated a /16 network to each datacenter, and left room to grow up to 8 datacenters. We're also leaving room to grow up to 512 branch offices. Planning along binary boundaries allows us to easily think in terms of route summarization. For us `10.0.0.0/13` represents datacenter networks. `10.0.0.0/16` is DC0. `10.1.0.0/16` is DC1 up to DC7. Our branches each need a voice and data vlan, keeping in line with our plan for all networks being /24, this means that each branch office needs a designated /23 network. A /14 can hold 512 /23 networks. So allocating `10.8.0.0/14` allows us to grow up to 512 branch offices. Basic sorting of branches by region can prove useful if we begin to open more datacenters in other regions. So the first 2 bits of the branch's address represent the region. `10.8.0.0/16` is Region 1 (Midwest), `10.9.0.0/16` is Region 2 (Midwest), `10.10.0.0/16` is Region 3 (South), `10.11.0.0/16` is Region 4 (West).

Every business is different and will require a unique network design. But I hope this post can demonstrate the power of remembering that in the end addresses and vlans are binary numbers. Next time you're tempted to add 10 for your next network, consider adding 8 instead.
