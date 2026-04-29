# TODO - Fluid-K3s Roadmap

## 🤖 Telegram Governance
- [x] **Supervision Layer**: Directory structure and `telegram.sh` orchestrator created.
- [ ] **Cluster Watcher Bot**: Finalize the Python watcher to push alerts to Telegram.
- [ ] **Health Dashboard**: Generate daily ASCII health reports.

## 🛰️ Platform Extensions
- [x] **Survival Rules**: PriorityClasses Alpha/Beta/Gamma implemented in `04_platform/rules.sh`.
- [x] **KEDA Integration**: Auto-scaler for "Sleep Strategy" added in `04_platform/keda.sh`.
- [ ] **Windows WSL2 Auto-Setup**: Finalize the `wsl.sh` logic for automated Ubuntu instance spawning.
- [ ] **Android Optimization**: Implement battery-aware CockroachDB start/stop for mobile nodes.
- [ ] **NFS Persistence**: Automate the setup of decentralized NFS mounts on top of the VXLAN mesh.

## 🛡️ Security & Hardening
- [ ] **TLS Certificate Mesh**: Automate internal mTLS for CockroachDB.
- [ ] **Policy Guard**: Implement OPA (Open Policy Agent) for pod admission across the federation.
