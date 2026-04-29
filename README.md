# 🛡️ Fluid-K3s: Sovereign Agnostic Mesh

> **100% Peer-to-Peer · 0% Hardcode · Sovereign Infrastructure**

Fluid-K3s is a domain-driven infrastructure project designed to deploy a high-resilience, decentralized Kubernetes cluster across a heterogeneous federation (Proxmox, Ubuntu, Android, Mac, Windows).

## 🚀 Key Features
- **Fluid-Mesh**: Layer 2 overlay via VXLAN over Tailscale for seamless HA.
- **Distributed SQL**: Multi-master state layer powered by **CockroachDB**.
- **Cross-Platform**: Support for Linux, Android (Termux), Darwin (Mac), and Windows (WSL/Hyper-V).
- **Tabula Rasa**: Radical reset capability for deterministic deployments.

## 🛠️ Quick Start

### 1. Configure the Registry
Update `hosts.json` with your device names and Tailscale IPs.

### 2. Install on any Peer
```bash
cd scripts/
./install.sh
```

### 3. Radical Reset
```bash
cd scripts/
./purge.sh
```

## 🧠 Architecture
Every node is a peer. There is no "Master" node. If the Proxmox host fails, the Ubuntu workstation or even a mobile device can hold the cluster state and leadership.

## 🏛️ Documentation
- [CONTRACT.md](./CONTRACT.md): The technical contract and impact analysis.
- [CHANGELOG.md](./CHANGELOG.md): Project evolution history.
- [TODO.md](./TODO.md): Roadmap and upcoming features.
