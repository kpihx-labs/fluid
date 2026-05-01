# CONTRACT — Fluid

## 1. Identity

Fluid is one logical Docker Swarm cluster spread across personal hosts.

It exists to keep services portable:

- hosts are replaceable
- the network is abstracted by Tailscale
- services stay Docker-first
- deployment intent stays in each project repo

Fluid is not a VM.
Fluid is not a single container.
Fluid is not one copy per host.

Fluid is:

- one cluster
- many hosts
- many project repos

## 2. Concrete shape

```text
                 GitLab CI / manual deploy
                           |
                           v
                    one Fluid cluster
                           |
          +----------------+----------------+
          |                                 |
          v                                 v
   ubuntu manager                    pve worker/manager
          |                                 |
          +---------------+-----------------+
                          |
                          v
                       mac worker
```

The first manager is usually `ubuntu`.
`pve` should ideally host a Linux execution node, not carry app workloads directly forever.

## 3. Source of truth

### `config/fluid.env`
Why:
- global defaults must be editable without touching scripts
- paths, ports, package baselines, and operator behavior are not code

### `config/hosts.json`
Why:
- Fluid needs one concrete fleet file
- each host must declare its identity, profile, network name, and capabilities

### `config/profiles/*.json`
Why:
- shared host behavior should be written once
- platform defaults must stay reusable

### `config/policies/*.json`
Why:
- network, authority, and continuity rules are cluster policy, not host identity

### `state/fluid-state.json`
Why:
- some truths are runtime truths
- the active manager, join tokens, retired hosts, and backup timestamps are not static config

### `runtime/`
Why:
- rendered files, backups, cache, and logs must stay visible
- generated output must never become hidden source of truth

## 4. Operator rule

Edit:

- `config/`
- project repos

Do not edit:

- `runtime/rendered/`
- installed files under `/etc` or `/var/lib`

Those are projections of the source of truth.

## 5. Host roles

Fluid uses only three practical roles:

- `manager`
  Runs Swarm control plane.

- `worker`
  Runs services but does not lead.

- `observer`
  Does not run the cluster. Useful for docs, recovery, or later extension.

Role comes from:

- host profile
- host overrides
- policy

Not from script hardcoding.

## 6. One-time cluster creation

### First host

Clone `fluid/` on the first serious host, usually `ubuntu`, then:

```bash
./fluid.sh audit
./fluid.sh bootstrap ubuntu
```

This does four things:

1. prepares the host
2. installs missing local prerequisites
3. initializes Docker Swarm
4. stores manager address and join tokens in `state/fluid-state.json`

### Next host

Clone or sync the same `fluid/` repo on the next host, then:

```bash
./fluid.sh join pve
```

This:

1. prepares the host
2. joins the existing Swarm cluster
3. applies node labels from config
4. installs continuity payloads when enabled

### Future host

The extension path must stay boring:

```text
install Tailscale
install Docker
clone fluid
add host entry
run ./fluid.sh join <host>
```

That is the whole point.

## 7. Project contract

Each service repo stays autonomous.

Minimal shape:

```text
my-service/
├── Dockerfile
├── docker-compose.yml
├── fluid.yml
└── .gitlab-ci.yml
```

Why:
- build logic belongs to the project
- runtime placement belongs to the project
- Fluid must not hardcode project internals

## 8. `fluid.yml`

`fluid.yml` declares how a project should live on Fluid.

Minimal example:

```yaml
stack: bw-proxy
compose:
  - docker-compose.yml
services:
  bw-proxy:
    replicas: 1
    constraints:
      - node.labels.fluid.class == app
    preferences:
      - spread: node.labels.fluid.site
```

Meaning:

- use this compose file
- deploy this stack name
- place this service only on app-capable nodes
- prefer spreading by site label

Fluid renders a Swarm override from this file.

## 9. Project lifecycle

### Validate

```bash
./fluid.sh project validate /path/to/repo
```

Checks:
- `fluid.yml`
- compose files
- deploy intent structure

### Render

```bash
./fluid.sh project render /path/to/repo
```

Writes:
- `runtime/rendered/projects/<stack>/metadata.json`
- `runtime/rendered/projects/<stack>/swarm.override.yml`

Why:
- deployment must stay inspectable before it is applied

### Deploy

```bash
./fluid.sh project deploy /path/to/repo
```

This runs `docker stack deploy` against the active manager.

So the normal flow becomes:

```text
git push
  -> CI builds image
  -> CI pushes registry image
  -> CI runs fluid project deploy
```

Portainer remains useful as a cockpit, not as the main source of truth.

## 10. Network contract

Current default:

- underlay: Tailscale
- advertise mode: Tailscale IP
- cluster identity: Tailscale host names and IPs

Why:
- real networks change
- school Wi-Fi is hostile
- host IP drift must not break the service plane

## 11. Continuity

Continuity exists for recovery, not for primary app scheduling.

It currently installs host-local helpers for:

- state guard
- authority marker
- recovery shell
- backup trigger timer

Why:
- if the cluster is sick, the operator still needs a local path back in

## 12. Backup and restore

```bash
./fluid.sh backup
./fluid.sh restore --from <archive>
./fluid.sh validate-restore
```

Backups keep the portable truth:

- config
- state
- scripts
- templates
- selected references

Why:
- rebuilding the cluster must not depend on memory

## 13. Failure model

If one host dies:

- Fluid survives on the remaining hosts if the required services can run there
- the service plane is restored by redeploying stacks, not by worshipping one dead machine

If the manager dies:

- recover the repo
- restore or recreate `state/fluid-state.json`
- bootstrap a surviving manager
- rejoin surviving workers
- redeploy stacks

That is the real abstraction boundary:

- hosts are expendable
- service definitions are not

## 14. Current scope

Fluid is intentionally optimized for:

- Docker services
- personal infra
- lightweight multi-host deployment
- gradual migration from existing Compose stacks

It is not trying to be:

- Kubernetes
- a full PaaS
- a generic cloud product

That restraint is deliberate. It keeps the long-term maintenance cost low.
