---
layout: post
title: Managing Users with Salt
---

One of the great things about a configuration management solution like Salt is the ability to centrally manage local users. Sure LDAP and Kerberos are great, but sometimes it's better to keep things simple, that's what I'm doing with Salt. Leveraging Pillars I can define certain users to be added to servers of a given role. Here's how I do it.

Start by defining a users pillar:

```sls
# /srv/pillar/top.sls
base:
  '*':
    - users
```

And define your users:

```sls
# /srv/pillar/users.sls
users:
  tywin:
    fullname: Tywin Lannister
    uid: 1100
  {% if salt['pillar.get']('role', 'default') == 'webserver' %}
  tyrion:
    fullname: Tyrion Lannister
    uid: 1101
  {% endif %}
  {% if salt['pillar.get']('role', 'default') == 'database' %}
  cersei:
    fullname: Cersei Lannister
    uid: 1102
  {% endif %}

revokedusers:
  robb:
    fullname: Robb Stark
    uid: 2001
```
