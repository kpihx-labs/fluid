# Changelog

## 2026-05-01

- Pivoted Fluid from a half-finished manager model to a Swarm-first model.
- Replaced the runtime core with Docker Swarm bootstrap, join, label sync, promote, demote, and retire flows.
- Added project lifecycle commands driven by per-repo `fluid.yml`.
- Kept continuity, backup, and restore as host-level recovery layers.
- Simplified the contract and README to match the actual Swarm-first architecture.
