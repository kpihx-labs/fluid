#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


BEGIN = "// BEGIN FLUID MANAGED ACLS"
END = "// END FLUID MANAGED ACLS"


def request_json(url: str, api_key: str, method: str = "GET", payload: dict | None = None) -> dict:
    data = None
    headers = {
        "Authorization": "Basic " + base64.b64encode(f"{api_key}:".encode()).decode(),
        "Accept": "application/json",
    }
    if payload is not None:
        data = json.dumps(payload).encode()
        headers["Content-Type"] = "application/json"

    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read().decode()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        body = exc.read().decode()
        raise SystemExit(f"Tailscale API {method} {url} failed: {exc.code} {body}") from exc


def extract_policy_hujson(payload: dict) -> str:
    for key in ("acl", "acl_hujson", "policy", "hujson"):
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            return value
    raise SystemExit("Could not find the current tailnet policy body in the Tailscale API response.")


def splice_policy(current: str, managed_block: str) -> str:
    if BEGIN in current and END in current:
      before = current.split(BEGIN, 1)[0]
      after = current.split(END, 1)[1]
      return before.rstrip() + "\n" + managed_block.rstrip() + "\n" + after.lstrip()
    return current.rstrip() + "\n\n" + managed_block.rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tailnet", required=True)
    parser.add_argument("--api-key", required=True)
    parser.add_argument("--managed-block", required=True)
    args = parser.parse_args()

    managed_block = Path(args.managed_block).read_text()
    tailnet = urllib.parse.quote(args.tailnet, safe="")
    base = f"https://api.tailscale.com/api/v2/tailnet/{tailnet}/acl"

    current_payload = request_json(base, args.api_key)
    current_hujson = extract_policy_hujson(current_payload)
    patched = splice_policy(current_hujson, managed_block)

    request_json(base + "/validate", args.api_key, method="POST", payload={"acl": patched})
    request_json(base, args.api_key, method="POST", payload={"acl": patched})
    sys.stdout.write("Applied Fluid-managed Tailscale policy block.\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
