---
layout: post
title: Compiling the mongodb plugin for collectd
date: 2015-06-30 14:20:00
aliases:
  - /posts/2015-06-30-mongodb-for-collectd
  - /posts/2015-6-30-mongodb-for-collectd
---

The MongoDB [plugin](https://collectd.org/wiki/index.php/Plugin:MongoDB) for collectd is currently unfinished and hasn't had active development since 2012. Fortunately the folks at [Stackdriver](https://github.com/Stackdriver) have fixed some of the issues so that the plugin works for their stackdriver agent, which is based on collectd. Unfortunately this code has not been submitted back upstream to collectd.

This means that if you want to monitor your own mongodb instances with collectd you'll need to build it yourself.

Start by cloning the stackdriver repository and changing to the stackdriver agent branch.

```bash
git clone https://github.com/Stackdriver/collectd
cd collectd
git checkout stackdriver-agent-5.5.0
```

The build script should help you find any missing dependencies you need to do the build.

```bash
./build.sh
```

Run the configure script, specifying only the mongodb module and instruct it to use the included libmongoc driver.

```
./configure --enable-mongodb --disable-all-plugins --disable-daemon --with-libmongoc=own
```

The mongodb plugin is now compiled. Copy it from `src/.libs/mongodb.so` to `/usr/lib/collectd/` on your mongodb server and configure according to the plugin documentation.
