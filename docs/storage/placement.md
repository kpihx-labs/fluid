# Placement

## Node classes in practice

```text
fluid-node-ubuntu
  manager
  authority
  continuity
  truth replica

fluid-node-pve
  manager
  authority
  continuity
  truth replica

fluid-node-mac
  worker
  no continuity
  truth replica

fluid-node-windows
  worker
  no continuity
  no truth replica
```

## Service cases

```text
host-local
  one carrier

shared
  many users, one carrier

replicated
  many users, many carriers
```
