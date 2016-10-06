---
layout: post
title: Creating a Secure Corporate Apt Repository with Salt
date: 2015-04-04T10:04:00-05:00
aliases:
  - /posts/2015-04-04-secure-corporate-apt-repo
  - /posts/2015-4-04-secure-corporate-apt-repo
  - /posts/2015-4-4-secure-corporate-apt-repo
---

There are many reasons an organization could use it's own internal apt repository. But controlling access to this repository for clients that are outside your internal network can be difficult. But if your repository contains proprietary or confidential packages, securing access is not optional. Thankfully apt supports client authentication with SSL certificates. And with the new [x509](http://docs.saltstack.com/en/latest/ref/states/all/salt.states.x509.html) module, managing these certificates can be made fully automatic.

The x509 module is not yet in the latest release of salt, so you'll need to manually add it to your custom paths.

```bash
cd /srv/salt/_modules
wget https://raw.githubusercontent.com/saltstack/salt/develop/salt/modules/x509.py
cd /srv/salt/_states
wget https://raw.githubusercontent.com/saltstack/salt/develop/salt/states/x509.py
```
Now setup targeting in the top file.

/srv/salt/top.sls

```sls
base:
  'ca':
    - ca.server
  'aptrepo':
    - aptrepo.server
  '*':
    - aptrepo.client
```

First the CA needs to be configured. It will need to create a CA private key and certificate,
then publish that certificate to the mine where other minions will get it. It will also need
to have a signing policy which allows the apt server and clients to get signed certificates.

Start by creating the signing policy configuraiton.

/srv/salt/pki/files/signing_policies.conf

```sls
x509_signing_policies:
  aptrepo_server:
    - minions: 'aptrepo'
    - signing_private_key: /etc/pki/aptrepo.key
    - signing_cert: /etc/pki/aptrepo.crt
    - C: US
    - ST: Utah
    - basicConstraints: "critical CA:false"
    - keyUsage: "keyEncipherment, dataEncipherment, keyAgreement, digitalSignature"
    - extendedKeyUsage: "critical serverAuth,clientAuth"
    - subjectKeyIdentifier: hash
    - authorityKeyIdentifier: keyid,issuer:always
    - days_valid: 90
    - copypath: /etc/pki/aptrepo_issued_certs/
  aptrepo_client:
    - minions: '*'
    - signing_private_key: /etc/pki/aptrepo.key
    - signing_cert: /etc/pki/aptrepo.crt
    - C: US
    - ST: Utah
    - basicConstraints: "critical CA:false"
    - keyUsage: "keyEncipherment, dataEncipherment, keyAgreement, digitalSignature"
    - extendedKeyUsage: "critical clientAuth"
    - subjectKeyIdentifier: hash
    - authorityKeyIdentifier: keyid,issuer:always
    - days_valid: 30
    - copypath: /etc/pki/aptrepo_issued_certs/
```

Note that in the below state I'm triggering a restart of the salt-minion service when the
configuration changes. You'll need another state managing the status of salt-minion for this to work.

/srv/salt/pki/server.sls

```sls
/etc/pki:
  file.directory:
    - user: root
    - group: root
    - mode: 700

/etc/salt/minion.d/signing_policies.conf:
      file.managed:
        - source: salt://pki/files/signing_policies.conf
        - listen_in:
          - service: salt-minion

/etc/pki/aptrepo.key:
  x509.private_key_managed:
    - bits: 4096
    - backup: True

/etc/pki/aptrepo.crt:
  x509.certificate_managed:
    - signing_private_key: /etc/pki/aptrepo.key
    - CN: Internal AptRepo
    - C: US
    - ST: Utah
    - basicConstraints: "critical CA:true"
    - keyUsage: "critical cRLSign, keyCertSign"
    - subjectKeyIdentifier: hash
    - authorityKeyIdentifier: keyid,issuer:always
    - days_valid: 1095
    - days_remaining: 30
    - backup: True

/etc/pki/aptrepo_issued_certs:
  file.directory:
    - user: root
    - group: root
    - mode: 700

mine.send:
  module.run: 
    - name: mine.send
    - func: x509.get_pem_entries
    - kwargs:
        glob_path: /etc/pki/*.crt
    - onchanges:
      - x509: /etc/pki/aptrepo.crt
```

To create the repository I'll be using reprepro. A good gude to configuring reprepro can be found
[here](http://vincent.bernat.im/en/blog/2014-local-apt-repositories.htmlGNUPGHOME=gpg) 
Reprepro requires some configuration files to define the distributions and components.
Here are these config files which salt will manage.

/srv/salt/aptrepo/server/files/conf/distributions

```
# Internal Trusty Packages
Origin: Internal #
Label: prod
Suite: trusty-prod
Codename: trusty-prod
Architectures: i386 amd64 source
Components: main
Description: Internal Trusty prod repository
Contents: .gz .bz2
Tracking: keep
SignWith: yes
Log: packages.trusty-prod.log
```

/srv/salt/aptrepro/server/files/conf/incoming

```
Name: incoming
IncomingDir: /srv/packages/incoming
TempDir: /srv/packages/tmp
Default: prod
```

/srv/salt/aptrepro/server/files/conf/options

```
outdir +b/www
logdir +b/logs
gnupghome +b/gpg
```

To sign packages added to the repository, gpg keys are required. Personally I opted to create
the GPG keys locally, then copy them to the salt server where they will be managed.

```bash
cd /srv/salt/aptrepo/server/files
mkdir gpg
GNUPGHOME=gpg gpg --gen-key  # Make sure and use an empty password
```

Another file that needs to be managed is the NGINX configuration file.
Notice the `ssl_verify_client on;`, this is what enables client authentication.

/srv/salt/aptrepo/server/files/nginx-default

```
server {
    listen	443;
    ssl on;
    ssl_certificate      /etc/nginx/certs/server.crt;
    ssl_certificate_key  /etc/nginx/certs/server.key;
    ssl_client_certificate /etc/nginx/certs/aptrepo_ca.crt;
    ssl_verify_client on;

    ## Let your repository be the root directory
    root        /srv/packages/www;
    autoindex on;

    ## Always good to log
    access_log  /var/log/nginx/repo.access.log;
    error_log   /var/log/nginx/repo.error.log;
}
```

Lastly, a script which will automatically import packages added to the incoming directory.
Salt will create a cron job that regularly runs this script. Now adding packages to the internal
repository is a simple matter of SCPing them to the incoming directory on the aptrepo server.

/srv/salt/aptrepo/server/files/processincoming.sh

```bash
#!/bin/sh
cd /srv/packages

for f in incoming/*.deb
do
	reprepro -C main includedeb trusty-prod $f
	rm $f
done
```

Now we're ready to put it all together with a salt state.

/srv/salt/aptrepo/server/init.sls

```sls

# Install the GPG package needed to sign packages
gnupg:
  pkg.installed: []

# Install the dpkg-sig package also needd to sign packages
dpkg-sig:
  pkg.installed: []

# Install nginx which will be used to serve the packages
nginx:
  pkg.installed: []
  service.running:
    - enable: True
    - require:
      - pkg: nginx

# Add a reprepro user
reprepro:
  user.present:
    - system: True
    - home: /srv/packages
  pkg.installed: []

# Configure nginx, restart the nginx service when this file changes
/etc/nginx/sites-available/default:
  file.managed:
    - source: salt://aptrepo/server/files/nginx-default
    - listen_in:
      - service: nginx

# Manage the reprepro configuration files
/srv/packages/conf:
  file.recurse:
    - makedirs: True
    - source: salt://aptrepo/server/files/conf
    - user: reprepro
    - group: reprepro
    
# Copy the GPG keys that will be used to sign packages
/srv/packages/gpg:
  file.recurse:
    - source: salt://aptrepo/server/files/gpg
    - makedirs: True
    - user: reprepro
    - group: reprepro

# Copy the public key into a location where it will be served by NGINX so that clients can get it.
/srv/packages/www/public.gpg.key:
  file.managed:
    - source: salt://aptrepo/server/files/gpg/public.gpg.key
    - makedirs: True
    - user: reprepro
    - group: reprepro

# Create a logging directory
/srv/packages/logs:
  file.directory:
    - makedirs: True
    - user: reprepro
    - group: reprepro

# Create a directory to hold incoming packages
/srv/packages/incoming/main:
  file.directory:
    - makedirs: True
    - mode: 777
    - user: reprepro
    - group: reprepro

# Copy the script that will automatically process incoming packages, and a cron job to run it.
/srv/packages/processincoming.sh:
  file.managed:
    - source: salt://aptrepo/server/files/processincoming.sh
    - user: reprepro
    - group: reprepro
    - mode: 755
  cron.present:
    - user: reprepro
    - minute: '*'
    - require:
      - pkg: reprepro
      - file: /srv/packages/processincoming.sh

# Create a certs directory for NGINX
/etc/nginx/certs:
  file.directory:
    - user: root
    - group: root
    - mode: 700

# Copy the CA cert to the nginx cert directory
/etc/nginx/certs/aptrepo_ca.crt:
  x509.pem_managed:
    - text: {{ salt['mine.get']('ca', 'x509.get_pem_entries')['ca']['/etc/pki/aptrepo.crt']|replace('\n', '') }}

# Create a private key for the server
# The condition below ensures that a key is always created if one doesn't exist, but if one does
# exist, the state will be a prereq and a new key will only be created when the certificate needs
# to be renewed.
aptrepo_server-key:
  x509.private_key_managed:
    - name: /etc/nginx/certs/server.key
    - bits: 4096
    - backup: True
    - new: True
    {% if salt['file.file_exists']('/etc/nginx/certs/server.key') -%}
    - prereq:
      - x509: aptrepo_server-cert
    {%- endif %}
    - listen_in:
      - service: nginx

# Create a certificate for the server, signed by the CA.
aptrepo_server-cert:
  x509.certificate_managed:
    - name: /etc/nginx/certs/server.crt
    - ca_server: ca
    - signing_policy: aptrepo_server
    - public_key: /etc/nginx/certs/server.key
    - CN: aptrepo.example.com
    - days_remaining: 30
    - backup: True
    - listen_in:
      - service: nginx

```

Now to configure clients to be able to use the new repository. First apt needs to know
that our repository requires a client certificate.

/srv/salt/aptrepo/client/files/45aptrepo-ssl

```
Acquire::https::aptrepo.example.com {
  Verify-Peer "true";
  Verify-Host "true";

  CaInfo "/etc/ssl/aptrepo_ca.crt";
  SslCert "/etc/ssl/aptrepo_client.crt";
  SslKey "/etc/ssl/aptrepo_client.key";
};
```

And now a client state to add the repository and generate the certificates clients will
need to use it.

/srv/salt/aptrepo/client/init.sls

```sls

# Add our new repository
internal-main-prod:
  pkgrepo.managed:
    - humanname: Internal Repo
    - name: deb https://aptrepo.example.com trusty-prod main
    - key_url: salt://aptrepo/server/files/gpg/public.gpg.key

# Add the CA certificate
/etc/ssl/aptrepo_ca.crt:
  x509.pem_managed:
    - text: {{ salt['mine.get']('ca', 'x509.get_pem_entries')['ca']['/etc/pki/aptrepo.crt']|replace('\n', '') }}

# Generate a unique private key
aptrepo_client-key:
  x509.private_key_managed:
    - name: /etc/ssl/aptrepo_client.key
    - bits: 4096
    - backup: True
    - new: True
    {% if salt['file.file_exists']('/etc/ssl/aptrepo_client.key') -%}
    - prereq:
      - x509: aptrepo_client-cert
    {%- endif %}

# Create a certificate signed by CA
aptrepo_client-cert:
  x509.certificate_managed:
    - name: /etc/ssl/aptrepo_client.crt
    - ca_server: ca
    - signing_policy: aptrepo_client
    - public_key: /etc/ssl/aptrepo_client.key
    - CN: {{ grains['fqdn'] }}
    - days_remaining: 15
    - backup: True

# Add the file configuring apt to use the certificates with this repository
/etc/apt/apt.conf.d/45aptrepo-ssl:
  file.managed:
    - source: salt://aptrepo/client/files/45aptrepo-ssl

```

That it, now you have a fully managed internal repository on aptrepo. You can create expose this repository to the internet and only your clients trusted by salt and issued a client certificate will be able to use it.
