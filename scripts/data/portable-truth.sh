#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/inventory.sh"

portable_truth_command="${1:-snapshot}"

portable_truth_archive_path() {
  local ts=$1
  echo "$FLUID_BACKUP_DIR/${FLUID_BACKUP_NAME_PREFIX}-${ts}.tar.gz"
}

portable_truth_snapshot() {
  fluid_state_bootstrap
  fluid_require_writable_state
  fluid_ensure_dir "$FLUID_BACKUP_DIR"
  fluid_ensure_dir "$FLUID_RENDER_DIR"

  local ts archive repo_parent repo_name
  ts="$(date +%Y%m%d-%H%M%S)"
  archive="$(portable_truth_archive_path "$ts")"
  repo_parent="$(dirname "$FLUID_ROOT")"
  repo_name="$(basename "$FLUID_ROOT")"

  fluid_run tar -czf "$archive" -C "$repo_parent" \
    "$repo_name/README.md" \
    "$repo_name/CONTRACT.md" \
    "$repo_name/LIFECYCLE.md" \
    "$repo_name/CHANGELOG.md" \
    "$repo_name/TODO.md" \
    "$repo_name/.gitignore" \
    "$repo_name/fabric" \
    "$repo_name/docs" \
    "$repo_name/state" \
    "$repo_name/render" \
    "$repo_name/fluid.sh" \
    "$repo_name/install.sh" \
    "$repo_name/purge.sh" \
    "$repo_name/scripts" \
    "$repo_name/templates" \
    "$repo_name/adapters"

  if [ "${FLUID_DRY_RUN}" != "true" ]; then
    local tmp
    tmp="$(mktemp)"
    jq --arg ts "$ts" '.last_backup = $ts' "$FLUID_STATE_PATH" >"$tmp"
    mv "$tmp" "$FLUID_STATE_PATH"
  fi

  fluid_info "Portable truth backup created: $archive"
}

portable_truth_restore() {
  local archive="" target_dir="$FLUID_RESTORE_DEFAULT_DIR"

  while [ $# -gt 0 ]; do
    case "$1" in
      --from)
        archive="${2:-}"
        shift 2
        ;;
      --into)
        target_dir="${2:-}"
        shift 2
        ;;
      *)
        fluid_die "Unknown restore argument. Expected --from <archive> [--into <dir>]."
        ;;
    esac
  done

  [ -n "$archive" ] || archive="$(find "$FLUID_BACKUP_DIR" -maxdepth 1 -type f -name "${FLUID_BACKUP_NAME_PREFIX}-*.tar.gz" | sort | tail -n 1)"
  [ -n "$archive" ] || fluid_die "No backup archive found. Run './fluid.sh backup' first."
  fluid_ensure_dir "$target_dir"
  fluid_run tar -xzf "$archive" -C "$target_dir"
  fluid_info "Portable truth restored from: $archive"
  fluid_info "Restore target directory: $target_dir"
}

portable_truth_validate_restore() {
  local archive validation_root repo_name restored_root
  repo_name="$(basename "$FLUID_ROOT")"
  archive="$(find "$FLUID_BACKUP_DIR" -maxdepth 1 -type f -name "${FLUID_BACKUP_NAME_PREFIX}-*.tar.gz" | sort | tail -n 1)"
  [ -n "$archive" ] || fluid_die "No backup archive exists yet. Run './fluid.sh backup' first."

  validation_root="$(mktemp -d "${FLUID_VALIDATE_RESTORE_DIR}.XXXXXX")"
  portable_truth_restore --from "$archive" --into "$validation_root"
  restored_root="$validation_root/$repo_name"

  [ -f "$restored_root/README.md" ] || fluid_die "Restore validation failed: README.md missing."
  [ -f "$restored_root/CONTRACT.md" ] || fluid_die "Restore validation failed: CONTRACT.md missing."
  [ -f "$restored_root/fabric/defaults.env" ] || fluid_die "Restore validation failed: fabric/defaults.env missing."
  [ -f "$restored_root/fabric/hosts.json" ] || fluid_die "Restore validation failed: fabric/hosts.json missing."
  [ -d "$restored_root/scripts" ] || fluid_die "Restore validation failed: scripts/ missing."
  [ -f "$restored_root/state/cluster-state.json" ] || fluid_die "Restore validation failed: state file missing."
  [ -d "$restored_root/templates" ] || fluid_die "Restore validation failed: templates/ missing."

  fluid_info "Restore validation passed in: $validation_root"
}

case "$portable_truth_command" in
  snapshot)
    portable_truth_snapshot
    ;;
  restore)
    portable_truth_restore "$@"
    ;;
  validate)
    portable_truth_validate_restore
    ;;
  *)
    fluid_die "Unknown portable truth command '$portable_truth_command'."
    ;;
esac
