# Tailscale access

## Inputs

```text
FLUID_TAILSCALE_TAILNET
FLUID_TAILSCALE_API_KEY
```

## Render only

```bash
./fluid.sh access render
```

Generated file:

```text
render/access/tailscale-managed-acl.hujson
```

## Apply through the adapter

```bash
export FLUID_TAILSCALE_TAILNET="example.com"
export FLUID_TAILSCALE_API_KEY="tskey-..."
./fluid.sh access apply tailscale
```

The adapter:

```text
1. GET current tailnet policy
2. replace or append the Fluid managed block
3. POST validate
4. POST apply
```
