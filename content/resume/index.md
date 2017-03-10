---
layout: single
title: Résumé
permalink: /resume/
date: 2016-10-06
blackfriday:
  fractions: false
---

Clint Armstrong
===============

Work Experience
----------
----------

01/2015 - Present
:    **Network Administrator** Trillium Staffing, Kalamazoo, MI
:    Primary technical resource for managing Networking, Servers and cloud
     services.

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
     * Wrote multiple docker plugins to built our container cluster.

12/2011 - 01/2015
:    **Professional Services Engineer** Secant Techologies, Kalamazoo, MI
:    Provided services to customers including NetPro visits to check health of
     network and server and leading upgrade projects to server infrastructure.

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

2008 - 2011
:    **Desktop Configuration Administrator** Liberty University, Lynchburg, VA
:    Managed the centeralized configuration of over 5000 workstations across
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

2008
:    **Desk-Side Support Technician** Liberty University, Lynchburg, VA
:    Provided desk side support for escalated IT tickets.

     * Operated as top-tier technical support troubleshooting hardware, software
       and network issues which ould not be solved by remote support
       technicians.
     * Deployed and re-imaged workstations.

2005 - 2007
:    **IT Technician** Comstock Public Schools, Kalamazoo, MI
:    Remote and on-site support technician

     * Created and maintained operating system images for Windows 98 and Windows
       XP.
     * Managed software deployment via Novell Zenworks.
     * Provided remote and on-site technical support.

Open Source Projects
----------
----------

**[undocker-dns](https://github.com/TrilliumIT/undocker-dns)**
:    A small daemon to keep Docker from changing the dns server in a container.

**[docker-vxlan-plugin](https://github.com/TrilliumIT/docker-vxlan-plugin)**
:    A plugin for connecting docker containers to vxlan overlay networks.

**[docker-arp-ipam](https://github.com/TrilliumIT/docker-arp-ipam)**
:    A docker IPAM plugin to assign IP addresses to containers based on which
     addresses are already in use on the network.

**[docker-drouter](https://github.com/TrilliumIT/docker-drouter)**
:    Co-Authored a tool which monitors docker containers and manipulates their
     routing tables to facilitate efficient routing between containers on a
     cluster of hosts.

**[SaltStack](https://github.com/saltstack/salt/commits?author=clinta)**
:    Wrote the
     [x509](https://docs.saltstack.com/en/latest/ref/states/all/salt.states.x509.html)
     state and module which facilitates managing an internal x509 PKI with Salt.

**[docker-zfs-plugin](https://github.com/TrilliumIT/docker-zfs-plugin)**
:    Wrote the go zfs library which this project is based on, and Setup the
     continuous integration pipeline.

Technologies Used
----------
----------
Technologies I have experinece with include:

Linux, Ubuntu, FreeBSD, FreeNAS, ZFS, Windows Server, Go (GoLang), Python,
PowerShell, Bash, Docker, Cisco, BGP, OSPF, Bird, Kamailio, Microsoft Exchange,
Windows Server, Office 365
