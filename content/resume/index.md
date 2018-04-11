---
layout: single
title: Résumé
permalink: /resume/
date: 2018-04-08
blackfriday:
  fractions: false
---

Clint Armstrong
===============

Open Source
----------
----------
**[go-multiping](https://github.com/TrilliumIT/go-multiping)**
:    An icmp library designed to ping multiple hosts efficiently in go.
     Improves on existing libraries by pinging multiple while using a single
     raw-socket in the kernel. This was created to improve the icmp module in
     [Bosun](https://github.com/bosun-monitor/bosun) and there is an open
     [PR](https://github.com/bosun-monitor/bosun/pull/2238) to implement it.

**[vxrouter](https://github.com/TrilliumIT/vxrouter)**
:    A docker network and ipam plugin that connects containers to vxlans using
     macvlan devices. It coordinates IPAM in a cluster by inserting /32 routes
     to each container into the kernel routing table, which can be
     redistributed through the network via a routing protocol of the admin's
     choosing. In our case BGB using bird.

**[iputil](https://github.com/TrilliumIT/iputil)**
:    A go library for common operations on IP addresses, like adding or
     subtracting from an address, or generating random addresses.

**[updog](https://github.com/TrilliumIT/updog)**
:    A simple monitoring system that uses http or tcp checks and logs data to
     bosun.

**[geliUnlocker](https://github.com/clinta/geliUnlocker)**
:    An rc.d script for FreeBSD which automates unlocking geli encrypted disks
     using a key and password stored on a remote server accessible via scp.

**[genify](https://github.com/clinta/genify)**
:    A go code generator to simulate generics.

**[go-zfs](https://github.com/clinta/go-zfs)**
:    A go library for manipulating zfs filesystems.

**[docker-vxlan-plugin](https://github.com/TrilliumIT/docker-vxlan-plugin)**
:    A docker plugin for connecting containers to vxlan networks.

**[docker-drouter](https://github.com/TrilliumIT/docker-drouter)**
:    A container based routing platform which injects routes to other container
     networks into each container namespace.

**[docker-arp-ipam](https://github.com/TrilliumIT/docker-arp-ipam)**
:    A docker ipam plugin which uses the arp cache to determine which IP
     addresses are in use.

**[salt-pwgen](https://github.com/clinta/salt-pwgen)**
:    A salt module for generating random passwords and storing them in
     [pass](https://www.passwordstore.org/).

**Other minor contributions**
:
   * [Many](https://github.com/saltstack/salt/pulls?q=is%3Apr+author%3Aclinta)
     bug fixes and contributions to
     [SaltStack](https://github.com/saltstack/salt).
   * [Fixed](https://github.com/hashicorp/nomad/pull/3081) a issue in
     [Nomad](https://github.com/hashicorp/nomad) that prevented jobs from being
     updated.
   * [Added](https://github.com/bosun-monitor/bosun/pull/2095) per region stats
     for hbase to [Bosun](https://github.com/bosun-monitor/bosun).
   * [Added](https://github.com/iocage/iocage/pull/94) the ability to add
     multiple IP addresses to jails in
     [iocage](https://github.com/iocage/iocage).
   * [Merged](https://github.com/PIVX-Project/PIVX/pull/85) an upstream bug fix
     from [Dash](https://github.com/dashpay/dash) into
     [Pivx](https://github.com/PIVX-Project/PIVX).
   * [Added](https://github.com/xenolf/lego/pull/296) memcached provider to
     [lego](https://github.com/xenolf/lego) LetsEncrypt client.
   * [Fixed](https://github.com/docker/libnetwork/pull/1289) a
     [bug](https://github.com/docker/libnetwork/issues/1288) in
     [docker/libnetwork](https://github.com/docker/libnetwork) that resulted in
     incorrect routes being added to containers.

Work Experience
----------
----------

01/2015 - Present
:    **Systems Engineer** Trillium Staffing, Kalamazoo, MI
:    Primary technical resource for managing Networking, Servers and cloud
     services.

     * Built an open-source big data cluster using Docker, Nomad, Ceph and many
       in-house plugins to tie them together.
     * Built a full mesh DMVPN network between over 100 branch offices using
       Linux on commodity hardware.
     * Managed a Citrix environment providing desktops for over 200 users.
       Handled upgrades between several major version of both Citrix and Windows
       Server.
     * Built a modern container cluster for running services on Linux.
     * Migrated communications services from on premis Microsoft Exchange and
       Sharepoint to Office 365.
     * Built a [solution](diy-sbs-for-Office-365-Unified-Messaging) for
       integrating Office 365 Unified Messaging using open source software.  and
       Cisco Unified Communications with only open source software.
     * Handled upgrades of multiple clusters between major versions of Vmware
       Vsphere.
     * Handled a migration between physical datacenters.
     * Migrated from provider IP space to BGP peering with multiple providers
       using provider independant IPs.
     * Wrote and contributed multiple modules for SaltStack to manage our linux
       servers and workstations.

----------

12/2011 - 01/2015
:    **Professional Services Engineer** Secant Technologies, Kalamazoo, MI
:    Provided services to customers including on-site visits to check health of
     network and servers and lead infrastructure upgrade projects.

     * Frequent repairs of unhealthy Active Directory infrastructure including
       correcting AD Site topology, forcibly removing failed domain controllers,
       and troubleshooting and repairing DNS and DHCP.
     * Many implementations of multi-host VSphere deployments with iSCSI, Fibre
       Chanel and SAS based shared storage.
     * Sole engineer on many server virtualization and upgrade projects for
       Active Directory versions 2008R2 and 2012, Exchange 2010 and 2013,
       various version of Microsoft SQL and other line of business applications.
     * Engaged in long term support for a large company coordinating migrations
       to accommodate a corporate acquisition. Included Exchange and Active
       Directory migrations, workstation inventory and replacement, and user
       support coordination.

----------

01/2011 - 12/2011
:    **Microsoft Systems Administrator** Liberty University, Lynchburg, VA
:    Primary Administrator responsible for design and maintenance of Active
     Directory, Exchange, Active Directory Federation Services, Forefront
     Unified Access Gateway and Public Key Infrastructure

     * Lead technician in project to migrate from an on-premises Exchange 2007
       environment to a hybrid oexistent deployment with 350,000 student user
       accounts in the cloud on Microsoft Office 365 and 000 Faculty and Staff
       accounts in on-premises Exchange 2010.
     * Implemented Forefront Unified Access Gateway to secure external
       authentication to Sharepoint and ther internal web services.
     * Implemented Active Directory Federation Services to provide single sign
       on for several external ervices.
     * Participated in implementation PCI security requirements for storage of
       sensitive data on infrastructure servers. 

----------

2008 - 2011
:    **Desktop Configuration Administrator** Liberty University, Lynchburg, VA
:    Managed the centralized configuration of over 5000 workstations across
     campus.

     * Implemented and managed Microsoft System Center Configuration Manager
       2007 for management of over 5000 workstations.
     * Implemented Microsoft Windows Deployment Services with a custom front-end
       to provide PXE booting and advanced automated imaging workflows to
       increase productivity for On-Site Support Technicians.
     * Repackaged and made the university software library available for
       installation via SCCM or Group Policy, improving efficiency for support
       departments by allowing self-service installations for users.
     * Created and maintained operating system images for Windows XP, Windows
       Vista and Windows 7.   Created and maintained Active Directory Group
       Policies for workstations.
     * Managed Windows Updates for workstations via Windows Server Update
       Services.
     * Automated repetitive business processes and client operations with
       VBScript and PowerShell.
     * Participated in committees coordinating the implementation of Information
       Technology Infrastructure Library (ITIL) business process throughout IT.

----------

2008
:    **Desk-Side Support Technician** Liberty University, Lynchburg, VA
:    Provided desk side support for escalated IT tickets.

     * Operated as top-tier technical support troubleshooting hardware, software
       and network issues which ould not be solved by remote support
       technicians.
     * Deployed and re-imaged workstations.

----------

2005 - 2007
:    **IT Technician** Comstock Public Schools, Kalamazoo, MI
:    Remote and on-site support technician

     * Created and maintained operating system images for Windows 98 and Windows
       XP.
     * Managed software deployment via Novell Zenworks.
     * Provided remote and on-site technical support.
