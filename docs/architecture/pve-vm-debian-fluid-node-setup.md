# Proxmox (PVE): Debian 12 VM for Fluid (`fluid-node-pve-debian`)

This document describes **how to create a dedicated Fluid workload VM on Proxmox** using a **Debian 12 stable (bookworm) cloud image** and **why** each step matters.

Fabric identity for this node: see `fabric/hosts.json` → host `fluid-node-pve-debian` (alias hostname `fluid-node-pve-vm-101`).

After the VM boots, continue with **`docs/architecture/setup-existing-node-debian.md`** (packages, Tailscale, Docker, clone Fluid, set `tailscale_ip`, `./fluid.sh join fluid-node-pve-debian`).

---

## Assumptions (adjust only if yours differ)

| Item | Typical value | Why |
|------|----------------|-----|
| Hypervisor SSH | From Ubuntu workstation: `ssh kpihx-pve` | You operate PVE remotely; Fluid does not automate PVE provisioning. |
| VMID | `101` | Stable ID ties docs, disks, and mental model (`fluid-node-pve-vm-101`). |
| Guest name | `fluid-node-pve-debian` | Matches Fabric host name as in `fabric/hosts.json`. |
| Storage | `local-zfs` | Common PVE root pool name; swap if yours is different (`pvesm status`). |
| Bridge | `vmbr1` | Lab LAN bridge for static IP (`10.10.10.x` style). |
| Admin user inside guest | `kpihx` | Cloud-init will create this user with your SSH keys. |

---

## One-shot creation script

Run **on the PVE shell** (`ssh kpihx-pve`). Review variables at the top; then paste the whole block.

```bash
sudo bash -lc '
set -euo pipefail
VMID=101
VMNAME=fluid-node-pve-debian
IMG=/var/lib/vz/template/iso/debian-12-genericcloud-amd64.qcow2

qm stop "${VMID}" 2>/dev/null || true
qm destroy "${VMID}" --purge 1 2>/dev/null || true

[ -f "${IMG}" ] || wget -O "${IMG}" https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2

qm create "${VMID}" --name "${VMNAME}" --ostype l26 --memory 4096 --balloon 2048 --cores 2 --cpu host \
  --scsihw virtio-scsi-single --agent enabled=1 --net0 virtio,bridge=vmbr1 \
  --serial0 socket --vga serial0

qm importdisk "${VMID}" "${IMG}" local-zfs
qm set "${VMID}" --scsi0 local-zfs:vm-"${VMID}"-disk-0
qm set "${VMID}" --ide2 local-zfs:cloudinit
qm set "${VMID}" --boot order=scsi0
qm resize "${VMID}" scsi0 64G

qm set "${VMID}" --ciuser kpihx \
  --sshkeys /home/kpihx/.ssh/authorized_keys \
  --ipconfig0 ip=10.10.10.11/24,gw=10.10.10.1 \
  --nameserver "1.1.1.1 9.9.9.9" \
  --searchdomain kpihx-labs.com

qm start "${VMID}"
qm status "${VMID}"
'
```

Exit PVE when done: `exit` (from Ubuntu workstation).

---

## Line-by-line: what each piece does and **why**

### `sudo bash -lc ' … '`

- **What**: Runs one root-owned Bash script with `-l` (login-style env).
- **Why**: `qm` is a Proxmox admin tool that requires root-equivalent privileges. A single guarded block avoids half-applied VM state after a mid-script failure.

### `set -euo pipefail`

- **What**: Exit on error, treat unset variables as fatal, pipelines fail if any stage fails.
- **Why**: VM creation touches disks and IDs; silent partial runs are painful to debug (`orphan disks`, wrong attach order).

### `VMID`, `VMNAME`, `IMG`

- **What**: Variables for reuse and clarity.
- **Why**: You will destroy/recreate; hard-coded strings in 15 places drift. Stable `VMID` maps to disks like `vm-101-disk-0`.

### `qm stop …` and `qm destroy … --purge 1`

- **What**: Stops VM if running; removes VM definition and related resources (purge).
- **Why**: Idempotent “greenfield recreate” pattern. **`|| true`**: first run may have no VM; do not abort the script.

### Image download (`wget … debian-12-genericcloud-amd64.qcow2`)

- **What**: Downloads **Debian cloud image** (`genericcloud`): minimal disk, meant for automation and cloud-init.
- **Why**: Faster and more reproducible than an interactive ISO installer; matches Fluid’s Debian profile and `setup-existing-node-debian.md`.

### `qm create` options

| Flag | Meaning | Why |
|------|---------|-----|
| `--ostype l26` | Guest OS class “Linux 2.6+” | Correct driver expectations for QEMU. |
| `--memory 4096` | 4 GiB RAM | Reasonable baseline for Docker + swarm agent + Fluid scripts. Tune if heavy stacks. |
| `--balloon 2048` | Balloon target 2 GiB | Lets the hypervisor reclaim idle RAM when safe; avoids fixed waste on many small VMs. |
| `--cores 2` | 2 vCPU | Enough for swarm node + systemd; avoids oversubscribing PVE blindly. |
| `--cpu host` | Pass-through host CPU feature flags | Maximizes compat for user-space/container stacks; downside: less live-migration portability. Acceptable on a personal lab node. |
| `--scsihw virtio-scsi-single` | Single VirtIO SCSI controller | Modern SCSI path + good performance for virtio disks under Linux guests. |
| `--agent enabled=1` | QEMU guest agent ON | Enables clean shutdown/reboot hooks, reports IP from inside guest to PVE, better ops. Fluid ops expect sane host visibility. |
| `--net0 virtio,bridge=vmbr1` | VirtIO NIC on lab bridge | Your guest gets L2 connectivity on the VLAN/bridge used for LAN addresses like `10.10.10.11`. Match your real bridge label. |
| `--serial0 socket` + `--vga serial0` | Serial console routing | Reliable headless troubleshooting if SSH or net bring-up fails early. |

### `qm importdisk` + `scsi0`

- **What**: Imports qcow into ZFS-backed storage and attaches as **guest boot disk**.
- **Why**: The cloud image is only a blob until attached as `scsi0` (our boot disk). ZFS-backed `local-zfs` is snapshot-friendly.

### `ide2` + **`local-zfs:cloudinit`**

- **What**: Attaches **Proxmox’s cloud-init drive** CD-ROM slot `ide2` carrying user-data/meta-data compiled from `qm set` flags.
- **Why**: Debian cloud image expects **seed data** from “NoCloud”/`config-drive`. Without this, cloud-init runs but has **nothing to apply**, so:

  - created user SSH keys won't match your intent,
  - static IP/network may not configure,
  - first login path becomes manual guesswork,

  contradicting repeatable Fluid onboarding.

### `--boot order=scsi0`

- **What**: Boot from virtio-scsi disk first.
- **Why**: Cloud-init “CD” must not preempt real OS disk in boot chain.

### `qm resize scsi0 64G`

- **What**: Grow root disk capacity.
- **Why**: Official cloud roots are tiny; Docker images and swarm state consume space quickly. Resize before first heavy use avoids partition drama.

### `--ciuser`, `--sshkeys`, `--ipconfig0`, `--nameserver`, `--searchdomain`

| Parameter | Role | Why |
|-----------|------|-----|
| `ciuser kpihx` | First POSIX user cloud-init configures | Matches your workstation identity pattern; aligns with SSH key path on PVE `/home/kpihx/.ssh/authorized_keys` as **source for injection**. |
| `sshkeys …authorized_keys` | Public keys for that user | **Non-interactive** trust establishment; Fluid workflow expects SSH bootstrap without typing passwords forever. Adjust path only if keys live elsewhere PVE-readable. |
| `ipconfig0 ip=…/gw=…` | Static addressing on NIC 1 | Predictable LAN reachability from workstation or PVE for first contact; Fluid V0 favors knowing fixed lab-side addressing while Tailscale is guest-side identity. Tune IP/gateway to your DHCP-free segment design. |
| `nameserver` / `searchdomain` | Resolver baseline | Faster `apt`/DNS sanity before Tailscale installs; avoids captive resolver failures on isolated segments. |

### `qm start` + `qm status`

- **What**: Power on VM and display state.
- **Why**: Immediate confirmation VM object is consistent and running.

---

## After the VM is running

1. From Ubuntu: **`ssh kpihx@10.10.10.11`** (or Serial console via PVE UI if SSH not yet up).
2. Follow **`setup-existing-node-debian.md`** end-to-end.
3. **`tailscale up`** → copy **live** `tailscale_ip` → paste into **`fabric/hosts.json`** for `fluid-node-pve-debian`.
4. On the Debian VM:

   ```bash
   cd ~/KpihX-Labs/Fluid/fluid    # after clone per doc
   ./fluid.sh audit
   ./fluid.sh join fluid-node-pve-debian
   ```

---

## Troubleshooting cues

| Symptom | Check |
|---------|-------|
| No SSH keys in guest | `qm cloudinit pending <VMID>`; ensure `authorized_keys` on PVE is non-empty readable by paths you reference. |
| Wrong bridge / no DHCP conflict | Guests on static IP must avoid duplicate IP collisions; verify LAN plan. |
| Boot loops / grub issues | Prefer cloud image unchanged; resize after import, not corrupt base. |

---

## Related Fluid docs

- `docs/architecture/setup-existing-node-debian.md` — Inside-guest prerequisites and join.
- `fabric/hosts.json` — Canonical host identity and Tailscale/IP fields once known.
- `LIFECYCLE.md` — Where this node plugs into bootstrap/join story.
