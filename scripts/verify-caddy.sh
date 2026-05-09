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

hosts=(
  "${SCRIPTORIUM_DOMAIN:-scriptorium.escrivivir.co}"
  "${SCRIPTORIUM_ADMIN_DOMAIN:-admin.scriptorium.escrivivir.co}"
  "${SCRIPTORIUM_MCP_DOMAIN:-mcp.scriptorium.escrivivir.co}"
  "${SCRIPTORIUM_NPM_DOMAIN:-npm.scriptorium.escrivivir.co}"
)

status=0
for host in "${hosts[@]}"; do
  url="https://${host}/healthz"
  echo "HEAD $url"
  if ! curl -fsSI --max-time 10 "$url" >/dev/null; then
    status=1
  fi
done
exit "$status"
