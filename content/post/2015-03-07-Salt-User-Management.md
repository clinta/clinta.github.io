---
layout: single
title: Managing Users with Salt
redirect_from:
slug: Salt-User-Management
aliases:
  - 2015-1-22-Salt-User-Management
  - 2015-1-28-Salt-User-Management
  - 2015-03-07-Salt-User-Management
  - 2015-3-07-Salt-User-Management
  - 2015-3-7-Salt-User-Management
date: 2015-03-07T09:38:00-05:00
---

This post has gone through a few iterations. You can see the full history on the github repo.

One of the great things about a configuration management solution like Salt is the ability to centrally manage local users. Sure LDAP and Kerberos are great, but sometimes it's better to keep things simple, that's what I'm doing with Salt. Leveraging Pillars I can define certain users to be added to servers of a given role. Here's how I do it.

Start by defining your users, separating and targeting by role.:

```sls 
# /srv/pillar/top.sls
base:
  '*':
    - users.admins
    - users.revokedusers

  'web*':
    - users.webadmins

  'db*':
    - users.dbadmins
```

And define your users:

```sls

# /srv/pillar/users/admins.sls
users:
  tywin:
    fullname: Tywin Lannister
    uid: 1100
    ssh-keys:
      - ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNWRiUmFXjxrp4VGfqWISvsEdxPJi2ES3gi6U/ZoVR3UpMUNGYm/VUTNjiXPX6XU5KjaSdGgeqDQdcwfAxl7q4A= tywin@CastRockWks1
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCllUe3Q14M1AwMyaGLaW0b3IyDyghljYzKlQE/osh0hjUCxqcjFW26DekBSF/RErYeJwlRPrGxWZAYLYW9ZMLolYJGAon1jBgNUAaSbj45m+sf8gFDWqpL6E0Vxzr4/o2A7NpqBsdwy95Xov0MGQq7wyJ7bEQ4b/TFo7Peb6oWoHGdDMbXym/T0UFiEH30w6XBIN34tRsV9DGmG3BpshI7ho5pNo1dO8xDD0Acr6blpOQKap02ihJKYBAdFDGfK4P3PUrhArEJvD8QU7Q7Fwl1Yej6Y54IMndTVf8i5CZNmUKh87Xawo4NRMaVPePoMInEYTiEkOYrILGkWRCT2GWb tywin@TLLap1

```

```sls

# /srv/pillar/users/revokedusers.sls
revokedusers:
  robb:
    fullname: Robb Stark
    uid: 2001
    ssh-keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFmuEiljWGa1W3/mgymLdEwCbkBcIaXZfik9uNQCzajW Robb@RSLap1

```

```sls

# /srv/pillar/users/webadmins.sls
users:
  tyrion:
    fullname: Tyrion Lannister
    uid: 1101
    ssh-keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIED4TtDwUcNZdhQwIxK4LOtn3Q/yQxlcvQKrZIBaOllQ tyrion@TSLap2

```

```sls

# /srv/pillar/users/dbadmins.sls
users:
  cersei:
    fullname: Cersei Lannister
    uid: 1102
    ssh-keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINZ9GpN4T3beWlRzfO27tYH7t13QhMRoKbmDR3nwwAWa cersei@CLLap1

```

It should be fairly self-explanatory how this works. Tywin is added to every server. Tyrion is only added to webservers and Cersei is only added to database servers. Robb has been fired and his access to all servers has been revoked.

Now the logic for adding these users.

```sls

# /srv/salt/users/init.sls

# Revoke any users with a role of revoked
{% for user, args in pillar.get('revokedusers', {}).iteritems() %}
{{user}}:
  user.absent: []
  group.absent: []

{% if args['ssh-keys'] %}
{{user}}_root_key:
  ssh_auth.absent:
    - user: root
    - names:
      {% for key in args['ssh-keys'] %}
      - {{ key }}
      {% endfor %}

{{user}}_key:
  ssh_auth.absent:
    - user: {{user}}
    - names:
      {% for key in args['ssh-keys'] %}
      - {{ key }}
      {% endfor %}
{% endif %}
{% endfor %}

# Add users
{% for user, args in pillar.get('users', {}).iteritems() %}
{{user}}:
  group.present:
    - gid: {{ args['uid'] }}
  user.present:
    - fullname: {{ args['fullname'] }}
    - uid: {{ args['uid'] }}
    - gid: {{ args['uid'] }}
    - shell: /bin/bash
    {% if grains['os'] == 'Ubuntu' %}
    - groups:
      - sudo
      - adm
      - dip
      - cdrom
      - plugdev
    {% endif %}

{% if args['ssh-keys'] %}
{{user}}_root_key:
  ssh_auth.present:
    - user: root
    - names:
      {% for key in args['ssh-keys'] %}
      - {{ key }}
      {% endfor %}

{{user}}_key:
  ssh_auth.present:
    - user: {{user}}
    - names:
      {% for key in args['ssh-keys'] %}
      - {{ key }}
      {% endfor %}
{% endif %}
{% endfor %}

# Allow sudoers to sudo without passwords.
# This is to avoid having to manage passwords in addition to keys
/etc/sudoers.d/sudonopasswd:
  file.managed:
    - source: salt://users/files/sudoers.d/sudonopasswd
    - user: root
    - group: root
    - mode: 440

```

The first section removes any revoked users, and removed revoked users ssh keys from the root account, as well as their own.

The second section adds any users in the users pillar to the system. It also adds their keys to the root account. This isn't ideal, but I've not found any other way to allow users to edit files over scp. Running `vim scp://root@server//etc/file` is very useful, and simply doesn't work with sudo.

Lastly, hashing passwords and putting that value into the pillar to define it wouldn't be difficult. But it does make it difficult for users to change their passwords. And with encrypted ssh keys, it seems unnecessary to me. So I push out a final config to allow users to sudo without a password, since no password is defined in the first place.

The file that's being managed to allow sudo without password is below:

```
# /srv/salt/users/files/sudoers.d/sudonopasswd
%sudo	ALL = (ALL) NOPASSWD: ALL
```
