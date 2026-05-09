#!/usr/bin/env bash
# unpublish-package.sh — Elimina un paquete (o versión) del registry Verdaccio
#
# Uso:
#   bash ScriptoriumVps/scripts/unpublish-package.sh <nombre-paquete> [<versión>]
#
#   Sin versión → elimina el paquete completo (todas las versiones).
#   Con versión → elimina solo esa versión (npm unpublish pkg@ver).
#
# Prerequisitos:
#   - ScriptoriumVps/.env.generated-secrets con VERDACCIO_ADMIN_USER,
#     VERDACCIO_ADMIN_PASSWORD y VERDACCIO_PUBLISHER_EMAIL.
#
# Referencia: RUNBOOK.md § Verdaccio — Ops Manual
set -euo pipefail

PKG_NAME="${1:?Uso: $0 <nombre-paquete> [<versión>]}"
PKG_VERSION="${2:-}"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR="$SCRIPT_DIR/.."
SECRETS_FILE="${SCRIPTORIUM_SECRETS_FILE:-$ROOT_DIR/.env.generated-secrets}"

if [ ! -f "$SECRETS_FILE" ]; then
  echo "Falta $SECRETS_FILE con VERDACCIO_ADMIN_USER y VERDACCIO_ADMIN_PASSWORD."
  exit 1
fi

set -a
# shellcheck disable=SC1090
. <(sed 's/\r//' "$SECRETS_FILE")
set +a

VUSER="${VERDACCIO_ADMIN_USER:?VERDACCIO_ADMIN_USER no definido}"
VPASS="${VERDACCIO_ADMIN_PASSWORD:?VERDACCIO_ADMIN_PASSWORD no definido}"
VEMAIL="${VERDACCIO_PUBLISHER_EMAIL:-ops@escrivivir.co}"
REGISTRY="${VERDACCIO_PUBLIC_URL:-https://npm.scriptorium.escrivivir.co}"
REGISTRY_HOST="${REGISTRY#https://}"
REGISTRY_HOST="${REGISTRY_HOST#http://}"

if [ -n "$PKG_VERSION" ]; then
  TARGET="${PKG_NAME}@${PKG_VERSION}"
else
  TARGET="$PKG_NAME"
fi

echo "Eliminando ${TARGET} de ${REGISTRY}"

# ── auth temporal en ~/.npmrc ─────────────────────────────────────────────────
VPASS_B64=$(echo -n "$VPASS" | base64 | tr -d '\n')
NPMRC="$HOME/.npmrc"
BACKUP="${NPMRC}.scriptorium-unpub-bak.$$"
[ -f "$NPMRC" ] && cp "$NPMRC" "$BACKUP"

{ grep -v "//${REGISTRY_HOST}/" "$NPMRC" 2>/dev/null || true; } > "${NPMRC}.tmp"
cat >> "${NPMRC}.tmp" <<EOF

//${REGISTRY_HOST}/:username=${VUSER}
//${REGISTRY_HOST}/:_password=${VPASS_B64}
//${REGISTRY_HOST}/:email=${VEMAIL}
//${REGISTRY_HOST}/:always-auth=true
EOF
mv "${NPMRC}.tmp" "$NPMRC"

restore_npmrc() {
  if [ -f "$BACKUP" ]; then
    mv "$BACKUP" "$NPMRC"
  else
    { grep -v "//${REGISTRY_HOST}/" "$NPMRC" 2>/dev/null || true; } > "${NPMRC}.tmp"
    mv "${NPMRC}.tmp" "$NPMRC"
  fi
  echo "~/.npmrc restaurado."
}
trap restore_npmrc EXIT

# ── unpublish ─────────────────────────────────────────────────────────────────
npm unpublish "$TARGET" --registry "$REGISTRY" --force

echo "Eliminado: ${TARGET}"
