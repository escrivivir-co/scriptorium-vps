#!/usr/bin/env bash
# publish-package.sh — Publica un paquete @alephscript/* en el registry Verdaccio
#
# Uso:
#   bash ScriptoriumVps/scripts/publish-package.sh <ruta-al-directorio-del-paquete>
#
# Prerequisitos:
#   - ScriptoriumVps/.env.generated-secrets con VERDACCIO_ADMIN_USER,
#     VERDACCIO_ADMIN_PASSWORD y VERDACCIO_PUBLISHER_EMAIL.
#   - El paquete debe tener dist/ ya compilado (npm run build si no).
#   - El paquete debe ser @alephscript/* en su package.json.
#
# Por qué este script y no npm publish directo:
#   - Verdaccio con max_users:-1 no emite tokens JWT compatibles con _authToken.
#   - Usamos username + _password (solo pass en base64) + email para auth npm.
#   - La web UI de Verdaccio muestra Author/Maintainers desde package.json; no
#     desde el usuario autenticado. El script valida que esos campos existan.
#   - El ~/.npmrc se modifica temporalmente y se restaura al terminar.
#
# Referencia: RUNBOOK.md § Verdaccio — Ops Manual
set -euo pipefail

PKG_DIR="${1:?Uso: $0 <ruta-al-directorio-del-paquete>}"
PKG_DIR=$(cd "$PKG_DIR" && pwd)
PKG_JSON="$PKG_DIR/package.json"
NODE_PKG_JSON="$PKG_JSON"
if command -v cygpath >/dev/null 2>&1; then
  NODE_PKG_JSON=$(cygpath -w "$PKG_JSON")
fi

# ── localizar .env.generated-secrets ─────────────────────────────────────────
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR="$SCRIPT_DIR/.."
SECRETS_FILE="${SCRIPTORIUM_SECRETS_FILE:-$ROOT_DIR/.env.generated-secrets}"

if [ ! -f "$SECRETS_FILE" ]; then
  echo "Falta $SECRETS_FILE con VERDACCIO_ADMIN_USER, VERDACCIO_ADMIN_PASSWORD y VERDACCIO_PUBLISHER_EMAIL."
  exit 1
fi

set -a
# shellcheck disable=SC1090
. <(sed 's/\r//' "$SECRETS_FILE")
set +a

# ── variables requeridas ──────────────────────────────────────────────────────
VUSER="${VERDACCIO_ADMIN_USER:?VERDACCIO_ADMIN_USER no definido en $SECRETS_FILE}"
VPASS="${VERDACCIO_ADMIN_PASSWORD:?VERDACCIO_ADMIN_PASSWORD no definido en $SECRETS_FILE}"
VEMAIL="${VERDACCIO_PUBLISHER_EMAIL:-ops@escrivivir.co}"
REGISTRY="${VERDACCIO_PUBLIC_URL:-https://npm.scriptorium.escrivivir.co}"
REGISTRY_HOST="${REGISTRY#https://}"
REGISTRY_HOST="${REGISTRY_HOST#http://}"

# ── verificar que el paquete es @alephscript/* ────────────────────────────────
PKG_NAME=$(node -e "const fs=require('fs'); const p=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(p.name||'')" "$NODE_PKG_JSON" 2>/dev/null || true)
PKG_VERSION=$(node -e "const fs=require('fs'); const p=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(p.version||'')" "$NODE_PKG_JSON" 2>/dev/null || true)
PKG_AUTHOR=$(node -e "const fs=require('fs'); const p=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(Boolean(p.author))" "$NODE_PKG_JSON" 2>/dev/null || echo false)
PKG_MAINTAINERS=$(node -e "const fs=require('fs'); const p=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(Array.isArray(p.maintainers) && p.maintainers.length > 0)" "$NODE_PKG_JSON" 2>/dev/null || echo false)
if [[ "$PKG_NAME" != @alephscript/* ]]; then
  echo "Advertencia: el paquete '$PKG_NAME' no es @alephscript/*."
  echo "¿Continuar? (Ctrl+C para abortar, Enter para continuar)"
  read -r _
fi
if [[ "$PKG_AUTHOR" != "true" || "$PKG_MAINTAINERS" != "true" ]]; then
  echo "El package.json debe declarar author y maintainers antes de publicar."
  echo "La web UI de Verdaccio muestra esos campos; si faltan, aparecerá 'Anonymous'."
  echo "Para saltar esta validación: SCRIPTORIUM_ALLOW_MISSING_PACKAGE_METADATA=YES"
  if [ "${SCRIPTORIUM_ALLOW_MISSING_PACKAGE_METADATA:-}" != "YES" ]; then
    exit 1
  fi
fi
echo "Publicando $PKG_NAME@$PKG_VERSION → $REGISTRY"

# ── verificar dist/ ───────────────────────────────────────────────────────────
if [ ! -d "$PKG_DIR/dist" ]; then
  echo "No existe $PKG_DIR/dist/. Ejecuta 'npm run build' primero."
  exit 1
fi

# ── auth: username + _password (solo pass) + email ───────────────────────────
# NO usar _authToken con este Verdaccio; max_users:-1 + htpasswd no genera tokens
# compatibles para npm publish. _auth también funciona para autenticar, pero esta
# forma es más explícita y compatible con npm login semantics.
VPASS_B64=$(echo -n "$VPASS" | base64 | tr -d '\n')

NPMRC="$HOME/.npmrc"
BACKUP="${NPMRC}.scriptorium-pub-bak.$$"
[ -f "$NPMRC" ] && cp "$NPMRC" "$BACKUP"

# eliminar entradas previas del registry si las hay y añadir las correctas
{ grep -v "//${REGISTRY_HOST}/" "$NPMRC" 2>/dev/null || true; } > "${NPMRC}.tmp"
cat >> "${NPMRC}.tmp" <<EOF

//${REGISTRY_HOST}/:username=${VUSER}
//${REGISTRY_HOST}/:_password=${VPASS_B64}
//${REGISTRY_HOST}/:email=${VEMAIL}
//${REGISTRY_HOST}/:always-auth=true
EOF
mv "${NPMRC}.tmp" "$NPMRC"

# ── restaurar ~/.npmrc al salir (éxito o error) ───────────────────────────────
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

# ── publish ───────────────────────────────────────────────────────────────────
cd "$PKG_DIR"
npm publish --registry "$REGISTRY"

echo ""
echo "Verificando publicación..."
npm view "$PKG_NAME" --registry "$REGISTRY" 2>/dev/null | grep -E "^$PKG_NAME|dist\." || true
