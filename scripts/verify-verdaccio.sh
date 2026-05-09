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

registry="${VERDACCIO_PUBLIC_URL:-https://npm.scriptorium.escrivivir.co}"
status=0

echo "HEAD ${registry}/-/ping"
if ! curl -fsSI --max-time 10 "${registry}/-/ping" >/dev/null; then
  status=1
fi

if command -v npm >/dev/null 2>&1; then
  echo "npm ping --registry ${registry}/"
  if ! npm ping --registry "${registry}/" --fetch-timeout=10000; then
    status=1
  fi
else
  echo "npm no disponible; se omite npm ping."
fi

exit "$status"
