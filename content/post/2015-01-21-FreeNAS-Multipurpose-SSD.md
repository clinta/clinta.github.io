---
date: "2015-01-21"
layout: post
title: Using one pair of SSDs for both ZIL and L2ARC in FreeNAS
aliases:
  - /post/2015-01-21-FreeNAS-Multipurpose-SSD
  - /post/2015-1-21-FreeNAS-Multipurpose-SSD
---

I'm a big fan of ZFS, and a big fan of FreeNAS. But some times the options avaliable in the FreeNAS GUI can't quite do everything. Using one disk for more than one purpose is one of those things. At $dayjob we're going to be using a new FreeNAS server for iSCSI datastores for VMWare. This is one of those instances where a ZIL can really improve performance because there is potential for a lot of synchronious writes from VMs hosting databases.

In the past, conventional wisdom was to use dedicated SLC SSDs for ZIL, but that seems to be dated information. SLC SSDs are pretty hard to find now, and all the info I can find indicates that enterprise grade MLCs can outperform and outlast the SLCs of a couple years ago. With that info in hand, we specced our new storage system with 2 Intel S3700 SSD's. These drives come in a minimum size of 100GB, way more than anyone needs for a ZIL.

A brief tangent on ZIL sizing, ZIL is going to cache synchronous writes so that the storage can send back the "Write succeeded" message before the data written actually gets to the disk. Data is flushed to the disks within the time set in the ZFS tunable tunable zfs_txg_timeout, this defaults to 5 seconds. With 20Gbps of connectivity to this system, the maximum that could ever be written within 5 seconds is 11 GiB. It's reasonable to double or triple this number as a precaution, and to allow SSD wear leveling to reduce the impact of this heavy write load. In my case I'll be sizing my ZIL to 30 GiB.

So I have a pair of 200 GB SSDs, of which I only need 30 GiB for ZIL. I'm going to do the cautious thing and mirror my ZIL, so that if the system loses power and a drive fails, the ZIL will still be safe on another drive. That leaves me with 312.5 GiB of SSD space to do something with. That something will be L2ARC.

Before going crazy and adding lots of L2ARC keep in mind RAM requirements. As a rule of thumb it's going to take at least 1 GiB of ARC (RAM) to index every 10 GiB of L2ARC. In my case that means indexing this L2ARC will need about 32 GiB of RAM. That's fine on this box, since it's filled with 256 GiB of RAM.

So now to the meat and potatoes of how to get this done. To begin with, create a pool in FreeNAS normally. Do not add the SSDs to the pool. In my case, it's an 8 Disk RaidZ2.

Now SSH into your FreeNAS and determine what geom your SSDs are on, in my case they are da8 and da9. First thing to do is initialize these disks with a partition table.

```
[root@freenas] ~# gpart create -s gpt da8
da8 created
[root@freenas] ~# gpart create -s gpt da9
da9 created
```

Next create the ZIL partitions, in my case 30 GiB. I'm creating partitions using the same [commands](https://github.com/freenas/freenas/blob/a77b818f2498257a5c7617c8895a07cf0a6c1643/gui/middleware/notifier.py) used by the FreeNAS GUI. The `-a 4k` makes sure the partitions are 4k alligned. The `-b 128` startsthe first partition at 128 bytes into the disk. I believe this has to do with making sure that EFI or BIOS don't try to boot from this drive. `-t freebsd-zfs` sets the partition type. And `-s 30G` sets the size.

```
[root@freenas] ~# gpart add -a 4k -b 128 -t freebsd-zfs -s 30G da8
da8p1 added
[root@freenas] ~# gpart add -a 4k -b 128 -t freebsd-zfs -s 30G da9
da9p1 added
```

Now create the L2ARC partitions. Omitting the size parameter will make the partition use what's left of the disk.

```
[root@freenas] ~# gpart add -a 4k -t freebsd-zfs da8
da8p2 added
[root@freenas] ~# gpart add -a 4k -t freebsd-zfs da9
da9p2 added
```

Sometimes the disk number assignments are unreliable. This is why FreeNAS always uses the partition GUIDs to create pools. I intend to do the same thing here. Start by getting the GUIDs for your new partitions with `gpart show da8`. Make note of the rawuuid value for your two partitions.

Add your ZIL mirror to your pool using the UUIDs you recorded.

```
[root@freenas] ~# zpool add tank log mirror gptid/<guid for da8p1> gptid/<guid for da9p1>
```

Add your L2ARC devices to your pool.

```
[root@freenas] ~# zpool add tank cache gptid/<guid for da8p2>
[root@freenas] ~# zpool add tank cache gptid/<guid for da9p2>
```

And that's it. You now have a ZFS pool using a pair of drives for both ZIL and L2ARC.
