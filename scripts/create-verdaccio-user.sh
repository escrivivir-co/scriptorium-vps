#!/usr/bin/env bash
# create-verdaccio-user.sh — Crea un usuario en el htpasswd de Verdaccio (VPS)
# Ejecutar desde dentro del VPS dentro de ventana controlada.
# Idempotente: si el usuario ya existe no hace nada.
#
# Uso:
#   bash scripts/create-verdaccio-user.sh [<usuario> <password>]
#
# Si no se pasan argumentos, lee VERDACCIO_ADMIN_USER / VERDACCIO_ADMIN_PASSWORD del .env.
# El hash se genera dentro del contenedor Verdaccio (openssl APR1-MD5), nunca sale en claro.
#
# Requiere:
#   - Estar en el VPS con Docker accesible.
#   - Candado: export SCRIPTORIUM_DEPLOY_CONFIRM=YES_DEPLOY_SCRIPTORIUM_VPS
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENV_FILE="${SCRIPTORIUM_ENV_FILE:-$ROOT_DIR/.env}"

if [ -f "$ENV_FILE" ]; then
  pre_confirm="${SCRIPTORIUM_DEPLOY_CONFIRM:-}"
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
  [ -n "$pre_confirm" ] && SCRIPTORIUM_DEPLOY_CONFIRM="$pre_confirm"
fi

# --- candado mutante ---
if [ "${SCRIPTORIUM_DEPLOY_CONFIRM:-}" != "YES_DEPLOY_SCRIPTORIUM_VPS" ]; then
  echo "Operación mutante bloqueada. Falta: export SCRIPTORIUM_DEPLOY_CONFIRM=YES_DEPLOY_SCRIPTORIUM_VPS"
  exit 1
fi

# --- parámetros ---
VUSER="${1:-${VERDACCIO_ADMIN_USER:?VERDACCIO_ADMIN_USER no definido}}"
VPASS="${2:-${VERDACCIO_ADMIN_PASSWORD:?VERDACCIO_ADMIN_PASSWORD no definido}}"

CONTAINER="${VERDACCIO_CONTAINER:-scriptorium-vps-verdaccio-1}"
HTPASSWD="${VERDACCIO_HTPASSWD_PATH:-/srv/oasis/scriptorium/verdaccio/storage/htpasswd}"

# --- comprobar que el contenedor está corriendo ---
if ! docker inspect "$CONTAINER" --format '{{.State.Status}}' 2>/dev/null | grep -q "running"; then
  echo "El contenedor $CONTAINER no está corriendo."
  exit 1
fi

# --- idempotencia ---
if [ -f "$HTPASSWD" ] && grep -q "^${VUSER}:" "$HTPASSWD" 2>/dev/null; then
  echo "Usuario '${VUSER}' ya existe en $HTPASSWD. No se modifica."
else
  # --- generar hash APR1 dentro del contenedor (no expone password en proceso local) ---
  HASH=$(docker exec "$CONTAINER" openssl passwd -apr1 "$VPASS")

  # --- asegurar que el directorio existe ---
  mkdir -p "$(dirname "$HTPASSWD")"

  # --- escribir entrada ---
  echo "${VUSER}:${HASH}" >> "$HTPASSWD"

  echo "Usuario '${VUSER}' creado en $HTPASSWD."
  echo "Entradas totales: $(wc -l < "$HTPASSWD")"
fi

# --- corregir permisos del storage para el proceso Verdaccio (uid=10001 gid=65533) ---
# El proceso Verdaccio corre como uid=10001, no como el usuario que crea los directorios.
# Se aplica siempre (idempotente y necesario tras cualquier operación sobre el storage).
SUDO=""
if command -v sudo >/dev/null 2>&1 && [ "$(id -u)" != "0" ]; then SUDO="sudo"; fi
$SUDO chown -R 10001:65533 "$(dirname "$HTPASSWD")"
echo "Permisos storage ajustados a 10001:65533."

# --- verificación rápida ---
# Nota: la API de registro (PUT /-/user/...) devuelve 409 aunque las credenciales sean
# correctas, porque max_users: -1 bloquea registros nuevos vía API una vez creados
# por htpasswd. La verificación real es un ping autenticado con basic auth.
echo ""
echo "Verificando credenciales contra el registry..."
REGISTRY="${VERDACCIO_PUBLIC_URL:-https://npm.scriptorium.escrivivir.co}"
AUTH_B64=$(echo -n "${VUSER}:${VPASS}" | base64 | tr -d '\n')
HTTP_STATUS=$(curl -sS -o /dev/null -w "%{http_code}" \
  -H "Authorization: Basic ${AUTH_B64}" \
  "${REGISTRY}/-/user/org.couchdb.user:${VUSER}")
echo "HTTP status autenticado: $HTTP_STATUS"
if [[ "$HTTP_STATUS" == "200" || "$HTTP_STATUS" == "201" ]]; then
  echo "Credenciales verificadas OK."
else
  echo "Advertencia: el ping autenticado devolvió $HTTP_STATUS."
  echo "Si el usuario acaba de crearse y el registry aún no ha recargado, reintenta en 5s."
fi
