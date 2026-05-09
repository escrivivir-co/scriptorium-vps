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

host="${SCRIPTORIUM_MCP_DOMAIN:-mcp.scriptorium.escrivivir.co}"
endpoint="https://${host}/mcp"
status=0

echo "HEAD https://${host}/healthz"
if ! curl -fsSI --max-time 10 "https://${host}/healthz" >/dev/null; then
  status=1
fi

echo "POST $endpoint without bearer (expect 401/403)"
code=$(curl -k -sS -o /dev/null -w '%{http_code}' --max-time 10 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":"0","method":"tools/list","params":{}}' \
  "$endpoint" || true)
echo "no bearer status: $code"
case "$code" in
  401|403) ;;
  *) status=1 ;;
esac

if [ -n "${MCP_DEVOPS_BEARER_TOKEN:-}" ] && [ "${MCP_DEVOPS_BEARER_TOKEN}" != "CHANGE_ME_TOKEN" ]; then
  echo "POST $endpoint with bearer (expect 200)"
  code=$(curl -k -sS -o /tmp/scriptorium-mcp-tools.json -w '%{http_code}' --max-time 20 \
    -H "Authorization: Bearer ${MCP_DEVOPS_BEARER_TOKEN}" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":"1","method":"tools/list","params":{}}' \
    "$endpoint" || true)
  echo "bearer status: $code"
  [ "$code" = "200" ] || status=1
else
  echo "Bearer real no configurado; se omite prueba autenticada."
fi

exit "$status"
