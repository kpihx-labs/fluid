#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/inventory.sh"

project_command="${1:-}"
project_repo="${2:-$PWD}"

[ -n "$project_command" ] || fluid_die "Usage: ./fluid.sh project <validate|render|deploy> <repo>"

project_repo="$(cd "$project_repo" && pwd)"
project_config_path="$project_repo/$FLUID_PROJECT_CONFIG_NAME"
PROJECT_PY_CMD=()

project_python_cmd() {
  if python3 -c 'import yaml' >/dev/null 2>&1; then
    PROJECT_PY_CMD=(python3)
    return 0
  fi

  if /usr/bin/python3 -c 'import yaml' >/dev/null 2>&1; then
    PROJECT_PY_CMD=(/usr/bin/python3)
    return 0
  fi

  if command -v uv >/dev/null 2>&1; then
    PROJECT_PY_CMD=(uv run --quiet --with pyyaml python)
    return 0
  fi

  fluid_die "PyYAML is missing. Install python3-yaml or make 'uv' available."
}

project_require_manager_state() {
  fluid_state_bootstrap
  [ -n "$(fluid_manager_host)" ] || fluid_die "Fluid manager host is unknown. Bootstrap the cluster first."
}

project_manager_docker() {
  if command -v docker >/dev/null 2>&1 && [ "$(docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null || printf 'false')" = "true" ]; then
    docker "$@"
    return 0
  fi

  local manager_host tailscale_name
  manager_host="$(fluid_manager_host)"
  [ -n "$manager_host" ] || fluid_die "Fluid manager host is unknown."
  tailscale_name="$(fluid_host_tailscale_name "$manager_host")"
  [ -n "$tailscale_name" ] || fluid_die "Manager host '$manager_host' has no tailscale_name."
  docker --host "ssh://$tailscale_name" "$@"
}

project_parse() {
  project_python_cmd
  "${PROJECT_PY_CMD[@]}" - "$project_repo" "$project_config_path" <<'PY'
import json
import os
import sys
from pathlib import Path

import yaml

repo = Path(sys.argv[1])
config_path = Path(sys.argv[2])

if not config_path.exists():
    raise SystemExit(f"Missing {config_path.name} in {repo}")

cfg = yaml.safe_load(config_path.read_text()) or {}

def normalize_compose(value):
    if value is None:
        return ["docker-compose.yml"]
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        return value
    if isinstance(value, dict):
        files = value.get("files")
        if isinstance(files, str):
            return [files]
        if isinstance(files, list):
            return files
    raise SystemExit("Invalid compose section in fluid.yml")

compose_files = normalize_compose(cfg.get("compose"))
for rel in compose_files:
    if not (repo / rel).exists():
        raise SystemExit(f"Compose file missing: {rel}")

services = cfg.get("services") or {}
if not services and cfg.get("service"):
    services = {
        cfg["service"]: {
            "replicas": cfg.get("replicas"),
            "constraints": cfg.get("constraints"),
            "preferences": cfg.get("preferences"),
            "deploy": cfg.get("deploy", {}),
        }
    }

if not services:
    raise SystemExit("fluid.yml must define either services: or service:")

stack = cfg.get("stack") or f"{os.environ.get('FLUID_PROJECT_DEFAULT_STACK_PREFIX', 'fluid')}-{repo.name}"

payload = {
    "stack": stack,
    "compose_files": compose_files,
    "services": services,
    "access": cfg.get("access") or {},
    "with_registry_auth": bool((cfg.get("deploy") or {}).get("with_registry_auth", os.environ.get("FLUID_PROJECT_DEPLOY_WITH_REGISTRY_AUTH", "true").lower() == "true")),
}

print(json.dumps(payload))
PY
}

project_render() {
  local meta_json stack render_dir override_path metadata_path
  meta_json="$(project_parse)"
  stack="$(jq -r '.stack' <<<"$meta_json")"
  render_dir="$FLUID_PROJECT_RENDER_DIR/$stack"
  override_path="$render_dir/swarm.override.yml"
  metadata_path="$render_dir/metadata.json"

  fluid_ensure_dir "$render_dir"
  printf '%s\n' "$meta_json" >"$metadata_path"

  project_python_cmd
  "${PROJECT_PY_CMD[@]}" - "$metadata_path" "$override_path" <<'PY'
import json
import sys
from pathlib import Path

import yaml

meta = json.loads(Path(sys.argv[1]).read_text())
override_path = Path(sys.argv[2])

doc = {"version": "3.9", "services": {}}

for service_name, cfg in meta["services"].items():
    cfg = cfg or {}
    deploy = dict(cfg.get("deploy") or {})
    placement = dict(deploy.get("placement") or {})
    service_doc = {}

    constraints = cfg.get("constraints")
    if constraints is not None:
        placement["constraints"] = constraints

    preferences = cfg.get("preferences")
    if preferences is not None:
        placement["preferences"] = preferences

    if placement:
        deploy["placement"] = placement

    for key in ("replicas", "mode", "restart_policy", "resources", "labels", "update_config", "rollback_config"):
      if cfg.get(key) is not None:
        deploy[key] = cfg[key]

    if deploy:
        service_doc["deploy"] = deploy

    service_access = cfg.get("access")
    if service_access is None:
        service_access = meta.get("access") or {}
    if service_access:
        service_doc["x-fluid-access"] = service_access

    if service_doc:
        doc["services"][service_name] = service_doc

override_path.write_text(yaml.safe_dump(doc, sort_keys=False))
PY

  fluid_info "Rendered project metadata: $metadata_path"
  fluid_info "Rendered Swarm override: $override_path"
}

project_validate() {
  local meta_json
  meta_json="$(project_parse)"
  fluid_info "Project config valid for stack '$(jq -r '.stack' <<<"$meta_json")'."
  fluid_info "Compose files: $(jq -r '.compose_files | join(", ")' <<<"$meta_json")"
  fluid_info "Services declared: $(jq -r '.services | keys | join(", ")' <<<"$meta_json")"
}

project_deploy() {
  local meta_json stack render_dir override_path with_registry_auth
  project_require_manager_state
  project_render >/dev/null
  meta_json="$(project_parse)"
  stack="$(jq -r '.stack' <<<"$meta_json")"
  render_dir="$FLUID_PROJECT_RENDER_DIR/$stack"
  override_path="$render_dir/swarm.override.yml"
  with_registry_auth="$(jq -r '.with_registry_auth' <<<"$meta_json")"

  local -a cmd=(stack deploy)
  if [ "$with_registry_auth" = "true" ]; then
    cmd+=(--with-registry-auth)
  fi

  while read -r compose_file; do
    [ -n "$compose_file" ] || continue
    cmd+=(-c "$project_repo/$compose_file")
  done < <(jq -r '.compose_files[]' <<<"$meta_json")
  cmd+=(-c "$override_path" "$stack")

  fluid_run project_manager_docker "${cmd[@]}"
  fluid_info "Deployed stack '$stack'."
}

case "$project_command" in
  validate)
    project_validate
    ;;
  render)
    project_render
    ;;
  deploy)
    project_deploy
    ;;
  *)
    fluid_die "Unknown project command '$project_command'."
    ;;
esac
