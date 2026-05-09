#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENV_FILE="${SCRIPTORIUM_ENV_FILE:-$ROOT_DIR/.env}"
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

python - <<'PY'
import os
import socket
import sys

hosts = [
    os.getenv('SCRIPTORIUM_DOMAIN', 'scriptorium.escrivivir.co'),
    os.getenv('SCRIPTORIUM_ADMIN_DOMAIN', 'admin.scriptorium.escrivivir.co'),
    os.getenv('SCRIPTORIUM_MCP_DOMAIN', 'mcp.scriptorium.escrivivir.co'),
    os.getenv('SCRIPTORIUM_NPM_DOMAIN', 'npm.scriptorium.escrivivir.co'),
]
expected = os.getenv('SCRIPTORIUM_EXPECTED_VPS_IP', '').strip()
failed = False
for host in hosts:
    try:
        ips = sorted(set(socket.gethostbyname_ex(host)[2]))
    except Exception as exc:
        print(f'FAIL {host}: {exc}')
        failed = True
        continue
    print(f'{host}: {ips}')
    if expected and expected not in ips:
        print(f'FAIL {host}: expected {expected}')
        failed = True
if failed:
    sys.exit(1)
PY
