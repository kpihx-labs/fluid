# Existing Debian node setup

Use this on an already existing Debian machine or VM.

## 1. Base packages

```bash
sudo apt-get update
sudo apt-get install -y curl ca-certificates gnupg lsb-release jq rsync unzip python3 python3-yaml docker.io openssh-client
```

## 2. Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
tailscale status --json
ip -4 addr show tailscale0
```

## 3. Docker

```bash
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
newgrp docker
docker info
```

## 4. Clone Fluid

```bash
mkdir -p "$HOME/KpihX-Labs/Fluid"
cd "$HOME/KpihX-Labs/Fluid"
git clone git@gitlab.com:kpihx-labs/fluid.git fluid
cd fluid
```

## 5. Register the exact Tailscale IP

Read:

```text
fabric/hosts.json
```

Set the concrete `tailscale_ip` for the node entry before running `Fluid`.

## 6. Verify

```bash
./fluid.sh audit
./fluid.sh status
```

## 7. Join later

(PVE Debian workload host is **`fluid-node-pve-debian`** in `fabric/hosts.json`; create the VM using `docs/architecture/pve-vm-debian-fluid-node-setup.md`.)

```bash
./fluid.sh join fluid-node-pve-debian
```
