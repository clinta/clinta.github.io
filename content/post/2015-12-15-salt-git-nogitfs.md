---
layout: post
title: Salt git integration without gitfs
date: 2015-12-15T15:45:00-05:00
slug: salt-git-nogitfs
aliases:
  - 2015-12-15-salt-git-nogitfs
---

[SaltStack](http://saltstack.com/) has some pretty cool git [integration](https://docs.saltstack.com/en/latest/topics/tutorials/gitfs.html). Unfortunately it also has quite a few [bugs](https://github.com/saltstack/salt/issues?utf8=%E2%9C%93&q=is%3Aissue+is%3Aopen+gitfs), especially when using gitfs for pillars.

These issues can be annoying at small scale, but they can become very important as you add more minions. To work around these I looked for ways I could simplify our salt/git integration and now that it's complete I couldn't be happier.

With a post-receive hook on my gitlab server and a salt master that is also a minion, the salt server updates it's file root's directory from git without the salt-master process having to do any interfacing with git at all. As a result applying states through our environment of nearly 200 minions is faster and more reliable than it ever was with gitfs.

I even have some features that I never had with gitfs, like automatic environments based on branches. Here's how it works.

My salt master has the following state applied. This state ensures that the salt-master service is running. It gets the list of branches from the git remote and makes sure that that branch is cloned into a directory under `/srv/salt/`. It also manages a file in `/etc/salt/master.d/roots.conf` which defines each environment that has been cloned and restarts the salt-master process when the file changes. This uses one git repository for both states and pillars, so states are in the `repo/states` directory and pillars are in the `repo/pillar` directory.

```sls

# repo/states/salt-master-git.sls

salt-master:
  service.running:
    - enable: True

/srv/salt:
  file.directory: []

# get the list of remote branches
{% set branches = [] %}
{% for origin_branch in salt['git.ls_remote'](remote='git@gitlab:salt/salt.git', opts='--heads', user='root') %}
  {% set i = branches.append(origin_branch.replace('refs/heads/', '')) %}
{% endfor %}

# delete any directories that are no longer remote branches
{% for dir in salt['file.find']('/srv/', type='d', maxdepth=1)
if dir.startswith('/srv/salt/') and dir.split('/')[-1] not in branches %}
{{ dir }}:
  file.absent:
    - require_in:
      - file: /etc/salt/master.d/roots.conf
{% endfor %}

# clone each branch
{% for branch in branches %}
salt-repo-{{ branch }}:
  git.latest:
    - name: git@gitlab:salt/salt.git
    - target: /srv/salt/{{ branch }}
    - rev: {{ branch }}
    - branch: {{ branch }}
    - user: root
    - force_checkout: True
    - force_clone: True
    - force_fetch: True
    - force_reset: True
    - require:
      - file: /srv/salt
    - require_in:
      - file: /etc/salt/master.d/roots.conf
{% endfor %}

# manage the file_roots config to generate environments
/etc/salt/master.d/roots.conf:
  file.managed:
    - template: jinja
    - source: salt://{{ tpldir }}/files/roots.conf
    - user: root
    - mode: 644
    - listen_in:
      - service: salt-master

```

```sls

# repo/states/files/roots.conf

{%- set branch_dirs = [] -%}
{%- for dir in salt['file.find']('/srv/', type='d', maxdepth=1) 
if dir.startswith('/srv/salt/') and dir != '/srv/salt/master' -%}
  {%- set i = branch_dirs.append(dir) -%}
{%- endfor -%}

file_roots:
  base:
    - /srv/salt/master/states
{%- for branch in branch_dirs if branch != 'master' %}
  {{ branch }}:
    - {{ branch }}/states
{%- endfor %}

pillar_roots:
  base:
    - /srv/salt/master/pillar
{%- for branch in branch_dirs if branch != 'master' %}
  {{ branch }}:
    - {{ branch }}/pillar
{%- endfor %}

```

With just this and a schedule you already have an okay salt-git integration. But with a little more work you can take it to the next step and make it event driven on git push.

If you're using gitlab for your salt repository, you can create a post-recieve script by putting a file in `/var/opt/gitlab/git-data/repositories/salt/salt.git/custom_hooks/post-receive`.

```bash

#!/usr/bin/env bash                                                        
 
while read branch; do                                                      
        branchname=$(cut -d "/" -f 3 <<< "${branch}")                      
        sudo salt-call event.send salt/push branch=${branchname}           
done                                                                       

```

Now in your salt master config, add a reactor:

```sls

# /etc/salt/master

reactor:
  - 'salt/push':
     - salt://reactor/salt-push.sls

```

Add the reactor file in your git repo.

```sls

# repo/states/reactor/salt-push.sls

salt-push:
  local.state.sls:
    - tgt: 'salt-master'
    - expr_form: pcre
    - queue: True
    - kwarg:
        mods: salt.master.salt-git
        pillar:
          salt_git_branches:
            - {{ data['data']['branch'] }}
        queue: True

```

And add a bit more logic to the salt-master-git.sls to handle the individual branch being pushed. With this logic if the pillar `salt_git_branches` is included in the state run, the state will only update that branch. If it is not included, the state will update all branches, and clean up old deleted branches. This saves some time which is important when it's being called by a post-recieve hook.

```sls

# repo/states/salt-master-git.sls

salt-master:
  service.running:
    - enable: True

/srv/salt:
  file.directory: []

{% set branches = salt['pillar.get']('salt_git_branches',[]) %}

# if a piller was not passed in, then get the list of branches from remote
{% if branches == [] %}
  {% for origin_branch in salt['git.ls_remote'](remote='git@gitlab:salt/salt.git', opts='--heads', user='root') %}
    {% set i = branches.append(origin_branch.replace('refs/heads/', '')) %}
  {% endfor %}

# Delete directories of deleted branches since we're looking at all remote branches
{% for dir in salt['file.find']('/srv/', type='d', maxdepth=1)
if dir.startswith('/srv/salt/') and dir.split('/')[-1] not in branches %}
{{ dir }}:
  file.absent:
    - require_in:
      - file: /etc/salt/master.d/roots.conf
{% endfor %}

{% endif %}

{% for branch in branches %}
salt-repo-{{ branch }}:
  git.latest:
    - name: git@gitlab:salt/salt.git
    - target: /srv/salt/{{ branch }}
    - rev: {{ branch }}
    - branch: {{ branch }}
    - user: root
    - force_checkout: True
    - force_clone: True
    - force_fetch: True
    - force_reset: True
    - require:
      - file: /srv/salt
    - require_in:
      - file: /etc/salt/master.d/roots.conf
{% endfor %}

/etc/salt/master.d/roots.conf:
  file.managed:
    - template: jinja
    - source: salt://{{ tpldir }}/files/roots.conf
    - user: root
    - mode: 644
    - listen_in:
      - service: salt-master

```

Now enjoy the best of both worlds. Automatic integration between salt and git and the reliability and speed of a simple file_roots configuration.
