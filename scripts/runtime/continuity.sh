#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/inventory.sh"

continuity_command="${1:-status}"
target_host="${2:-$(fluid_local_host_name)}"

continuity_render_dir() {
  echo "$FLUID_CONTINUITY_RENDER_DIR/$target_host"
}

continuity_enabled_for_host() {
  fluid_host_continuity_enabled "$target_host"
}

continuity_supports_apply() {
  [ "$(fluid_host_field "$target_host" '.runtime.supports_continuity_apply // false')" = "true" ]
}

continuity_render_linux() {
  local render_dir install_root state_dir marker_file timer authority_csv
  render_dir="$(continuity_render_dir)"
  install_root="$(fluid_effective_host_value "$target_host" "CONTINUITY_INSTALL_ROOT" '' "$CONTINUITY_INSTALL_ROOT_DEFAULT")"
  state_dir="$(fluid_effective_host_value "$target_host" "CONTINUITY_STATE_DIR" '' "$CONTINUITY_STATE_DIR_DEFAULT")"
  marker_file="$(fluid_effective_host_value "$target_host" "CONTINUITY_MARKER_FILE" '' "$CONTINUITY_MARKER_FILE_DEFAULT")"
  timer="$(fluid_effective_host_value "$target_host" "CONTINUITY_BACKUP_ON_CALENDAR" '' "$(fluid_continuity_backup_schedule)")"
  authority_csv="$(fluid_authority_set | paste -sd ',' -)"

  cat >"$render_dir/README.txt" <<EOF
Fluid continuity payload for $target_host

Purpose:
- keep local access to portable truth and recovery assets
- expose a durable recovery shell entrypoint
- materialize authority metadata locally
- provide an explicit local backup trigger path

Continuity enabled for this host: $(continuity_enabled_for_host)
Install root: $install_root
State dir: $state_dir
Marker file: $marker_file
Backup schedule: $timer
EOF

  cat >"$render_dir/state-guard.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$install_root/bin" "$state_dir" "$state_dir/recovery"
touch "$state_dir/.guard-ok"
EOF

  cat >"$render_dir/authority-marker.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$(dirname "$marker_file")"
cat >"$marker_file" <<MARKER
HOST_NAME=$target_host
ACTIVE_AUTHORITY_SET=$authority_csv
UPDATED_AT=$(date -Is)
MARKER
EOF

  cat >"$render_dir/backup-trigger.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
"$ROOT_DIR/fluid.sh" backup
EOF

  cat >"$render_dir/fluid-recovery-shell.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
cat <<'HELP'
Fluid recovery shell

Useful commands:
  ./fluid.sh status
  ./fluid.sh bootstrap
  ./fluid.sh backup
  ./fluid.sh restore --from <archive>
  ./fluid.sh sync-labels
HELP
EOF

  cat >"$render_dir/$CONTINUITY_STATE_GUARD_UNIT_DEFAULT" <<EOF
[Unit]
Description=Fluid state guard
After=network-online.target

[Service]
Type=oneshot
ExecStart=$install_root/bin/state-guard.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

  cat >"$render_dir/$CONTINUITY_AUTHORITY_MARKER_UNIT_DEFAULT" <<EOF
[Unit]
Description=Fluid authority marker
After=$CONTINUITY_STATE_GUARD_UNIT_DEFAULT

[Service]
Type=oneshot
ExecStart=$install_root/bin/authority-marker.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

  cat >"$render_dir/$CONTINUITY_BACKUP_TRIGGER_UNIT_DEFAULT" <<EOF
[Unit]
Description=Fluid backup trigger

[Service]
Type=oneshot
ExecStart=$install_root/bin/backup-trigger.sh
EOF

  cat >"$render_dir/$CONTINUITY_BACKUP_TRIGGER_TIMER_DEFAULT" <<EOF
[Unit]
Description=Fluid backup trigger timer

[Timer]
OnCalendar=$timer
Persistent=true

[Install]
WantedBy=timers.target
EOF

  cat >"$render_dir/$CONTINUITY_RECOVERY_SHELL_UNIT_DEFAULT" <<EOF
[Unit]
Description=Fluid recovery shell materializer
After=$CONTINUITY_STATE_GUARD_UNIT_DEFAULT

[Service]
Type=oneshot
ExecStart=$install_root/bin/fluid-recovery-shell.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

  chmod +x "$render_dir"/*.sh
}

continuity_render_non_linux() {
  local render_dir
  render_dir="$(continuity_render_dir)"
  cat >"$render_dir/README.txt" <<EOF
Fluid continuity payload for $target_host

Platform: $(fluid_host_field "$target_host" '.platform')
Continuity enabled for this host: $(continuity_enabled_for_host)
Automated apply supported: $(fluid_host_field "$target_host" '.runtime.supports_continuity_apply')

This host currently receives documentation-only continuity output.
To change that behavior, edit fabric/profiles/$(fluid_host_profile_name "$target_host").json
or add host-specific overrides in fabric/hosts.json.
EOF
}

continuity_render() {
  fluid_host_exists "$target_host" || fluid_die "Unknown host '$target_host'."
  fluid_ensure_dir "$(continuity_render_dir)"

  if fluid_is_linux_family "$(fluid_host_field "$target_host" '.platform')"; then
    continuity_render_linux
  else
    continuity_render_non_linux
  fi
}

continuity_apply_linux() {
  local render_dir install_root state_dir
  render_dir="$(continuity_render_dir)"
  install_root="$(fluid_effective_host_value "$target_host" "CONTINUITY_INSTALL_ROOT" '' "$CONTINUITY_INSTALL_ROOT_DEFAULT")"
  state_dir="$(fluid_effective_host_value "$target_host" "CONTINUITY_STATE_DIR" '' "$CONTINUITY_STATE_DIR_DEFAULT")"

  [ -f "$render_dir/$CONTINUITY_STATE_GUARD_UNIT_DEFAULT" ] || fluid_die "Continuity assets are missing for '$target_host'. Run continuity render first."

  fluid_run_privileged "Create Fluid continuity install root" mkdir -p "$install_root/bin"
  fluid_run_privileged "Create Fluid continuity state dir" mkdir -p "$state_dir"

  for script in state-guard.sh authority-marker.sh backup-trigger.sh fluid-recovery-shell.sh; do
    fluid_run_privileged "Install continuity script '$script'" install -m 0755 "$render_dir/$script" "$install_root/bin/$script"
  done

  for unit in \
    "$CONTINUITY_STATE_GUARD_UNIT_DEFAULT" \
    "$CONTINUITY_AUTHORITY_MARKER_UNIT_DEFAULT" \
    "$CONTINUITY_BACKUP_TRIGGER_UNIT_DEFAULT" \
    "$CONTINUITY_BACKUP_TRIGGER_TIMER_DEFAULT" \
    "$CONTINUITY_RECOVERY_SHELL_UNIT_DEFAULT"; do
    fluid_run_privileged "Install continuity unit '$unit'" install -m 0644 "$render_dir/$unit" "$FLUID_SYSTEMD_UNIT_DIR/$unit"
  done

  fluid_run_privileged "Reload systemd after continuity unit changes" systemctl daemon-reload
  fluid_run_privileged "Enable continuity baseline units" systemctl enable --now \
    "$CONTINUITY_STATE_GUARD_UNIT_DEFAULT" \
    "$CONTINUITY_AUTHORITY_MARKER_UNIT_DEFAULT" \
    "$CONTINUITY_RECOVERY_SHELL_UNIT_DEFAULT" \
    "$CONTINUITY_BACKUP_TRIGGER_TIMER_DEFAULT"
}

continuity_uninstall_linux() {
  local install_root state_dir marker_parent
  install_root="$(fluid_effective_host_value "$target_host" "CONTINUITY_INSTALL_ROOT" '' "$CONTINUITY_INSTALL_ROOT_DEFAULT")"
  state_dir="$(fluid_effective_host_value "$target_host" "CONTINUITY_STATE_DIR" '' "$CONTINUITY_STATE_DIR_DEFAULT")"
  marker_parent="$(dirname "$(fluid_effective_host_value "$target_host" "CONTINUITY_MARKER_FILE" '' "$CONTINUITY_MARKER_FILE_DEFAULT")")"

  fluid_run_privileged "Stop continuity units" systemctl disable --now \
    "$CONTINUITY_STATE_GUARD_UNIT_DEFAULT" \
    "$CONTINUITY_AUTHORITY_MARKER_UNIT_DEFAULT" \
    "$CONTINUITY_RECOVERY_SHELL_UNIT_DEFAULT" \
    "$CONTINUITY_BACKUP_TRIGGER_TIMER_DEFAULT" \
    2>/dev/null || true

  fluid_run_privileged "Stop continuity trigger service if present" systemctl stop \
    "$CONTINUITY_BACKUP_TRIGGER_UNIT_DEFAULT" \
    2>/dev/null || true

  for unit in \
    "$CONTINUITY_STATE_GUARD_UNIT_DEFAULT" \
    "$CONTINUITY_AUTHORITY_MARKER_UNIT_DEFAULT" \
    "$CONTINUITY_BACKUP_TRIGGER_UNIT_DEFAULT" \
    "$CONTINUITY_BACKUP_TRIGGER_TIMER_DEFAULT" \
    "$CONTINUITY_RECOVERY_SHELL_UNIT_DEFAULT"; do
    fluid_run_privileged "Remove continuity unit '$unit'" rm -f "$FLUID_SYSTEMD_UNIT_DIR/$unit"
  done

  fluid_run_privileged "Reload systemd after continuity purge" systemctl daemon-reload
  fluid_run_privileged "Remove continuity install root" rm -rf "$install_root"
  fluid_run_privileged "Remove continuity state dir" rm -rf "$state_dir"
  fluid_run_privileged "Remove continuity marker dir if empty" rmdir "$marker_parent" 2>/dev/null || true
}

case "$continuity_command" in
  render)
    continuity_render
    ;;
  apply|enable)
    if continuity_supports_apply; then
      continuity_apply_linux
    else
      fluid_info "Continuity apply is intentionally not automated for platform '$(fluid_host_field "$target_host" '.platform')'."
    fi
    ;;
  disable)
    fluid_info "Disable is intentionally manual for now: stop/disable the continuity units you no longer want."
    ;;
  uninstall|purge)
    if fluid_is_linux_family "$(fluid_host_field "$target_host" '.platform')"; then
      continuity_uninstall_linux
    else
      fluid_info "Continuity uninstall is only automated for Linux-family hosts."
    fi
    ;;
  status)
    fluid_info "Continuity enabled for '$target_host': $(continuity_enabled_for_host)"
    ;;
  *)
    fluid_die "Unknown continuity command '$continuity_command'."
    ;;
esac
