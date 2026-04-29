# 🏗️ Audit Réseau : PVE (Seed)
Date : 2026-04-29

## Interfaces Physiques
- **Bridge WAN (vmbr0) :** 129.104.234.138/22 (Réseau Polytechnique)
- **Tailscale (tailscale0) :** 100.123.81.21/32

## Ponts Proxmox
- **vmbr1 :** 10.10.10.1/24 (Segment Cluster Cible)
- **fwbr100i0 :** Pont pare-feu VM 100

## Routes Principales
- Default via 129.104.235.254 (vmbr0)
- 10.10.10.0/24 via vmbr1 (Local)
