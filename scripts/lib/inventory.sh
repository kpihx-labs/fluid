#!/usr/bin/env bash
# Hosts, profiles, policy, and mutable state helpers.

source "$FLUID_ROOT/scripts/lib/common.sh"
source "$FLUID_ROOT/scripts/lib/resolve.sh"

fluid_state_bootstrap() {
  fluid_ensure_dir "$FLUID_STATE_DIR"
  fluid_ensure_dir "$FLUID_STATE_DIR/locks"
  if [ ! -f "$FLUID_STATE_PATH" ]; then
    cat >"$FLUID_STATE_PATH" <<'EOF'
{
  "version": 3,
  "cluster_name": "fluid",
  "manager_host": null,
  "manager_advertise_addr": null,
  "authority_set": [],
  "worker_join_token": null,
  "manager_join_token": null,
  "retired_hosts": [],
  "last_backup": null,
  "portable_truth_generation": 1,
  "notes": "Mutable runtime state for the Fluid cluster."
}
EOF
  fi
}

fluid_require_writable_state() {
  fluid_state_bootstrap
  [ -w "$FLUID_STATE_PATH" ] || fluid_die "State file '$FLUID_STATE_PATH' is not writable by the current user."
}

fluid_inventory_hosts() {
  jq -r '.hosts[].name' "$FLUID_HOSTS_PATH"
}

fluid_host_exists() {
  local host=$1
  jq -e --arg host "$host" '.hosts[] | select(.name == $host)' "$FLUID_HOSTS_PATH" >/dev/null
}

fluid_raw_host_json() {
  local host=$1
  jq -c --arg host "$host" '.hosts[] | select(.name == $host)' "$FLUID_HOSTS_PATH"
}

fluid_host_profile_name() {
  local host=$1
  jq -r --arg host "$host" '.hosts[] | select(.name == $host) | (.profile // .platform // "linux")' "$FLUID_HOSTS_PATH"
}

fluid_profile_path() {
  printf '%s\n' "$FLUID_PROFILES_DIR/$1.json"
}

fluid_profile_json() {
  local profile=$1 file parent base overlay
  file="$(fluid_profile_path "$profile")"
  [ -f "$file" ] || fluid_die "Unknown profile '$profile'."

  parent="$(jq -r '.extends // empty' "$file")"
  if [ -n "$parent" ]; then
    base="$(fluid_profile_json "$parent")"
    overlay="$(jq -c 'del(.extends)' "$file")"
    jq -cn --argjson base "$base" --argjson overlay "$overlay" '$base * $overlay'
  else
    jq -c 'del(.extends)' "$file"
  fi
}

fluid_policy_json() {
  local file=$1 parent base overlay
  [ -f "$file" ] || fluid_die "Policy file '$file' is missing."
  parent="$(jq -r '.extends // empty' "$file")"
  if [ -n "$parent" ]; then
    base="$(fluid_policy_json "$FLUID_POLICIES_DIR/$parent.json")"
    overlay="$(jq -c 'del(.extends)' "$file")"
    jq -cn --argjson base "$base" --argjson overlay "$overlay" '$base * $overlay'
  else
    jq -c 'del(.extends)' "$file"
  fi
}

fluid_effective_host_json() {
  local host=$1 profile raw base
  fluid_host_exists "$host" || fluid_die "Unknown host '$host'."
  profile="$(fluid_host_profile_name "$host")"
  raw="$(fluid_raw_host_json "$host")"
  base="$(fluid_profile_json "$profile")"
  jq -cn --argjson base "$base" --argjson host "$raw" '$base * $host'
}

fluid_host_field() {
  local host=$1 filter=$2
  fluid_effective_host_json "$host" | jq -r "$filter"
}

fluid_host_tailscale_name() {
  local host=$1
  fluid_host_field "$host" '.network.tailscale_name // empty'
}

fluid_host_tailscale_ip() {
  local host=$1
  fluid_host_field "$host" '.network.tailscale_ip // empty'
}

fluid_host_role() {
  local host=$1
  fluid_host_field "$host" '.role // "observer"'
}

fluid_host_execution_capable() {
  case "$(fluid_host_role "$1")" in
    manager|worker) echo "true" ;;
    *) echo "false" ;;
  esac
}

fluid_host_survivor_capable() {
  fluid_effective_host_bool "$1" "SURVIVOR_CAPABLE" '.survivor_capable' "false"
}

fluid_host_authority_eligible() {
  fluid_effective_host_bool "$1" "AUTHORITY_ELIGIBLE" '.authority_eligible' "false"
}

fluid_host_continuity_enabled() {
  fluid_effective_host_bool "$1" "CONTINUITY_ENABLED" '.continuity_enabled' "$CONTINUITY_ENABLED_DEFAULT"
}

fluid_host_portable_truth_replica() {
  fluid_effective_host_bool "$1" "PORTABLE_TRUTH_REPLICA" '.portable_truth_replica' "false"
}

fluid_host_elevated() {
  fluid_effective_host_bool "$1" "ELEVATED" '.elevated' "false"
}

fluid_policy_authority_size() {
  fluid_policy_json "$FLUID_AUTHORITY_POLICY_PATH" | jq -r '.defaults.authority_size // 3'
}

fluid_policy_min_authority_size() {
  fluid_policy_json "$FLUID_AUTHORITY_POLICY_PATH" | jq -r '.defaults.minimum_authority_size // 1'
}

fluid_require_survivor_capable() {
  fluid_policy_json "$FLUID_AUTHORITY_POLICY_PATH" | jq -r '.requirements.survivor_capable // true' | sed 's/.*/\L&/'
}

fluid_require_authority_eligible() {
  fluid_policy_json "$FLUID_AUTHORITY_POLICY_PATH" | jq -r '.requirements.authority_eligible // true' | sed 's/.*/\L&/'
}

fluid_require_manager_role() {
  fluid_policy_json "$FLUID_AUTHORITY_POLICY_PATH" | jq -r '.requirements.manager_role // true' | sed 's/.*/\L&/'
}

fluid_underlay_type() {
  fluid_policy_json "$FLUID_NETWORK_POLICY_PATH" | jq -r '.underlay.type // "tailscale"'
}

fluid_underlay_interface() {
  fluid_policy_json "$FLUID_NETWORK_POLICY_PATH" | jq -r '.underlay.interface // "tailscale0"'
}

fluid_require_underlay() {
  fluid_policy_json "$FLUID_NETWORK_POLICY_PATH" | jq -r '.underlay.require // true' | sed 's/.*/\L&/'
}

fluid_tailscale_status_cmd() {
  fluid_policy_json "$FLUID_NETWORK_POLICY_PATH" | jq -r '.underlay.status_command // "tailscale status --json"'
}

fluid_advertise_mode() {
  fluid_policy_json "$FLUID_NETWORK_POLICY_PATH" | jq -r '.fluid.advertise_mode // "tailscale-ip"'
}

fluid_continuity_backup_schedule() {
  fluid_policy_json "$FLUID_CONTINUITY_POLICY_PATH" | jq -r '.defaults.backup_on_calendar // "hourly"'
}

fluid_local_tailscale_ip() {
  local iface
  iface="$(fluid_underlay_interface)"
  if command -v ip >/dev/null 2>&1; then
    ip -4 addr show "$iface" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n 1
  elif command -v ifconfig >/dev/null 2>&1; then
    ifconfig "$iface" 2>/dev/null | awk '/inet / {print $2}' | head -n 1
  fi
}

fluid_local_identity_sources_json() {
  local current_ts_ip
  current_ts_ip="$(fluid_local_tailscale_ip)"
  jq -cn --arg tailscale_ip "$current_ts_ip" '{tailscale_ip: $tailscale_ip}'
}

fluid_find_host_by_tailscale_ip() {
  local current_ts_ip
  current_ts_ip="$(fluid_local_tailscale_ip)"
  [ -n "$current_ts_ip" ] || return 1
  while read -r host; do
    [ -n "$host" ] || continue
    if fluid_effective_host_json "$host" | jq -e \
      --arg current_ts_ip "$current_ts_ip" \
      '
      .network.tailscale_ip == $current_ts_ip
      ' >/dev/null; then
      printf '%s\n' "$host"
      return 0
    fi
  done < <(fluid_inventory_hosts)
}

fluid_local_host_name() {
  fluid_find_host_by_tailscale_ip || true
}

fluid_manager_host() {
  fluid_state_bootstrap
  jq -r '.manager_host // empty' "$FLUID_STATE_PATH"
}

fluid_manager_advertise_addr() {
  fluid_state_bootstrap
  jq -r '.manager_advertise_addr // empty' "$FLUID_STATE_PATH"
}

fluid_authority_set() {
  fluid_state_bootstrap
  jq -r '.authority_set[]?' "$FLUID_STATE_PATH"
}

fluid_retired_hosts() {
  fluid_state_bootstrap
  jq -r '.retired_hosts[]?' "$FLUID_STATE_PATH"
}

fluid_set_cluster_runtime() {
  local manager_host=$1 advertise_addr=$2 manager_token=$3 worker_token=$4 tmp
  tmp="$(mktemp)"
  jq \
    --arg manager_host "$manager_host" \
    --arg advertise_addr "$advertise_addr" \
    --arg manager_token "$manager_token" \
    --arg worker_token "$worker_token" \
    '
    .manager_host = $manager_host
    | .manager_advertise_addr = $advertise_addr
    | .manager_join_token = $manager_token
    | .worker_join_token = $worker_token
    ' "$FLUID_STATE_PATH" >"$tmp"
  mv "$tmp" "$FLUID_STATE_PATH"
}

fluid_set_authority() {
  local hosts_csv=$1 tmp
  if [ "${FLUID_DRY_RUN}" = "true" ]; then
    fluid_info "DRY-RUN: set authority set to '$hosts_csv'"
    return 0
  fi
  tmp="$(mktemp)"
  jq --arg hosts_csv "$hosts_csv" '
    .authority_set = (($hosts_csv | split(",")) | map(select(length > 0)) | unique)
  ' "$FLUID_STATE_PATH" >"$tmp"
  mv "$tmp" "$FLUID_STATE_PATH"
}

fluid_add_authority_host() {
  local host=$1 authority_csv
  authority_csv="$(
    {
      fluid_authority_set || true
      printf '%s\n' "$host"
    } | awk 'NF && !seen[$0]++' | paste -sd ',' -
  )"
  fluid_set_authority "$authority_csv"
}

fluid_remove_authority_host() {
  local host=$1 tmp
  if [ "${FLUID_DRY_RUN}" = "true" ]; then
    fluid_info "DRY-RUN: remove authority host '$host'"
    return 0
  fi
  tmp="$(mktemp)"
  jq --arg host "$host" '.authority_set |= map(select(. != $host))' "$FLUID_STATE_PATH" >"$tmp"
  mv "$tmp" "$FLUID_STATE_PATH"
}

fluid_mark_retired() {
  local host=$1 tmp
  if [ "${FLUID_DRY_RUN}" = "true" ]; then
    fluid_info "DRY-RUN: mark retired '$host'"
    return 0
  fi
  tmp="$(mktemp)"
  jq --arg host "$host" '.retired_hosts = ((.retired_hosts + [$host]) | unique)' "$FLUID_STATE_PATH" >"$tmp"
  mv "$tmp" "$FLUID_STATE_PATH"
}

fluid_clear_retired() {
  local host=$1 tmp
  if [ "${FLUID_DRY_RUN}" = "true" ]; then
    fluid_info "DRY-RUN: clear retired '$host'"
    return 0
  fi
  tmp="$(mktemp)"
  jq --arg host "$host" '.retired_hosts |= map(select(. != $host))' "$FLUID_STATE_PATH" >"$tmp"
  mv "$tmp" "$FLUID_STATE_PATH"
}

fluid_host_swarm_role() {
  case "$(fluid_host_role "$1")" in
    manager) echo "manager" ;;
    worker) echo "worker" ;;
    *) echo "none" ;;
  esac
}

fluid_host_is_authority_candidate() {
  local host=$1
  if [ "$(fluid_require_manager_role)" = "true" ] && [ "$(fluid_host_role "$host")" != "manager" ]; then
    echo "false"
    return 0
  fi
  if [ "$(fluid_require_survivor_capable)" = "true" ] && [ "$(fluid_host_survivor_capable "$host")" != "true" ]; then
    echo "false"
    return 0
  fi
  if [ "$(fluid_require_authority_eligible)" = "true" ] && [ "$(fluid_host_authority_eligible "$host")" != "true" ]; then
    echo "false"
    return 0
  fi
  echo "true"
}

fluid_host_swarm_labels_json() {
  local host=$1
  fluid_effective_host_json "$host" | jq -c '
    (.labels // {})
    * {
      "fluid.host": .name,
      "fluid.platform": .platform,
      "fluid.profile": (.profile // .platform),
      "fluid.role": .role,
      "fluid.execution_capable": (
        if (.role == "manager" or .role == "worker") then "true" else "false" end
      ),
      "fluid.survivor_capable": (.survivor_capable | tostring),
      "fluid.authority_eligible": (.authority_eligible | tostring),
      "fluid.continuity_enabled": (.continuity_enabled | tostring),
      "fluid.portable_truth_replica": (.portable_truth_replica | tostring)
    }
  '
}

fluid_best_authority_candidates() {
  while read -r host; do
    [ -n "$host" ] || continue
    [ "$(fluid_host_is_authority_candidate "$host")" = "true" ] || continue
    printf '%s;%s\n' \
      "$(fluid_effective_host_value "$host" "PROMOTION_WEIGHT" '.authority_weight' "0")" \
      "$host"
  done < <(fluid_inventory_hosts) | sort -t';' -k1,1nr | cut -d';' -f2
}

fluid_portable_truth_replicas() {
  while read -r host; do
    [ -n "$host" ] || continue
    [ "$(fluid_host_portable_truth_replica "$host")" = "true" ] && printf '%s\n' "$host"
  done < <(fluid_inventory_hosts)
}
