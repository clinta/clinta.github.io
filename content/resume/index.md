---
layout: single
title: Clint Armstrong
email: clint@clintarmstrong.net
layout: resume
permalink: /resume/
date: 2019-06-05
blackfriday:
  fractions: false
# Be sure and update the pdf when updating this
---

{{< span class="pdfLink">}}[Download](/resume.pdf "Download PDF"){{< /span >}}

{{< resPage >}}

{{< resSection >}}
IT Systems and Operations engineer with expertise in building and maintaining
business critical infrastructure in a variety of environments. Utilizing open
source software I build reliable systems and networks that empower businesses to
be more agile and do more with less. Programming experience building solutions
in Go and Python.
{{< /resSection >}}

{{< resSection "Work Experience" >}}
01/2015 - Present
:    **DevOps Engineer** Trillium Staffing, Kalamazoo, MI
:    Head engineer responsible for networking, servers and cloud services.
     * Facilitated a corporate big-data initiative building an open source,
         hyperconverged cluster on top of [Nomad](https://www.nomadproject.io/),
         [Docker](https://www.docker.com/), and [Ceph](https://ceph.com/), and wrote
         several plugins and contributions to these projects to integrate them.
     * Replaced a Cisco hub-and-spoke branch VPN solution with a full mesh DMVPN
         between over 100 branch offices using Linux on commodity hardware.
     * Achieved datacenter IP redundancy using Linux to peer with multiple ISPs
         and announce provider independent IP space via BGP.
     * Introduced and standardized configuration management on a wide deployment
         of Linux servers improving security and maintainability.

12/2011 - 01/2015
:    **Professional Services Engineer** Secant Technologies, Kalamazoo, MI
:    On-Site and Remote consulting, support and engineering.
     * Frequently engaged to perform infrastructure upgrades of SANs,
         datacenter switches and vSphere clusters.
     * Performed migration projects for business services including email,
         databases and identity.

01/2011 - 12/2011
:    **Microsoft Systems Administrator** Liberty University, Lynchburg, VA
:    Responsible for design and maintenance of Active Directory, Exchange,
     and all other critical Microsoft services.
     * Migrated a 350,000 user environment from Exchange 2007 to a hybrid
       Office 365 and Exchange 2010 deployment.
{{< /resSection >}}
{{< /resPage >}}

{{< resPage break="1" >}}

{{< resSection "Work Experience (continued)" "onlyPrint">}}
2008 - 2011
:    **Desktop Configuration Administrator** Liberty University, Lynchburg, VA
:    Managed the centralized configuration of over 5000 workstations across
     campus.
     * Implemented and managed Microsoft System Center Configuration Manager
       2007 for management of over 5000 workstations.
     * Implemented Microsoft Windows Deployment Services with a custom front-end
       to provide advanced automated imaging workflows for Support Technicians.

2008
:    **Desk-Side Support Technician** Liberty University, Lynchburg, VA
:    On-Site support technician
<ul/>

2005 - 2007
:    **IT Technician** Comstock Public Schools, Kalamazoo, MI
:    Remote and on-site support technician
<ul/>
{{< /resSection >}}

{{< resSection "Open Source" >}}
See my complete portfolio of open source work at https://github.com/clinta/.
:    

**[vxrouter](https://github.com/TrilliumIT/vxrouter)**
:    A docker network and IPAM plugin that connects containers to VXLANs using
     MacVLAN devices. Designed to be used with a routing protocol like BGP to
     coordinate IPAM across a cluster of hosts.

**[go-multiping](https://github.com/TrilliumIT/go-multiping)**
:    An ICMP library designed to ping multiple hosts efficiently in go.
     Improves on existing libraries by pinging multiple hosts while using a single
     raw-socket in the kernel.

**[updog](https://github.com/TrilliumIT/updog)**
:    A simple monitoring system that uses HTTP or TCP checks and logs data to
     [Bosun](https://bosun.org/).

**[iputil](https://github.com/TrilliumIT/iputil)**
:    A go library for common operations on IP addresses.

**[go-zfs](https://github.com/clinta/go-zfs)**
:    A go library for manipulating ZFS filesystems.

**[salt-pwgen](https://github.com/clinta/salt-pwgen)**
:    A salt module for generating random passwords and storing them in
     [pass](https://www.passwordstore.org/).

**[salt](https://github.com/saltstack/salt/pulls?q=is%3Apr+author%3Aclinta)**
:    Wrote the [x509 module](https://docs.saltstack.com/en/latest/ref/states/all/salt.states.x509.html) and contributed several bug fixes.

**[containernetworking/plugins (CNI Networking)](https://github.com/containernetworking/plugins/pulls?q=is%3Apr+author%3Aclinta)**
:    Added functionality for managing mac addresses of connected containers
{{< /resSection >}}
{{< /resPage >}}
