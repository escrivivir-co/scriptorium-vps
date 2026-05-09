#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
else
  echo "WARN: falta $ENV_FILE; uso defaults públicos para checks de red."
fi

scripts=(
  verify-dns.sh
  verify-caddy.sh
  verify-nodered.sh
  verify-mcp-devops.sh
  verify-verdaccio.sh
)

status=0
for script in "${scripts[@]}"; do
  echo "==> $script"
  if ! bash "$ROOT_DIR/scripts/$script"; then
    status=1
  fi
done

if [ "${SCRIPTORIUM_ALLOW_REMOTE_READ:-}" = "YES_READ_VPS" ]; then
  echo "==> verify-volumes.sh"
  if ! bash "$ROOT_DIR/scripts/verify-volumes.sh"; then
    status=1
  fi
else
  echo "==> verify-volumes.sh omitido: requiere SCRIPTORIUM_ALLOW_REMOTE_READ=YES_READ_VPS"
fi

exit "$status"
