# Existing Debian node setup

Use this on an **already-provisioned** Debian machine or VM—for example **after** the Proxmox walkthrough in the [PVE/vm_debian repository](https://github.com/kpihx-labs/pve/tree/master/vm_debian).

Each numbered block below installs something Fluid expects; the bullets explain **why**, not “because the script said so”.

---

## 1. Base packages

```bash
sudo apt-get update
sudo apt-get install -y curl ca-certificates gnupg lsb-release jq rsync unzip python3 python3-yaml docker.io openssh-client
```

**Why**

- **`curl`** — Pulls installers (Tailscale script) without depending on distro package freshness.
- **`ca-certificates` + `gnupg` + `lsb-release`** — TLS trust and distro detection for APT keys / third‑party repos.
- **`jq`** — Fluid tooling and scripting often parses JSON (status, inventories); failing here causes opaque script errors later.
- **`rsync`** — Used by sync/deploy-style flows across nodes; harmless on a fresh host and needed when continuity bundles move data.
- **`unzip`** — Occasional asset or bundle unpacking in automation.
- **`python3` + `python3-yaml`** — Lifecycle/render helpers are Python-first; YAML is the lingua franca for fabric/state fragments.
- **`docker.io`** — Fluid V0 **does not** auto-install infra; Debian’s Docker packages satisfy “engine present” prerequisites for workloads you later attach via adapters/scripts.
- **`openssh-client`** — `scp`/`sftp`/Git-over-SSH from the node for operator workflows.

Fluid **does not** hide these dependencies behind magic—explicit install keeps audits honest.

---

## 2. Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
tailscale status --json
ip -4 addr show tailscale0
```

**Why**

Fluid V0 is **Tailscale-first** for stable identity across machines. The **canonical address** Fluid scripts care about is the **assigned IPv4 on `tailscale0`**, copied into **`fabric/hosts.json`** as `tailscale_ip`. Until that field matches reality, `audit`/`join`/render targeting will disagree with the live network plane.

Running `tailscale status --json` and `ip … tailscale0` gives you immediate proof the interface exists and advertised routes are sane.

---

## 3. Docker

```bash
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
newgrp docker
docker info
```

**Why**

The meta repo avoids baking service-specific Compose trees, but many Fluid-related workloads assume a **Docker engine** on qualifying nodes. Enabling systemd start keeps reboot continuity; adding **`$USER` to group `docker`** avoids sudo-spam during iterative workflows (accept the UNIX group caveat in shared-admin environments).

`docker info` confirms the daemon is reachable using your current privileges.

---

## 4. Clone Fluid

```bash
FLUID_PARENT="${FLUID_PARENT:-$HOME/Workspace}"
mkdir -p "$FLUID_PARENT/Fluid"
cd "$FLUID_PARENT/Fluid"
git clone <YOUR_FLUID_REPO_GIT_URL> fluid
cd fluid
```

**Why**

- **`FLUID_PARENT`** — Lets each site choose a canonical checkout root without embedding a proprietary path literal in upstream docs (export it if you dislike the default `$HOME/workspace`).
- **Separate `fluid/` directory** — Keeps sibling repos (templates, overlays) predictable; aligns with tooling that resolves relative `fabric/` and `scripts/` directories from repo root.

After clone, `./fluid.sh` resolves against this tree.

---

## 5. Register the exact Tailscale IP

Read:

```text
fabric/hosts.json
```

Set the concrete `tailscale_ip` for **this machine’s Fabric host entry** before relying on `./fluid.sh` for truthful networking.

**Why**

Fluid resolves **targets from Fabric**. The LAN IP (`192.168.x.x`-style admin path) matters for provisioning, but **runtime joining and continuity** hinge on **`tailscale_ip` matching the live Tailscale IPv4**. Mismatches manifest as unreachable rsync sinks, contradictory `status` maps, or audit failures—even when ping on your LAN works.

---

## 6. Verify

```bash
./fluid.sh audit
./fluid.sh status
```

**Why**

`audit` encodes prerequisites (presence of tools/paths/policy checks you opted into); `status` prints the reconciled worldview from Fabric + live facts. Fixing red items here prevents subtle partial-join states.

---

## 7. Join later

Provision the guest with **`pve-vm-debian-fluid-node-setup.md`** **before** you expect continuity artifacts to land correctly; the Fabric host **`id`/entry key** must already exist inside **`fabric/hosts.json`** with accurate `tailscale_ip`.

```bash
./fluid.sh join YOUR_FABRIC_HOST_ID
```

**Why**

`join` attaches this node identity to Fluid’s continuity graph (render targets, manifests, role flags). **`YOUR_FABRIC_HOST_ID` is exactly the host key** Fluid uses—not the Proxmox **VMNAME** unless you deliberately made them identical. Keeping those namespaces distinct avoids “it worked on my laptop hostname” portability bugs.
