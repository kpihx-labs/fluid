# 🚀 Fluid-K3s: Universal Federation Deployment Guide

This guide provides the agnostic, hyper-documented procedure for deploying a high-availability, 1-node survival cluster across Linux, macOS, and WSL2.

---

## 🛠️ Phase 0: Host Provisioning & State Pre-requisites

### 0.1 Host Preparation (Proxmox Example)
If deploying on Proxmox, use the automated provisioner to spawn the VM:
```bash
# Sourcing labels from config.env for identity consistency
VM_NAME_PREFIX=$MASTER_1_HOST bash scripts/0-pve-provision.sh 100
```

### 0.2 Initializing the Decentralized Brain (CockroachDB)
The state layer must exist before the engine can start. Run on both primary nodes:
```bash
# On PVE and Ubuntu hosts
bash scripts/0.1-db-setup.sh
```

### 0.3 Launching the Floating Entry Point (Kube-VIP)
This Virtual IP ($CLUSTER_VIP) ensures a single permanent gateway for all nodes.
```bash
# On PVE (Seed) and Ubuntu (Relay) hosts
bash scripts/0.2-vip-setup.sh
```

---

## 🚀 Phase 1: Launching the Stateless Engine (Agnostic)

### 1.1 Triggering the Conductor
The conductor manages the final engine installation and connection to the brain.
```bash
# On PVE (as Seed)
bash scripts/1-launch.sh server-init

# On Ubuntu (as Relay)
bash scripts/1-launch.sh server-join
```

### 1.2 Joining specialized nodes (WSL2 & Mac)
These nodes join the federation via the Virtual IP API.
```bash
# On WSL2 SSD (WSL2) or Mac Studio (Lima)
VM_NAME_PREFIX=$MASTER_3_HOST bash scripts/1-launch.sh server-join
```

---

## 🧪 Phase 2: Resilience Verification (The "Kill Test")

To validate the "i > 0" survival architecture:
1.  **Verify Cluster:** `kubectl get nodes` (Should show all active cells).
2.  **Extinguish Seed:** Violently shut down the PVE Laptop.
3.  **Validate Relay:** Run `kubectl get nodes` from Ubuntu. The cluster MUST remain responsive and writable.
4.  **Confirm VIP:** Ping `$CLUSTER_VIP`. It should have migrated to Ubuntu in < 15 seconds.

---

## 🛡️ Phase 3: Service Layer Automates

Activate the specialized service layers once the federation is stable:
1.  **Distributed Storage:** `bash scripts/2-longhorn.sh`
2.  **Secret Management:** `bash scripts/3-eso.sh`
