#!/usr/bin/env bash
# Effective value resolver for Fluid.
#
# Host-scoped values:
#   HOST_<HOST>_<KEY> > <KEY> > effective host config > fallback
#
# Global values:
#   <KEY> > policy JSON > fallback

source "$FLUID_ROOT/scripts/lib/common.sh"

fluid_key_to_env_fragment() {
  printf '%s' "$1" | tr '[:lower:].-' '[:upper:]__'
}

fluid_host_to_env_fragment() {
  printf '%s' "$1" | tr '[:lower:].-' '[:upper:]__'
}

fluid_env_value() {
  local key=$1
  if [ -n "${!key+x}" ]; then
    printf '%s' "${!key}"
  fi
}

fluid_host_env_name() {
  local host=$1
  local key=$2
  printf 'HOST_%s_%s' "$(fluid_host_to_env_fragment "$host")" "$(fluid_key_to_env_fragment "$key")"
}

fluid_json_file_value() {
  local file=$1
  local filter=$2
  [ -f "$file" ] || return 0
  jq -r "$filter" "$file"
}

fluid_effective_global_value() {
  local key=$1
  local policy_file=$2
  local policy_filter=$3
  local fallback=${4:-}
  local global_env policy_value

  global_env="$(fluid_env_value "$key")"
  if [ -n "$global_env" ]; then
    printf '%s' "$global_env"
    return 0
  fi

  if [ -n "$policy_file" ] && [ -n "$policy_filter" ]; then
    policy_value="$(fluid_json_file_value "$policy_file" "$policy_filter")"
    if [ -n "$policy_value" ] && [ "$policy_value" != "null" ]; then
      printf '%s' "$policy_value"
      return 0
    fi
  fi

  printf '%s' "$fallback"
}

fluid_effective_global_bool() {
  local key=$1
  local policy_file=$2
  local policy_filter=$3
  local fallback=${4:-false}
  local value
  value="$(fluid_effective_global_value "$key" "$policy_file" "$policy_filter" "$fallback")"
  case "$value" in
    true|True|TRUE|1|yes|YES|on|ON) echo "true" ;;
    *) echo "false" ;;
  esac
}

fluid_inventory_host_value() {
  local host=$1
  local filter=$2

  if command -v fluid_effective_host_json >/dev/null 2>&1; then
    fluid_effective_host_json "$host" | jq -r "$filter"
  else
    jq -r --arg host "$host" ".hosts[] | select(.name == \$host) | $filter" "$FLUID_HOSTS_PATH"
  fi
}

fluid_effective_host_value() {
  local host=$1
  local key=$2
  local inventory_filter=$3
  local fallback=${4:-}
  local host_env global_env inventory_value

  host_env="$(fluid_host_env_name "$host" "$key")"
  if [ -n "${!host_env+x}" ]; then
    printf '%s' "${!host_env}"
    return 0
  fi

  global_env="$(fluid_env_value "$key")"
  if [ -n "$global_env" ]; then
    printf '%s' "$global_env"
    return 0
  fi

  if [ -n "$inventory_filter" ]; then
    inventory_value="$(fluid_inventory_host_value "$host" "$inventory_filter")"
    if [ -n "$inventory_value" ] && [ "$inventory_value" != "null" ]; then
      printf '%s' "$inventory_value"
      return 0
    fi
  fi

  printf '%s' "$fallback"
}

fluid_effective_host_bool() {
  local host=$1
  local key=$2
  local inventory_filter=$3
  local fallback=${4:-false}
  local value
  value="$(fluid_effective_host_value "$host" "$key" "$inventory_filter" "$fallback")"
  case "$value" in
    true|True|TRUE|1|yes|YES|on|ON) echo "true" ;;
    *) echo "false" ;;
  esac
}
