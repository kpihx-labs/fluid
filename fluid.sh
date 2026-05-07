#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/inventory.sh"

fluid_require_cmd jq

command_name="${1:-help}"
shift || true

case "$command_name" in
  help|-h|--help)
    cat <<'EOF'
Fluid

Usage:
  ./fluid.sh <command> [args]

Core:
  help
  audit
  status
  bootstrap
  join [host]
  promote <host>
  demote <host>
  sync-labels [host]
  continuity <render|apply|status>
  link [user|global]
  backup
  restore --from <archive> [--into <dir>]
  validate-restore
  retire <host>
  uninstall [host]
  access validate
  access render
  access apply tailscale

Projects:
  project validate <repo>
  project render <repo>
  project deploy <repo>

Fabric:
  - Source of truth: fabric/
  - Mutable state: state/cluster-state.json
  - Generated output: render/
EOF
    ;;
  audit) exec bash "$ROOT_DIR/scripts/lifecycle/audit.sh" "$@" ;;
  status) exec bash "$ROOT_DIR/scripts/lifecycle/status.sh" "$@" ;;
  bootstrap) exec bash "$ROOT_DIR/scripts/lifecycle/bootstrap.sh" "$@" ;;
  join) exec bash "$ROOT_DIR/scripts/lifecycle/join.sh" "$@" ;;
  promote) exec bash "$ROOT_DIR/scripts/lifecycle/promote.sh" "$@" ;;
  demote) exec bash "$ROOT_DIR/scripts/lifecycle/demote.sh" "$@" ;;
  sync-labels) exec bash "$ROOT_DIR/scripts/lifecycle/sync-labels.sh" "$@" ;;
  continuity) exec bash "$ROOT_DIR/scripts/lifecycle/continuity.sh" "$@" ;;
  link) exec bash "$ROOT_DIR/scripts/lifecycle/link.sh" "$@" ;;
  backup) exec bash "$ROOT_DIR/scripts/lifecycle/backup.sh" "$@" ;;
  restore) exec bash "$ROOT_DIR/scripts/lifecycle/restore.sh" "$@" ;;
  validate-restore) exec bash "$ROOT_DIR/scripts/lifecycle/validate-restore.sh" "$@" ;;
  retire) exec bash "$ROOT_DIR/scripts/lifecycle/retire.sh" "$@" ;;
  uninstall) exec bash "$ROOT_DIR/scripts/lifecycle/uninstall.sh" "$@" ;;
  access) exec bash "$ROOT_DIR/scripts/lifecycle/access.sh" "$@" ;;
  project) exec bash "$ROOT_DIR/scripts/lifecycle/project.sh" "$@" ;;
  *)
    fluid_die "Unknown command '$command_name'. Run './fluid.sh help'."
    ;;
esac
