# CONTRACT — Fluid

## Core

```text
Fluid
  = meta only
  = local distributed survival plane
  = Tailscale underlay
  = Docker Swarm placement
```

Fluid does not own service code.
Fluid does not own service repo paths.
Fluid does not auto-install host prerequisites in V0.

## Source of truth

```text
fabric/
  hosts.json
  profiles/
  policies/
  defaults.env

state/
  cluster-state.json

render/
  continuity/
  access/
  projects/
  backups/
```

## Host runtime

```text
/etc/fluid
  installed host runtime

/var/lib/fluid
  mutable local runtime state
```

## Roles

```text
manager
  - joins Swarm control plane
  - may join authority

worker
  - runs workloads
  - not control plane

observer
  - does not run workloads
  - consumes shared services/data only
```

## Authority

Authority is not just "manager".

```text
authority member
  = role == manager
  + survivor_capable == true
  + authority_eligible == true
```

## Continuity

Continuity means host-local recovery helpers.

```text
state-guard
  ensure local continuity dirs/files exist

authority-marker
  write local authority metadata

backup-trigger
  trigger Fluid backup on schedule

recovery-shell
  materialize local recovery entrypoint
```

## Portable truth replica

```text
portable_truth_replica = true
  -> host may carry replicated critical Fluid truth

portable_truth_replica = false
  -> host may use Fluid but is not a truth replica target
```

## V0 prerequisite rule

Each execution-capable host must already have:

```text
tailscale installed
tailscale connected
docker installed
docker daemon running
current user in docker group
this repo cloned at $HOME/KpihX-Labs/Fluid/fluid
```

Fluid checks these prerequisites.
Fluid does not install them in V0.

## Service boundary

Services live outside Fluid core.

```text
Fluid core
  -> placement
  -> authority
  -> continuity
  -> access intent
  -> portable truth

Service repo
  -> Dockerfile
  -> docker-compose.yml
  -> fluid.yml
  -> service secrets/runtime
```

`nextcloud` and `ts_proxy` are service repos, not Fluid core.
