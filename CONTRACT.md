# CONTRACT.md — Fluid-K3s

> **[100% TRANSPARENT · 0% HIDDEN MAGIC · SOVEREIGN INFRASTRUCTURE]**

This document defines the absolute technical contract between the Fluid-K3s orchestration and your hardware.

---

## 🏛️ Facet 1: Device Impact (What we touch)

### 1.1 Network Stack
| Component | Impact | Change |
|-----------|--------|--------|
| **Interface** | `vxlan-fluid` | Created as a Layer 2 overlay on `tailscale0`. |
| **MTU** | `1150` | Explicitly set to avoid fragmentation over WireGuard (1280). |
| **Routing** | `10.20.20.0/24` | Static overlay IPs assigned to each peer. |
| **Broadcasting**| `ARP` | VIP `10.20.20.250` managed by Arping for high-availability. |

### 1.2 Storage Stack
| Component | Path | Impact |
|-----------|------|--------|
| **Database** | `~/cockroach-data` | Local distributed SQL storage (Multi-Master). |
| **Engine** | `/var/lib/rancher/k3s`| Stateless K3s binaries and cluster identity. |
| **Replication**| `/var/lib/longhorn` | Block storage replication across nodes. |

### 1.3 System Resources (Lean Mode)
- **CockroachDB**: Capped at `128Mi` RAM for cache and `128Mi` for SQL (Silent Host Policy).
- **K3s Engine**: Runs with `--disable traefik --disable servicelb` to minimize CPU/RAM footprint.

---

## 🛠️ Facet 2: Lifecycle Contract (Installation/Purge)

### 2.1 The "Tabula Rasa" Guarantee
The `purge.sh` script is designed to be **symmetrically radical**. It targets:
1.  **Processes**: `SIGKILL` on cockroach, postgres, k3s.
2.  **Interfaces**: Total removal of `vxlan-fluid` and `br-fluid`.
3.  **Filesystem**: `rm -rf` on all data directories mentioned in Facet 1.
4.  **Result**: The host returns to a 100% pre-deployment state.

### 2.2 Agnosticism Rules
- **Convention over Configuration**: Scripts follow `$NODE_OS.sh` naming.
- **Single Source of Truth**: All variables are resolved via `config.env` and `hosts.json`.
- **Privilege**: Standard audited `sudo` only. No proprietary gateways.

---

## 🛡️ Facet 3: Security & Governance

### 3.1 Data Residency
- **100% Local**: No data leaves the Tailscale mesh.
- **Insecure mode**: Database is currently in `--insecure` mode because it is protected by the host-to-host encryption of Tailscale/WireGuard.

### 3.2 Automated Governance (Upcoming)
Each host will have a dedicated Telegram bot monitoring its local state and alerting via the global mesh channel.
