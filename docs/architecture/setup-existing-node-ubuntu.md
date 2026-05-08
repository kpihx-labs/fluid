# Existing Ubuntu node setup

Use this on an already existing Ubuntu machine (desktop, VPS, bare metal—not necessarily created via the PVE Fluid VM guide).

The **package list parallels Debian** deliberately: Fluid tooling expects the same scriptable surface (`jq`, Python YAML, Docker engine presence, SSH client). Divergence between distros belongs in quirks you document locally, not buried in Fluid core.

---

## 1. Base packages

```bash
sudo apt-get update
sudo apt-get install -y curl ca-certificates gnupg lsb-release jq rsync unzip python3 python3-yaml docker.io openssh-client
```

**Why**

Same rationale as Debian `setup-existing-node-debian.md` §1: **`curl`** for installers, **`jq`/`python3-yaml`** for JSON/YAML-heavy automation, **`docker.io`** for engine parity with workload scripts, **`rsync`** for sync-style flows. Ubuntu’s repos track slightly different versioning but the **capabilities** Fluid checks for remain identical.

---

## 2. Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
tailscale status --json
ip -4 addr show tailscale0
```

**Why**

Identical reasoning to Debian: Fluid V0 uses **Tailscale IPv4** (`tailscale_ip` in **`fabric/hosts.json`**) as the authoritative reachability anchor for intra-mesh orchestration—not your Wi-Fi/LAN DHCP lease.

---

## 3. Docker

```bash
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
newgrp docker
docker info
```

**Why**

Service adapters and scripts assume `dockerd` reachable; enabling on boot survives laptop suspend cycles or VPS reboot policies. **`docker.info`** verifies permission wiring after group change.

---

## 4. Clone Fluid

```bash
FLUID_PARENT="${FLUID_PARENT:-$HOME/workspace}"
mkdir -p "$FLUID_PARENT/Fluid"
cd "$FLUID_PARENT/Fluid"
git clone <YOUR_FLUID_REPO_GIT_URL> fluid
cd fluid
```

**Why**

Keeps upstream docs neutral: **you** decide clone URL and filesystem layout via `FLUID_PARENT`. The Fluid repo assumes relative paths `fabric/`, `scripts/`, … from checkout root—do not arbitrarily nest deeper without adjusting automation.

---

## 5. Register the exact Tailscale IP

Read:

```text
fabric/hosts.json
```

Populate `tailscale_ip` for Ubuntu host entry—**literal current `tailscale0` IPv4**, not guessed from DNS or MagicDNS shortcuts unless those match Fluid’s verifier.

---

## 6. Verify

```bash
./fluid.sh audit
./fluid.sh status
```

**Why**

Run after every substantive change (IP drift, reinstall TS, rotating Docker). Fixing errors before `bootstrap`/`join` prevents half-applied manifests.

---

## 7. Bootstrap later

```bash
./fluid.sh bootstrap YOUR_FABRIC_HOST_ID
```

**Why**

`bootstrap` (where enabled in your tree) primes continuity paths for Ubuntu-class nodes. **`YOUR_FABRIC_HOST_ID` must equal the Fabric host key** declared in **`fabric/hosts.json`** for this machine—not your shell `hostname` unless you consciously aligned them. The earlier example cited `fluid-node-ubuntu` only as a **generic profile name** pattern; substitute your real Fabric id.
