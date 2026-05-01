#!/usr/bin/env bash

fluid_tailscale_status() {
  if [ "$(fluid_underlay_type)" != "tailscale" ]; then
    echo "not-applicable"
    return 0
  fi

  if ! command -v tailscale >/dev/null 2>&1; then
    echo "missing"
    return 0
  fi

  if eval "$(fluid_tailscale_status_cmd)" >/dev/null 2>&1; then
    echo "connected"
  else
    echo "degraded"
  fi
}
