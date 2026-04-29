# CHANGELOG - Fluid-K3s

All notable changes to this project will be documented in this file.

## [1.0.0] - 2026-04-29
### Added
- **Agnostic Orchestration**: New `install.sh` and `purge.sh` driven by convention ($NODE_OS.sh/ps1).
- **Universal Registry**: Centralized `hosts.json` using `tailscale_ip` as the primary identifier.
- **Decentralized State**: Migration from single Postgres to **CockroachDB Mesh** (multi-master).
- **Mobile Quorum**: Support for Android (S25 Ultra / Tablet) as witness nodes via Termux.
- **L2 Mesh**: VXLAN overlay on top of Tailscale for HA broadcast domain.
- **Stateless Engine**: K3s configured with external SQL (Kine) for control plane liquidity.

### Changed
- Renamed `inventory.json` to `hosts.json` for better alignment with industry standards.
- Refactored all phase scripts to use a unified `linux.sh` base for PVE and Ubuntu.
- Moved from hardcoded IPs to dynamic JQ-based value extraction.

### Removed
- Reliance on personal gateway wrappers (SUI) in favor of standard audited `sudo`.
- Hardcoded hostname checks for IP assignment.
