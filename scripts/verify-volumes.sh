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

if [ "${SCRIPTORIUM_ALLOW_REMOTE_READ:-}" != "YES_READ_VPS" ]; then
  echo "Lectura remota bloqueada. Exporta SCRIPTORIUM_ALLOW_REMOTE_READ=YES_READ_VPS dentro de ventana controlada."
  exit 1
fi

: "${SCRIPTORIUM_SSH_HOST:?SCRIPTORIUM_SSH_HOST no definido}"
: "${SCRIPTORIUM_SSH_USER:?SCRIPTORIUM_SSH_USER no definido}"
SCRIPTORIUM_SSH_PORT="${SCRIPTORIUM_SSH_PORT:-22}"
SCRIPTORIUM_SSH_KEY_PATH="${SCRIPTORIUM_SSH_KEY_PATH:?SCRIPTORIUM_SSH_KEY_PATH no definido}"
SCRIPTORIUM_REMOTE_ROOT="${SCRIPTORIUM_REMOTE_ROOT:-/srv/oasis/scriptorium}"

ssh -i "$SCRIPTORIUM_SSH_KEY_PATH" -p "$SCRIPTORIUM_SSH_PORT" -o StrictHostKeyChecking=accept-new \
  "${SCRIPTORIUM_SSH_USER}@${SCRIPTORIUM_SSH_HOST}" \
  "set -eu; test -d '${SCRIPTORIUM_REMOTE_ROOT}'; find '${SCRIPTORIUM_REMOTE_ROOT}' -maxdepth 4 -printf '%u:%g %m %p\\n' | sort | head -200"
