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
  backup
  restore --from <archive> [--into <dir>]
  validate-restore
  retire <host>

Projects:
  project validate <repo>
  project render <repo>
  project deploy <repo>
EOF
    ;;
  audit) exec "$ROOT_DIR/scripts/lifecycle/audit.sh" "$@" ;;
  status) exec "$ROOT_DIR/scripts/lifecycle/status.sh" "$@" ;;
  bootstrap) exec "$ROOT_DIR/scripts/lifecycle/bootstrap.sh" "$@" ;;
  join) exec "$ROOT_DIR/scripts/lifecycle/join.sh" "$@" ;;
  promote) exec "$ROOT_DIR/scripts/lifecycle/promote.sh" "$@" ;;
  demote) exec "$ROOT_DIR/scripts/lifecycle/demote.sh" "$@" ;;
  sync-labels) exec "$ROOT_DIR/scripts/lifecycle/sync-labels.sh" "$@" ;;
  continuity) exec "$ROOT_DIR/scripts/lifecycle/continuity.sh" "$@" ;;
  backup) exec "$ROOT_DIR/scripts/lifecycle/backup.sh" "$@" ;;
  restore) exec "$ROOT_DIR/scripts/lifecycle/restore.sh" "$@" ;;
  validate-restore) exec "$ROOT_DIR/scripts/lifecycle/validate-restore.sh" "$@" ;;
  retire) exec "$ROOT_DIR/scripts/lifecycle/retire.sh" "$@" ;;
  project) exec "$ROOT_DIR/scripts/lifecycle/project.sh" "$@" ;;
  *)
    fluid_die "Unknown command '$command_name'. Run './fluid.sh help'."
    ;;
esac
