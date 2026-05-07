# Project templates

Use these files inside service repos.

```text
service repo
  Dockerfile
  docker-compose.yml
  fluid.yml
```

Fluid reads `fluid.yml`, renders `render/projects/<stack>/`, then deploys with Docker Swarm.
