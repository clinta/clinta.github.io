---
layout: post
title: Managing Users with Salt
redirect_from: "2015-1-22-Salt-User-Management"
---

This post has been updated. Though I thought I had properly tested my implementation of role specific users, it was wrong. Using pillars to set pillars is apparently impossible. As a result, I've redesigned my user management methods. If you'd like to see what this guide looked like before, the history is all on github.

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
{% raw %}
# /srv/pillar/users/admins.sls
users:
  tywin:
    fullname: Tywin Lannister
    uid: 1100
```

```sls
{% raw %}
# /srv/pillar/users/revokedusers.sls
revokedusers:
  robb:
    fullname: Robb Stark
    uid: 2001
{% endraw %}
```

```sls
{% raw %}
# /srv/pillar/users/webadmins.sls
users:
  tyrion:
    fullname: Tyrion Lannister
    uid: 1101
{% endraw %}
```

```sls
{% raw %}
# /srv/pillar/users/dbadmins.sls
  cersei:
    fullname: Cersei Lannister
    uid: 1102
{% endraw %}
```

It should be fairly self-explanatory how this works. Tywin is added to every server. Tyrion is only added to webservers and Cersei is only added to database servers. Robb has been fired and his access to all servers has been revoked.

Now the logic for adding these users.

```sls
{% raw %}
# /srv/states/users/init.sls
{% if pillar['revokedusers'] != None %}
{% for user, args in pillar['revokedusers'].iteritems() %}
{{user}}:
  user.absent: []
  group.absent: []

{{user}}_root_key:
  ssh_auth.absent:
    - user: root
    - source: salt://users/files/ssh/{{user}}.id_rsa.pub

{{user}}_key:
  ssh_auth.absent:
    - user: {{user}}
    - source: salt://users/files/ssh/{{user}}.id_rsa.pub
{% endfor %}
{% endif %}

# Add users
{% for user, args in pillar['users'].iteritems() %}
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

{{user}}_root_key:
  ssh_auth.present:
    - user: root
    - source: salt://users/files/ssh/{{user}}.id_rsa.pub

{{user}}_key:
  ssh_auth.present:
    - user: {{user}}
    - source: salt://users/files/ssh/{{user}}.id_rsa.pub
{% endfor %}

# Allow sudoers to sudo without passwords.
# This is to avoid having to manage passwords in addition to keys
/etc/sudoers.d/sudonopasswd:
  file.managed:
    - source: salt://users/files/sudoers.d/sudonopasswd
    - user: root
    - group: root
    - mode: 440
{% endraw %}
```

The first section removes any revoked users, and removed revoked users ssh keys from the root account, as well as their own.

The second section adds any users in the users pillar to the system. It also adds their keys to the root account. This isn't ideal, but I've not found any other way to allow users to edit files over scp. Running `vim scp://root@server//etc/file` is very useful, and simply doesn't work with sudo.

Lastly, hashing passwords and putting that value into the pillar to define it wouldn't be difficult. But it does make it difficult for users to change their passwords. And with encrypted ssh keys, it seems unnecessary to me. So I push out a final config to allow users to sudo without a password, since no password is defined in the first place.
