# Fluid Lifecycle

## Full path

```text
HOST 1: ubuntu
  |
  +--> install + connect tailscale
  +--> install + start docker
  +--> clone Fluid
  |
  v
./fluid.sh audit
  |
  v
./fluid.sh bootstrap fluid-node-ubuntu
  |
  +--> docker swarm init
  +--> write state/cluster-state.json
  +--> set authority = fluid-node-ubuntu
  +--> render/apply continuity
  |
  v
HOST 2: Debian VM on PVE
  |
  +--> install + connect tailscale
  +--> install + start docker
  +--> clone Fluid
  |
  v
./fluid.sh join fluid-node-pve
  |
  +--> docker swarm join
  +--> sync labels
  +--> recompute live authority
  +--> render/apply continuity
  |
  v
SERVICE REPO
  |
  +--> docker-compose.yml
  +--> fluid.yml
  |
  v
./fluid.sh project deploy <repo>
```

## What changes

```text
bootstrap
  -> state/cluster-state.json
  -> render/continuity/fluid-node-ubuntu/*
  -> /etc/fluid/continuity/*
  -> /etc/systemd/system/fluid-*.service
  -> /etc/systemd/system/fluid-*.timer
  -> /var/lib/fluid/state/*
  -> local docker swarm state

join
  -> render/continuity/fluid-node-pve/*
  -> /etc/fluid/continuity/*
  -> /etc/systemd/system/fluid-*.service
  -> /etc/systemd/system/fluid-*.timer
  -> /var/lib/fluid/state/*
  -> local docker swarm state

project deploy
  -> render/projects/<stack>/*
  -> live docker stack state
```

## Access path

```text
./fluid.sh access render
  |
  +--> render/access/access-matrix.json
  +--> render/access/ACCESS.md
  +--> render/access/tailscale-managed-acl.hujson

./fluid.sh access apply tailscale
  |
  +--> uses adapters/access/tailscale/apply.py
  +--> requires:
        FLUID_TAILSCALE_TAILNET
        FLUID_TAILSCALE_API_KEY
```

## Normal service cases

```text
HOST-LOCAL
  one node carries it
  example:
    constraints:
      - node.labels.fluid.host == fluid-node-ubuntu

SHARED
  many nodes use it, one carrier
  example:
    nextcloud UI used from ubuntu/mac/windows
    but carried on fluid-node-pve

REPLICATED
  many nodes use it, many carriers allowed
  example:
    dashboard with replicas on ubuntu + debian VM
```
