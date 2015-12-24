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
