#!/usr/bin/env bash
# Hosts, profiles, policy, and mutable state helpers.

source "$FLUID_ROOT/scripts/lib/common.sh"
source "$FLUID_ROOT/scripts/lib/resolve.sh"

fluid_state_bootstrap() {
  fluid_ensure_dir "$(dirname "$FLUID_STATE_PATH")"
  if [ ! -f "$FLUID_STATE_PATH" ]; then
    cat >"$FLUID_STATE_PATH" <<'EOF'
{
  "version": 2,
  "cluster_name": "fluid",
  "manager_host": null,
  "manager_advertise_addr": null,
  "authority_set": [],
  "worker_join_token": null,
  "manager_join_token": null,
  "retired_hosts": [],
  "last_backup": null,
  "portable_truth_generation": 1,
  "notes": "Mutable runtime state for the Fluid Swarm cluster."
}
EOF
  fi
}

fluid_require_writable_state() {
  fluid_state_bootstrap
  [ -w "$FLUID_STATE_PATH" ] || fluid_die "State file '$FLUID_STATE_PATH' is not writable by the current user. Fix ownership before running mutable Fluid commands."
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
  echo "$FLUID_PROFILES_DIR/$1.json"
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

fluid_host_ssh_target() {
  local host=$1 target
  target="$(fluid_host_field "$host" '.ssh.target // empty')"
  if [ -n "$target" ] && [ "$target" != "null" ]; then
    printf '%s\n' "$target"
    return 0
  fi

  target="$(fluid_host_tailscale_name "$host")"
  if [ -n "$target" ] && [ "$target" != "null" ]; then
    printf '%s\n' "$target"
    return 0
  fi

  printf '%s\n' "$host"
}

fluid_policy_authority_size() {
  fluid_effective_global_value "FLUID_DEFAULT_AUTHORITY_SIZE" "$FLUID_AUTHORITY_POLICY_PATH" '.defaults.authority_size' "3"
}

fluid_policy_min_authority_size() {
  fluid_effective_global_value "FLUID_MIN_AUTHORITY_SIZE" "$FLUID_AUTHORITY_POLICY_PATH" '.defaults.minimum_authority_size' "1"
}

fluid_require_survivor_capable() {
  fluid_effective_global_bool "FLUID_AUTHORITY_REQUIRE_SURVIVOR_CAPABLE" "$FLUID_AUTHORITY_POLICY_PATH" '.requirements.survivor_capable' "true"
}

fluid_require_authority_eligible() {
  fluid_effective_global_bool "FLUID_AUTHORITY_REQUIRE_ELIGIBLE" "$FLUID_AUTHORITY_POLICY_PATH" '.requirements.authority_eligible' "true"
}

fluid_require_swarm_manager() {
  fluid_effective_global_bool "FLUID_AUTHORITY_REQUIRE_SWARM_MANAGER" "$FLUID_AUTHORITY_POLICY_PATH" '.requirements.swarm_manager' "true"
}

fluid_underlay_type() {
  fluid_effective_global_value "FLUID_UNDERLAY" "$FLUID_NETWORK_POLICY_PATH" '.underlay.type' "tailscale"
}

fluid_underlay_interface() {
  fluid_effective_global_value "FLUID_UNDERLAY_INTERFACE" "$FLUID_NETWORK_POLICY_PATH" '.underlay.interface' "tailscale0"
}

fluid_require_underlay() {
  fluid_effective_global_bool "FLUID_REQUIRE_TAILSCALE" "$FLUID_NETWORK_POLICY_PATH" '.underlay.require' "true"
}

fluid_tailscale_status_cmd() {
  fluid_effective_global_value "FLUID_TAILSCALE_STATUS_CMD" "$FLUID_NETWORK_POLICY_PATH" '.underlay.status_command' "tailscale status --json"
}

fluid_advertise_mode() {
  fluid_effective_global_value "FLUID_ADVERTISE_MODE" "$FLUID_NETWORK_POLICY_PATH" '.fluid.advertise_mode' "tailscale-ip"
}

fluid_overlay_enabled() {
  fluid_effective_global_bool "FLUID_OVERLAY_ENABLED" "$FLUID_NETWORK_POLICY_PATH" '.fluid.overlay.enabled' "false"
}

fluid_overlay_cidr() {
  fluid_effective_global_value "FLUID_OVERLAY_CIDR" "$FLUID_NETWORK_POLICY_PATH" '.fluid.overlay.cidr' ""
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

fluid_find_host_by_hostname() {
  local current_hostname current_ts_ip current_hostname_lower
  current_hostname="$(fluid_detect_hostname)"
  current_ts_ip="$(fluid_local_tailscale_ip)"
  current_hostname_lower="$(printf '%s' "$current_hostname" | tr '[:upper:]' '[:lower:]')"

  while read -r host; do
    [ -n "$host" ] || continue
    if fluid_effective_host_json "$host" | jq -e \
      --arg current_hostname_lower "$current_hostname_lower" \
      --arg current_hostname "$current_hostname" \
      --arg current_ts_ip "$current_ts_ip" \
      '
      (.name | ascii_downcase) as $host_name
      |
      (
        (.match.hostnames // []) | map(ascii_downcase) | index($current_hostname_lower)
      ) != null
      or (.network.tailscale_ip == $current_ts_ip)
      or (.network.tailscale_name == $current_hostname)
      or ($current_hostname_lower | contains($host_name))
      ' >/dev/null; then
      echo "$host"
      return 0
    fi
  done < <(fluid_inventory_hosts)
}

fluid_local_host_name() {
  fluid_find_host_by_hostname || true
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
  local manager_host=$1 advertise_addr=$2 manager_token=$3 worker_token=$4
  local tmp
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
  local host=$1
  if [ "$(fluid_effective_host_bool "$host" "SWARM_MANAGER_ENABLED" '.capabilities.swarm_manager' "false")" = "true" ] && \
     [ "$(fluid_effective_host_bool "$host" "AUTHORITY_ELIGIBLE" '.authority_eligible' "false")" = "true" ]; then
    echo "manager"
  elif [ "$(fluid_effective_host_bool "$host" "SWARM_WORKER_ENABLED" '.capabilities.swarm_worker' "true")" = "true" ]; then
    echo "worker"
  else
    echo "none"
  fi
}

fluid_host_swarm_labels_json() {
  local host=$1
  fluid_effective_host_json "$host" | jq -c '
    (
      .swarm.labels // {}
    )
    * {
      "fluid.host": .name,
      "fluid.platform": .platform,
      "fluid.profile": (.profile // .platform),
      "fluid.execution_capable": (.execution_capable | tostring)
    }
  '
}

fluid_best_authority_candidates() {
  while read -r host; do
    [ -n "$host" ] || continue
    if [ "$(fluid_require_survivor_capable)" = "true" ] && [ "$(fluid_effective_host_bool "$host" "SURVIVOR_CAPABLE" '.survivor_capable' "false")" != "true" ]; then
      continue
    fi
    if [ "$(fluid_require_authority_eligible)" = "true" ] && [ "$(fluid_effective_host_bool "$host" "AUTHORITY_ELIGIBLE" '.authority_eligible' "false")" != "true" ]; then
      continue
    fi
    if [ "$(fluid_require_swarm_manager)" = "true" ] && [ "$(fluid_effective_host_bool "$host" "SWARM_MANAGER_ENABLED" '.capabilities.swarm_manager' "false")" != "true" ]; then
      continue
    fi
    printf '%s;%s\n' \
      "$(fluid_effective_host_value "$host" "PROMOTION_WEIGHT" '.policy.promotion_weight' "0")" \
      "$host"
  done < <(fluid_inventory_hosts) | sort -t';' -k1,1nr | cut -d';' -f2
}

fluid_portable_truth_replicas() {
  while read -r host; do
    [ -n "$host" ] || continue
    if [ "$(fluid_effective_host_bool "$host" "PORTABLE_TRUTH_REPLICA" '.capabilities.portable_truth_replica' "false")" = "true" ]; then
      echo "$host"
    fi
  done < <(fluid_inventory_hosts)
}
