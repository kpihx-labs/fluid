#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"

mode="${1:-user}"
shift || true

case "$mode" in
  user|--user)
    target_dir="${FLUID_LINK_DIR:-$HOME/.local/bin}"
    target_bin="$target_dir/fluid"
    mkdir -p "$target_dir"
    cat >"$target_bin" <<EOF
#!/usr/bin/env bash
exec "$ROOT_DIR/fluid.sh" "\$@"
EOF
    chmod +x "$target_bin"
    fluid_info "Installed link: $target_bin -> $ROOT_DIR/fluid.sh"
    if [[ ":$PATH:" != *":$target_dir:"* ]]; then
      fluid_warn "Directory not in PATH: $target_dir"
      fluid_warn "Add this to your shell profile:"
      fluid_warn "  export PATH=\"$target_dir:\$PATH\""
    fi
    ;;
  global|--global)
    target_bin="/usr/local/bin/fluid"
    fluid_require_cmd sudo
    tmp_file="$(mktemp)"
    cat >"$tmp_file" <<EOF
#!/usr/bin/env bash
exec "$ROOT_DIR/fluid.sh" "\$@"
EOF
    chmod +x "$tmp_file"
    sudo install -m 755 "$tmp_file" "$target_bin"
    rm -f "$tmp_file"
    fluid_info "Installed global link: $target_bin -> $ROOT_DIR/fluid.sh"
    ;;
  *)
    fluid_die "Usage: ./fluid.sh link [user|global]"
    ;;
esac
