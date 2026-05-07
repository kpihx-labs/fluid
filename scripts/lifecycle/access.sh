#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/inventory.sh"

access_command="${1:-}"
access_target="${2:-}"
[ -n "$access_command" ] || fluid_die "Usage: ./fluid.sh access <validate|render|apply> [tailscale]"

access_validate() {
  jq -e '
    .version != null
    and (.principals | type == "object")
    and (.defaults | type == "object")
    and (.layers | type == "object")
  ' "$FLUID_ACCESS_POLICY_PATH" >/dev/null || fluid_die "Invalid access policy at $FLUID_ACCESS_POLICY_PATH."
  fluid_info "Access policy is valid."
}

access_render_matrix() {
  local matrix_path markdown_path
  matrix_path="$FLUID_ACCESS_RENDER_DIR/access-matrix.json"
  markdown_path="$FLUID_ACCESS_RENDER_DIR/ACCESS.md"

  fluid_ensure_dir "$FLUID_ACCESS_RENDER_DIR"

  jq -n \
    --slurpfile policy "$FLUID_ACCESS_POLICY_PATH" \
    --slurpfile hosts "$FLUID_HOSTS_PATH" \
    '
    {
      version: 2,
      policy: $policy[0],
      hosts: [
        $hosts[0].hosts[] | {
          name,
          profile,
          elevated: (.elevated // false),
          tailscale_name: (.network.tailscale_name // null),
          tailscale_ip: (.network.tailscale_ip // null)
        }
      ]
    }
  ' >"$matrix_path"

  {
    printf '# Fluid Access\n\n'
    printf 'Generated from `fabric/policies/access.json` and `fabric/hosts.json`.\n\n'
    printf '## Layers\n\n'
    jq -r '.layers | to_entries[] | "- `" + .key + "`: " + .value' "$FLUID_ACCESS_POLICY_PATH"
    printf '\n## Default actions\n\n'
    jq -r '
      .defaults
      | to_entries[]
      | "- `" + .key + "`: " + (.value | join(", "))
    ' "$FLUID_ACCESS_POLICY_PATH"
    printf '\n## Hosts\n\n'
    printf '| Host | Profile | Elevated | Tailscale |\n'
    printf '| :--- | :--- | :--- | :--- |\n'
    jq -r '
      .hosts[]
      | "| " + .name + " | " + .profile + " | " + (.elevated|tostring) + " | " + ((.tailscale_name // .tailscale_ip // "-")) + " |"
    ' "$matrix_path"
  } >"$markdown_path"

  fluid_info "Rendered access matrix: $matrix_path"
  fluid_info "Rendered access summary: $markdown_path"
}

access_render_tailscale_acl() {
  local acl_path
  acl_path="$FLUID_ACCESS_RENDER_DIR/tailscale-managed-acl.hujson"
  fluid_ensure_dir "$FLUID_ACCESS_RENDER_DIR"

  python3 - "$FLUID_HOSTS_PATH" "$FLUID_ACCESS_POLICY_PATH" "$acl_path" "$FLUID_STATE_PATH" <<'PY'
import json
import sys
from pathlib import Path

hosts = json.loads(Path(sys.argv[1]).read_text())["hosts"]
policy = json.loads(Path(sys.argv[2]).read_text())
output = Path(sys.argv[3])
state = json.loads(Path(sys.argv[4]).read_text())
authority = set(state.get("authority_set") or [])

def host_targets(selector: str):
    if selector == "fluid:all:*":
        out = []
        for host in hosts:
            ip = host.get("network", {}).get("tailscale_ip")
            if ip and "x" not in ip:
                out.append(f"{ip}:*")
        return out

    if selector.startswith("fluid:authority:"):
        port = selector.split(":")[-1]
        out = []
        for host in hosts:
            if host.get("name") not in authority:
                continue
            ip = host.get("network", {}).get("tailscale_ip")
            if ip and "x" not in ip:
                out.append(f"{ip}:{port}")
        return out

    return [selector]

lines = []
lines.append("// BEGIN FLUID MANAGED ACLS")
for rule in policy.get("tailscale", {}).get("managed_rules", []):
    dst = []
    for item in rule.get("dst", []):
        dst.extend(host_targets(item))
    if not dst:
        continue
    lines.append("\t\t// " + rule.get("comment", "Fluid managed rule"))
    lines.append("\t\t{")
    lines.append(f'\t\t\t"action": "{rule["action"]}",')
    if "proto" in rule:
        lines.append(f'\t\t\t"proto":  "{rule["proto"]}",')
    src_json = json.dumps(rule.get("src", []))
    dst_json = json.dumps(dst)
    lines.append(f'\t\t\t"src":    {src_json},')
    lines.append(f'\t\t\t"dst":    {dst_json},')
    lines.append("\t\t},")
lines.append("// END FLUID MANAGED ACLS")
output.write_text("\n".join(lines) + "\n")
print(output)
PY

  fluid_info "Rendered managed Tailscale ACL block: $acl_path"
}

access_apply_tailscale() {
  local managed_path
  managed_path="$FLUID_ACCESS_RENDER_DIR/tailscale-managed-acl.hujson"
  access_validate >/dev/null
  access_render_tailscale_acl >/dev/null

  if [ -z "$FLUID_TAILSCALE_TAILNET" ] || [ -z "$FLUID_TAILSCALE_API_KEY" ]; then
    fluid_die "Set FLUID_TAILSCALE_TAILNET and FLUID_TAILSCALE_API_KEY, or apply $managed_path manually using docs/architecture/tailscale-access.md."
  fi

  python3 "$ROOT_DIR/adapters/access/tailscale/apply.py" \
    --tailnet "$FLUID_TAILSCALE_TAILNET" \
    --api-key "$FLUID_TAILSCALE_API_KEY" \
    --managed-block "$managed_path"
}

access_render() {
  access_validate >/dev/null
  access_render_matrix
  access_render_tailscale_acl
}

case "$access_command" in
  validate) access_validate ;;
  render) access_render ;;
  apply)
    case "$access_target" in
      tailscale) access_apply_tailscale ;;
      *) fluid_die "Usage: ./fluid.sh access apply tailscale" ;;
    esac
    ;;
  *) fluid_die "Unknown access command '$access_command'." ;;
esac
