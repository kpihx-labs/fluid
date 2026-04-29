# TODO - Fluid-K3s Roadmap

## 🤖 Telegram Governance
- [ ] **Host Bots**: Create a dedicated Telegram bot for each host (`pve-bot`, `ubuntu-bot`, `s25-bot`).
- [ ] **Infrastructure Bot**: Centralized `fluid-mesh-bot` for cluster-wide status alerts.
- [ ] **Health Checks**: Automate heartbeats from CockroachDB Mesh to Telegram.

## 🛰️ Platform Extensions
- [ ] **Windows Hyper-V**: Finalize the `00_provision_vm/windows.ps1` logic for automated node spawning.
- [ ] **Android Optimization**: Implement battery-aware CockroachDB start/stop for mobile nodes.
- [ ] **NFS Persistence**: Automate the setup of decentralized NFS mounts on top of the VXLAN mesh.

## 🛡️ Security & Hardening
- [ ] **TLS Certificate Mesh**: Automate internal mTLS for CockroachDB (currently insecure for ease of deployment).
- [ ] **Policy Guard**: Implement OPA (Open Policy Agent) for pod admission across the federation.
