#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/inventory.sh"

swarm_command="${1:-status}"
target_host="${2:-$(fluid_local_host_name)}"

swarm_listen_port() {
  printf '%s\n' "${FLUID_SWARM_LISTEN_ADDR##*:}"
}

swarm_target_host() {
  [ -n "$target_host" ] || fluid_die "Could not match this machine to a host entry. Fix fabric/hosts.json first."
  fluid_host_exists "$target_host" || fluid_die "Unknown host '$target_host'."
}

swarm_role_for_host() {
  fluid_host_swarm_role "$1"
}

swarm_local_state() {
  if ! command -v docker >/dev/null 2>&1; then
    printf 'missing\n'
    return 0
  fi
  docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || printf 'inactive\n'
}

swarm_local_is_manager() {
  [ "$(docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null || printf 'false')" = "true" ]
}

swarm_local_advertise_addr() {
  local from_inventory from_local
  from_inventory="$(fluid_host_tailscale_ip "$target_host")"
  if [ -n "$from_inventory" ] && ! printf '%s' "$from_inventory" | grep -q 'x\.x\.x'; then
    printf '%s\n' "$from_inventory"
    return 0
  fi

  from_local="$(fluid_local_tailscale_ip)"
  [ -n "$from_local" ] || fluid_die "Could not determine a local Tailscale IPv4 address for '$target_host'."
  printf '%s\n' "$from_local"
}

swarm_manager_endpoint() {
  local advertise_addr
  advertise_addr="$(fluid_manager_advertise_addr)"
  [ -n "$advertise_addr" ] || fluid_die "Cluster manager advertise address is unknown. Bootstrap a manager first."
  printf '%s:%s\n' "$advertise_addr" "$(swarm_listen_port)"
}

swarm_manager_docker_host() {
  local manager_host tailscale_name
  manager_host="$(fluid_manager_host)"
  [ -n "$manager_host" ] || fluid_die "No manager host is recorded in state."
  tailscale_name="$(fluid_host_tailscale_name "$manager_host")"
  [ -n "$tailscale_name" ] || fluid_die "Manager host '$manager_host' has no tailscale_name."
  printf 'ssh://%s\n' "$tailscale_name"
}

swarm_manager_exec() {
  if swarm_local_is_manager; then
    docker "$@"
    return 0
  fi
  docker --host "$(swarm_manager_docker_host)" "$@"
}

swarm_manager_node_rows() {
  swarm_manager_exec node ls --format '{{.ID}}	{{.Hostname}}	{{.ManagerStatus}}'
}

swarm_find_node_id() {
  local host=$1 candidates candidate row_id row_hostname row_hostname_lower
  candidates="$(fluid_effective_host_json "$host" | jq -r '[.name, (.hostnames // [])[]] | unique[]')"

  while IFS=$'\t' read -r row_id row_hostname _; do
    [ -n "$row_id" ] || continue
    row_hostname_lower="$(printf '%s' "$row_hostname" | tr '[:upper:]' '[:lower:]')"
    while read -r candidate; do
      [ -n "$candidate" ] || continue
      if [ "$row_hostname_lower" = "$(printf '%s' "$candidate" | tr '[:upper:]' '[:lower:]')" ]; then
        printf '%s\n' "$row_id"
        return 0
      fi
    done <<<"$candidates"
  done < <(swarm_manager_node_rows)
}

swarm_find_live_authority_hosts() {
  local hostname host
  while IFS=$'\t' read -r _ hostname manager_status; do
    [ -n "$hostname" ] || continue
    [ -n "$manager_status" ] || continue
    while read -r host; do
      [ -n "$host" ] || continue
      if fluid_effective_host_json "$host" | jq -e --arg hostname "$hostname" '
        [.name, (.hostnames // [])[]] | map(ascii_downcase) | index($hostname | ascii_downcase)
      ' >/dev/null && [ "$(fluid_host_is_authority_candidate "$host")" = "true" ]; then
        printf '%s\n' "$host"
        break
      fi
    done < <(fluid_inventory_hosts)
  done < <(swarm_manager_node_rows)
}

swarm_refresh_authority_from_cluster() {
  local authority_hosts_csv
  if [ "${FLUID_DRY_RUN}" = "true" ]; then
    fluid_info "DRY-RUN: authority refresh skipped."
    return 0
  fi
  authority_hosts_csv="$(swarm_find_live_authority_hosts | paste -sd ',' -)"
  fluid_set_authority "$authority_hosts_csv"
}

swarm_desired_labels_json() {
  local host=$1 role role_label key value base
  role="$(swarm_role_for_host "$host")"
  if [ "$role" = "manager" ]; then
    role_label="$FLUID_SWARM_MANAGER_LABEL"
  else
    role_label="$FLUID_SWARM_WORKER_LABEL"
  fi

  key="${role_label%%=*}"
  value="${role_label#*=}"
  base="$(fluid_host_swarm_labels_json "$host")"
  jq -cn --argjson base "$base" --arg key "$key" --arg value "$value" '$base * {($key): $value}'
}

swarm_sync_one_host_labels() {
  local host=$1 node_id desired current args=() key value
  node_id="$(swarm_find_node_id "$host" || true)"
  [ -n "$node_id" ] || fluid_die "Could not find a Swarm node for host '$host'. Join the host first."

  desired="$(swarm_desired_labels_json "$host")"
  current="$(swarm_manager_exec node inspect "$node_id" --format '{{json .Spec.Labels}}' 2>/dev/null || printf '{}')"

  while read -r key; do
    [ -n "$key" ] || continue
    if ! jq -e --arg key "$key" 'has($key)' <<<"$desired" >/dev/null; then
      args+=(--label-rm "$key")
    fi
  done < <(jq -r 'keys[]?' <<<"$current" | grep '^fluid\.' || true)

  while IFS=$'\t' read -r key value; do
    [ -n "$key" ] || continue
    args+=(--label-add "$key=$value")
  done < <(jq -r 'to_entries[] | "\(.key)\t\(.value)"' <<<"$desired")

  if [ "${#args[@]}" -eq 0 ]; then
    fluid_info "No label change needed for '$host'."
    return 0
  fi

  fluid_run swarm_manager_exec node update "${args[@]}" "$node_id"
}

swarm_sync_labels() {
  local host=${1:-}
  if [ "${FLUID_DRY_RUN}" = "true" ]; then
    fluid_info "DRY-RUN: label sync skipped${host:+ for $host}."
    return 0
  fi

  if [ -n "$host" ]; then
    swarm_sync_one_host_labels "$host"
    swarm_refresh_authority_from_cluster
    return 0
  fi

  while read -r host; do
    [ -n "$host" ] || continue
    if swarm_find_node_id "$host" >/dev/null 2>&1; then
      swarm_sync_one_host_labels "$host"
    fi
  done < <(fluid_inventory_hosts)
  swarm_refresh_authority_from_cluster
}

swarm_bootstrap_local_manager() {
  local advertise_addr manager_token worker_token local_state
  swarm_target_host
  [ "$(swarm_role_for_host "$target_host")" = "manager" ] || fluid_die "Host '$target_host' is not configured as a Swarm manager."
  [ "$(fluid_host_is_authority_candidate "$target_host")" = "true" ] || fluid_die "Host '$target_host' cannot bootstrap authority under the current policy."

  advertise_addr="$(swarm_local_advertise_addr)"
  local_state="$(swarm_local_state)"

  if [ "$local_state" = "active" ]; then
    fluid_info "Swarm is already active on '$target_host'. Reusing the local cluster state."
  else
    fluid_run_privileged "Initialize the Fluid Swarm cluster" \
      docker swarm init \
      --advertise-addr "$advertise_addr" \
      --listen-addr "$FLUID_SWARM_LISTEN_ADDR" \
      --data-path-port "$FLUID_SWARM_OVERLAY_PORT"
  fi

  if [ "${FLUID_DRY_RUN}" = "true" ]; then
    manager_token="DRYRUN_MANAGER_TOKEN"
    worker_token="DRYRUN_WORKER_TOKEN"
  else
    manager_token="$(docker swarm join-token -q manager)"
    worker_token="$(docker swarm join-token -q worker)"
  fi

  fluid_set_cluster_runtime "$target_host" "$advertise_addr" "$manager_token" "$worker_token"
  fluid_add_authority_host "$target_host"
  fluid_clear_retired "$target_host"
  swarm_sync_labels "$target_host"
  swarm_refresh_authority_from_cluster

  fluid_info "Fluid Swarm bootstrap completed on '$target_host'."
}

swarm_join_local_host() {
  local desired_role local_state join_token
  swarm_target_host
  desired_role="$(swarm_role_for_host "$target_host")"
  [ "$desired_role" != "none" ] || fluid_die "Host '$target_host' is not execution-capable in the current configuration."

  local_state="$(swarm_local_state)"
  if [ "$local_state" = "active" ]; then
    fluid_info "Swarm is already active on '$target_host'."
    if [ "$desired_role" = "manager" ] && ! swarm_local_is_manager; then
      fluid_warn "This node is active as a worker but should be a manager. Run './fluid.sh promote $target_host' from a manager."
    elif [ "$desired_role" = "worker" ] && swarm_local_is_manager; then
      fluid_warn "This node is active as a manager but is configured as a worker. Run './fluid.sh demote $target_host' from a manager."
    fi
    swarm_sync_labels "$target_host"
    return 0
  fi

  case "$desired_role" in
    manager) join_token="$(jq -r '.manager_join_token // empty' "$FLUID_STATE_PATH")" ;;
    worker) join_token="$(jq -r '.worker_join_token // empty' "$FLUID_STATE_PATH")" ;;
    *) fluid_die "Unsupported Swarm role '$desired_role'." ;;
  esac

  [ -n "$join_token" ] || fluid_die "Missing Swarm join token for role '$desired_role'. Bootstrap the cluster first."
  fluid_run_privileged "Join the Fluid Swarm cluster as $desired_role" \
    docker swarm join \
    --token "$join_token" \
    "$(swarm_manager_endpoint)"

  if [ "$desired_role" = "manager" ] && [ "$(fluid_host_is_authority_candidate "$target_host")" = "true" ]; then
    fluid_add_authority_host "$target_host"
  fi
  fluid_clear_retired "$target_host"
  swarm_sync_labels "$target_host"
  fluid_info "Host '$target_host' joined Fluid as a $desired_role."
}

swarm_promote_host() {
  local host=$1 node_id
  fluid_host_exists "$host" || fluid_die "Unknown host '$host'."
  [ "$(fluid_host_role "$host")" = "manager" ] || fluid_die "Host '$host' is not declared as role=manager in fabric."
  if [ "${FLUID_DRY_RUN}" = "true" ]; then
    fluid_add_authority_host "$host"
    fluid_info "DRY-RUN: host '$host' would be promoted to manager."
    return 0
  fi
  node_id="$(swarm_find_node_id "$host" || true)"
  [ -n "$node_id" ] || fluid_die "Host '$host' is not present in the Swarm cluster."
  fluid_run swarm_manager_exec node promote "$node_id"
  if [ "$(fluid_host_is_authority_candidate "$host")" = "true" ]; then
    fluid_add_authority_host "$host"
  fi
  swarm_sync_labels "$host"
  swarm_refresh_authority_from_cluster
}

swarm_demote_host() {
  local host=$1 node_id
  fluid_host_exists "$host" || fluid_die "Unknown host '$host'."
  if [ "${FLUID_DRY_RUN}" = "true" ]; then
    fluid_remove_authority_host "$host"
    fluid_info "DRY-RUN: host '$host' would be demoted to worker."
    return 0
  fi
  node_id="$(swarm_find_node_id "$host" || true)"
  [ -n "$node_id" ] || fluid_die "Host '$host' is not present in the Swarm cluster."
  fluid_run swarm_manager_exec node demote "$node_id"
  fluid_remove_authority_host "$host"
  swarm_sync_labels "$host"
  swarm_refresh_authority_from_cluster
}

swarm_retire_host() {
  local host=$1 node_id
  fluid_host_exists "$host" || fluid_die "Unknown host '$host'."
  fluid_mark_retired "$host"
  fluid_remove_authority_host "$host"

  if [ "${FLUID_DRY_RUN}" = "true" ]; then
    fluid_info "DRY-RUN: host '$host' would be retired from the cluster."
    return 0
  fi

  if [ "$host" = "$target_host" ] && [ "$(swarm_local_state)" = "active" ]; then
    fluid_run_privileged "Leave the Fluid Swarm cluster" docker swarm leave --force
  fi

  node_id="$(swarm_find_node_id "$host" || true)"
  if [ -n "$node_id" ]; then
    fluid_run swarm_manager_exec node rm --force "$node_id"
  fi

  swarm_refresh_authority_from_cluster
}

swarm_status() {
  local authority_csv manager_host advertise_addr local_state desired_role
  swarm_target_host
  local_state="$(swarm_local_state)"
  desired_role="$(swarm_role_for_host "$target_host")"
  manager_host="$(fluid_manager_host)"
  advertise_addr="$(fluid_manager_advertise_addr)"
  authority_csv="$(fluid_authority_set | paste -sd ',' -)"

  fluid_info "Host: $target_host"
  fluid_info "Desired role: $desired_role"
  fluid_info "Local node state: $local_state"
  fluid_info "Local control plane: $(swarm_local_is_manager && echo manager || echo worker-or-none)"
  fluid_info "Manager host: ${manager_host:-none}"
  fluid_info "Manager advertise addr: ${advertise_addr:-none}"
  fluid_info "Authority set: ${authority_csv:-none}"
}

case "$swarm_command" in
  bootstrap) swarm_bootstrap_local_manager ;;
  join) swarm_join_local_host ;;
  promote) swarm_promote_host "$target_host" ;;
  demote) swarm_demote_host "$target_host" ;;
  retire) swarm_retire_host "$target_host" ;;
  sync-labels) swarm_sync_labels "${target_host:-}" ;;
  status) swarm_status ;;
  *)
    fluid_die "Unknown swarm command '$swarm_command'."
    ;;
esac
