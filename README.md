# Fluid

Fluid is a lightweight personal service plane:

- Tailscale for network identity
- Docker Swarm for runtime placement
- `fluid.yml` in each project repo for placement intent
- GitLab CI or manual `docker stack deploy` for delivery

Quick start:

```bash
./fluid.sh audit
./fluid.sh bootstrap ubuntu
./fluid.sh join pve
./fluid.sh status
```

Project flow:

```bash
./fluid.sh project validate /path/to/repo
./fluid.sh project render /path/to/repo
./fluid.sh project deploy /path/to/repo
```

Read [CONTRACT.md](./CONTRACT.md) before the first real deployment.
