---
layout: post
title: Random root passwords with saltstack.
date: 2015-09-24
aliases:
  - /posts/2015-09-24-random-local-passwords
  - /posts/2015-9-24-random-local-passwords
---

Common passwords for devices is a significant security risk, but maintaining unique passwords for every server is nearly impossible without some password manager. But manually generating passwords for hundreds of servers and putting them into a password manager is just not practical. Here is a way to have your salt master generate complex random passwords for each minion and store them in a password manager where you can retrieve them later.

The password manager I'll be using is [pass](http://www.passwordstore.org/). Pass is uniquely suited to this challenge because it relies on GPG and asymetric cryptography. This allows me to put my public GPG key on the salt master so that the salt master can encrypt passwords it generates, but the salt master doesn't have to store any private key that would allow it to ever decrypt the passwords after they've been generated.

First install pass using your operating system's package manager. It should pull in all GPG dependencies.

If you don't have a GPG key that you wish to use with pass, you must first create one on your workstation. Depending on your workstation it may take a long time to generate, you can make this faster by installing the `haveged` daemon to collect entropy. Choose to generate a key of type `RSA and RSA` and be sure to choose a strong passphrase. This passphrase and the key file are what will protect all your passwords in the future.

```bash
$ gpg --gen-key
```

Once you have a gpg key, initialize a password store.

```bash
$ pass init me@mydomain.com
```

You also need to initialize your password store as a git repo and add a git remote. The service account which runs your salt-master must also have read and write permissions to this git remote.

```bash
$ pass git init
$ pass git remote add origin git@gitserver:/passdb
$ pass git push
```

Export your gpg public key and copy it to your salt master.

```bash
$ gpg --armor --export me@mydomain.com > gpg.pub
```

In your salt master, install pass, then import your gpg public key and trust it. Run the commands under the user account that runs your salt-master service.

```
$ gpg --import gpg.pub
$ gpg --edit-key me@mydomain.com
gpg> trust
5
y
gpg> quit
```

On your salt master, install the [pwgen](https://github.com/clinta/salt-pwgen) extension module. Install this in your [extension modules](https://docs.saltstack.com/en/latest/ref/configuration/master.html#extension-modules) directory. These directions assume it is `/srv/modules`.

```bash
$ sudo wget https://raw.githubusercontent.com/clinta/salt-pwgen/master/pwgen.py -O /srv/modules/pwgen.py
```

Clone your password store to the salt master, using your salt-master service account. In my case I'm cloning it to /opt/passdb

```bash
$ cd /opt
$ git clone git@gitserver:/passdb
```

Now you are ready to start generating passwords. Here's how it will work. A pillar will be defined with a jinja template which calls this extension module. When the salt master compiles the pillar it will run the extension module. The extension module checks for the existence of a meta file which holds the unix password hash as well as a sha256 of the .gpg file which contains the encrypted plaintext password. If the meta file does not exist, or the .gpg file doesn't exist, or the sha256 in the meta file doesn't match the .gpg file, it calls pass to generate a new password and writes the unix hash of this password and the sha256 of the new .gpg file to the meta file. It then returns the unix hash which is the value of the pillar. If the meta file does exist, and matches the .gpg file, the unix hash from the meta file is returned for the value of the pillar.

Create your pillar template:

```sls
{% raw %}
# /srv/pillar/root-pw.sls
root-pw: {{ salt['pwgen.get_pw'](pw_name='local-root/'+grains['host'], pw_store='/opt/passdb', pw_meta_dir='/opt/pw_meta') }}
{% endraw %}
```

And apply this pillar via the pillar top file:

```sls
# /srv/pillar/top.sls

base:
  '*':
    - root-pw
```

At this point you should be able to highstate a minion, then on the minion run `salt-call pillar.get root-pw` and get back a unix hash of a unique password. You can get the plaintext of this password on your workstation:

```bash
$ pass git pull
$ pass local-root/minion
```

Once you know this is working, you can use this unix hash to set the root password on your minions with a simple state:

```sls
{% raw %}
# /srv/salt/root-pw.sls

root:
  user.present:
    - password: {{ salt['pillar.get']('root-pw') }}
{% endraw %}
```

Make sure this state is applied via your top file, highstate all your minions and you will now have all their unique passwords in your password store.
