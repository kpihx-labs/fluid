# Fluid

Fluid is the meta-plane for a local distributed system.

- network identity: Tailscale
- runtime placement: Docker Swarm
- host truth: `fabric/`
- mutable cluster truth: `state/cluster-state.json`
- generated artifacts: `render/`
- host runtime: `/etc/fluid` and `/var/lib/fluid`

## Quick start

```bash
./fluid.sh audit
./fluid.sh link
./fluid.sh bootstrap fluid-node-ubuntu
./fluid.sh status
```

After `./fluid.sh link`, you can run `fluid ...` from any directory on that host.

Create the Debian VM on PVE:

- `docs/architecture/pve-vm-debian-fluid-node-setup.md`

Then on the Debian guest:

```bash
./fluid.sh join fluid-node-pve-debian
```

Project flow:

```bash
./fluid.sh project validate /path/to/repo
./fluid.sh project render /path/to/repo
./fluid.sh project deploy /path/to/repo
./fluid.sh access render
```

Read:

- `CONTRACT.md`
- `LIFECYCLE.md`
- `docs/architecture/tailscale-access.md`
- `docs/architecture/pve-vm-debian-fluid-node-setup.md`
