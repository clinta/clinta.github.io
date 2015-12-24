Install docker, docker-machine and docker-compose and virtualbox. Start by creating a docker-machine which will be used to generate your token to create a swarm cluster.

```bash
$ docker-machine create -d virtualbox default
$ eval "$(docker-machine env default)"
$ docker run swarm create
```

Copy the token returned as the last line output from `docker swarm create`. Now create your swarm manager.

```bash
docker-machine create \
        -d virtualbox \
        --swarm \
        --swarm-master \
        --swarm-discovery token://<TOKEN-FROM-ABOVE> \
      swarm-master
```

Create a couple of swarm nods:

```bash
docker-machine create \
    -d virtualbox \
    --swarm \
    --swarm-discovery token://<TOKEN-FROM-ABOVE> \
    swarm-agent-00

docker-machine create \
    -d virtualbox \
    --swarm \
    --swarm-discovery token://<TOKEN-FROM-ABOVE> \
    swarm-agent-01
```

Now set your shell to manage the swarm:

```bash
eval $(docker-machine env --swarm swarm-master)
```

Now your docker swarm is up and running.

Lets take a look at what the networking looks like on our docker hosts.

```bash
$ docker-machine ssh swarm-agent-00
$ ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default 
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: dummy0: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN group default 
    link/ether 9a:e8:1a:c5:3a:c5 brd ff:ff:ff:ff:ff:ff
3: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 08:00:27:46:f7:27 brd ff:ff:ff:ff:ff:ff
    inet 10.0.2.15/24 brd 10.0.2.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe46:f727/64 scope link 
       valid_lft forever preferred_lft forever
4: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 08:00:27:d3:63:51 brd ff:ff:ff:ff:ff:ff
    inet 192.168.99.102/24 brd 192.168.99.255 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fed3:6351/64 scope link 
       valid_lft forever preferred_lft forever
6: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    link/ether 02:42:af:f0:ad:84 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 scope global docker0
       valid_lft forever preferred_lft forever

$ ip route show
default via 10.0.2.2 dev eth0  metric 1 
10.0.2.0/24 dev eth0  proto kernel  scope link  src 10.0.2.15 
127.0.0.1 dev lo  scope link 
172.17.0.0/16 dev docker0  proto kernel  scope link  src 172.17.0.1 
192.168.99.0/24 dev eth1  proto kernel  scope link  src 192.168.99.102
 ```

We have 2 nics in the VM created by docker-machine. eth0 is our defualt network with our gateway on it. eth1 is a host-only network created by docker-machine. And docker0 is the default docker network that containers will be added to.

Lets spin one up and take a look.

```bash
$ docker run -it ubuntu /bin/bash
root@515f2bd8c40e:/# ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default 
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
7: eth0@if8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.2/16 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:acff:fe11:2/64 scope link 
       valid_lft forever preferred_lft forever
 ```

Create your vxlan device on each swarm member:

```bash
$ docker-machine ssh swarm-master
$ sudo ip link add vxlan0 type vxlan id 42 group 
$ 239.1.1.1 dev eth1 dstport 4789
$ sudo ip addr add 10.1.1.1/24 dev vxlan0
$ sudo ip link set up vxlan0
$ exit
$ 
$ docker-machine ssh swarm-agent-00
$ sudo ip link add vxlan0 type vxlan id 42 group 
$ 239.1.1.1 dev eth1 dstport 4789
$ sudo ip addr add 10.1.1.2/24 dev vxlan0
$ sudo ip link set up vxlan0
$ exit
$ 
$ docker-machine ssh swarm-agent-01
$ sudo ip link add vxlan0 type vxlan id 42 group 
$ 239.1.1.1 dev eth1 dstport 4789
$ sudo ip addr add 10.1.1.3/24 dev vxlan0
$ sudo ip link set up vxlan0
$ exit
```

Now your docker hosts should be able to ping eachother on their vxlan addresses. Now to get docker to use this network we need to use a different network plugin for docker. I'm going to use the docker [ipvlan plugin](https://github.com/gopher-net/ipvlan-docker-plugin).

```
docker-machine ssh swarm-master
wget https://github.com/gopher-net/ipvlan-docker-plugin/raw/master/binaries/ipvlan-docker-plugin-0.2-Linux-x86_64
chmod +x ipvlan-docker-plugin-0.2-Linux-x86_64
nohup ./ipvlan-docker-plugin-0.2-Linux-x86_64 -d &
docker network  create  -d ipvlan  --subnet=10.1.1.1/24 --gateway=10.1.1.1 --ip-range=10.1.1.32/27 -o host_iface=vxlan0 -o mode=l2  net1

docker-machine ssh swarm-agent-00
wget https://github.com/gopher-net/ipvlan-docker-plugin/raw/master/binaries/ipvlan-docker-plugin-0.2-Linux-x86_64
chmod +x ipvlan-docker-plugin-0.2-Linux-x86_64
nohup ./ipvlan-docker-plugin-0.2-Linux-x86_64 -d &
docker network  create  -d ipvlan  --subnet=10.1.1.0/24 --gateway=10.1.1.2 --ip-range=10.1.1.64/27 -o host_iface=vxlan0 -o mode=l2  net1

docker-machine ssh swarm-agent-01
wget https://github.com/gopher-net/ipvlan-docker-plugin/raw/master/binaries/ipvlan-docker-plugin-0.2-Linux-x86_64
chmod +x ipvlan-docker-plugin-0.2-Linux-x86_64
nohup ./ipvlan-docker-plugin-0.2-Linux-x86_64 -d &
docker network  create  -d ipvlan  --subnet=10.1.1.0/24 --gateway=10.1.1.3 --ip-range=10.1.1.96/27 -o host_iface=vxlan0 -o mode=l2  net1
```

You may notice that each host has a separate `ip-range` value. This is necessary to prevent docker from assigning the same IP to multiple containers. With the new pluggable ipam backend for docker, hopefully there will soon be a better solution for this.

Now you can start containers on hte 10.1.1.0/24 network.

```
docker run -it --net=net1 ubuntu /bin/bash
