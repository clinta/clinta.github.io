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

Create a couple of swarm agent hosts:

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

Now your docker swarm is up and running. Time to create some networks. When you run `docker network create` with the default bridge driver, docker creates a bridge device with the IP that you specify as gateway. The bridge device is named br-<short-id> where short-id is the first 12 characters of the network's UUID.

I'm going to capture the network's short ID from the create command and store it in the netid variable then use this variable to join the vxlan device to this bridge device.

I'm also a little bit OCD about my networks. The vxlan ID is a 24 bit field, and my networks are /24. So I'm going to make sure that the vxlan ID is the same as the 24 bit network number. In this example I'm going to create the network 10.42.0.0/24. The 24 bit network address of this network in base 10 is 666112, so that will be my vxlan ID for this network.

I'm also assigning a /27 ip-range to the docker network so that each host assigns a specific subset of this network and I don't end up with containers that have overlapping IPs.

```bash
docker-machine ssh swarm-master
netid=$(docker network create --subnet=10.42.0.0/24 --gateway=10.42.0.1 --ip-range=10.42.0.32/27 vxlan666112 | cut -c1-12)
sudo ip link add vxlan666112 
type vxlan id 666112 group 239.1.1.1 dev eth1 dstpor
t 4789
sudo ip link set vxlan666112 master br-$netid
sudo ip link set up vxlan666112
sudo ip link set up br-$netid
exit
```

Now do the same for the two swarm agents. Making sure to change the gateway and ip-range parameters.

```
docker-machine ssh swarm-agent-00
netid=$(docker network create --subnet=10.42.0.0/24 --gateway=10.42.0.2 --ip-range=10.42.0.64/27 vxlan666112 | cut -c1-12)
sudo ip link add vxlan666112 type vxlan id 666112 group 239.1.1.1 dev eth1 dstport 4789
sudo ip link set vxlan666112 master br-$netid
sudo ip link set up vxlan666112
sudo ip link set up br-$netid
exit

docker-machine ssh swarm-agent-01
netid=$(docker network create --subnet=10.42.0.0/24 --gateway=10.42.0.3 --ip-range=10.42.0.96/27 vxlan666112 | cut -c1-12)
sudo ip link add vxlan666112 type vxlan id 666112 group 239.1.1.1 dev eth1 dstport 4789
sudo ip link set vxlan666112 master br-$netid
sudo ip link set up vxlan666112
sudo ip link set up br-$netid
exit
```

Now at this point you have a vxlan overlay. Each docker node should to ping each other node on the addresses 10.42.0.1, 10.42.0.2 and 10.42.0.3.

Now you can create containers on this new network and have connectivity to hosts and other containers on this vxlan network.

```
docker run -it --net=vxlan666112 ubuntu /bin/bash
```

Run a few more containers and they should all have access to eachother via this vxlan network.

Obviously this setup requires more networking work that is left as an exercise for the reader. Things like routing to the rest of your network, and NAT at your network edge for internet access. But this guide was target toward an audience who already has this infrastructure setup and wants docker containers to be part of it.

If this was helpful to you or you have any questions, find me on twitter or send me an email.
