#!/usr/bin/env bash
# setup-volumenes.sh — Inicializar layout de volúmenes compartidos en el VPS
#
# Uso: sudo bash setup-volumenes.sh
#   (ejecutar como root o con sudo en el VPS de destino)
#
# Variables de entorno (con defaults seguros).
# Nombres canónicos decididos en RESPUESTAS.md:
SCRIPTORIUM_UID=${SCRIPTORIUM_UID:-1000}
SCRIPTORIUM_GID=${SCRIPTORIUM_GID:-1000}
SCRIPTORIUM_REMOTE_ROOT=${SCRIPTORIUM_REMOTE_ROOT:-/srv/oasis/scriptorium}

set -euo pipefail

echo "==> Creando layout en ${SCRIPTORIUM_REMOTE_ROOT} (UID=${SCRIPTORIUM_UID} GID=${SCRIPTORIUM_GID})"

# ── ARCHIVO — raíz + DISCO ────────────────────────────────────────────────────
install -d -m 755 \
  "${SCRIPTORIUM_REMOTE_ROOT}/ARCHIVO" \
  "${SCRIPTORIUM_REMOTE_ROOT}/ARCHIVO/DISCO"

touch "${SCRIPTORIUM_REMOTE_ROOT}/ARCHIVO/.gitkeep"
touch "${SCRIPTORIUM_REMOTE_ROOT}/ARCHIVO/DISCO/.gitkeep"

# ── ARCHIVO/PLUGINS — paths requeridos por mounts de stacks diseñados ─────────
# Creados con UID:GID correcto ANTES del primer `docker compose up`,
# para evitar que Docker los cree como root.
install -d -m 755 \
  "${SCRIPTORIUM_REMOTE_ROOT}/ARCHIVO/PLUGINS" \
  "${SCRIPTORIUM_REMOTE_ROOT}/ARCHIVO/PLUGINS/MCP_DATA" \
  "${SCRIPTORIUM_REMOTE_ROOT}/ARCHIVO/PLUGINS/MCP_DATA/devops-mcp-server"

install -d -m 755 \
  "${SCRIPTORIUM_REMOTE_ROOT}/ARCHIVO/PLUGINS/SCRIPTORIUM_VPS" \
  "${SCRIPTORIUM_REMOTE_ROOT}/ARCHIVO/PLUGINS/SCRIPTORIUM_VPS/audit" \
  "${SCRIPTORIUM_REMOTE_ROOT}/ARCHIVO/PLUGINS/SCRIPTORIUM_VPS/deployments" \
  "${SCRIPTORIUM_REMOTE_ROOT}/ARCHIVO/PLUGINS/SCRIPTORIUM_VPS/secrets-templates" \
  "${SCRIPTORIUM_REMOTE_ROOT}/ARCHIVO/PLUGINS/SCRIPTORIUM_VPS/node-red-projects"

# ── Verdaccio ─────────────────────────────────────────────────────────────────
# IMPORTANTE: el proceso Verdaccio dentro del contenedor corre como uid=10001 gid=65533
# (definido en la imagen oficial verdaccio/verdaccio, no configurable por env).
# El directorio storage/ requiere ser accesible por ese UID, NO por SCRIPTORIUM_UID.
# El directorio conf/ solo necesita lectura (montado :ro), 755 es suficiente.
VERDACCIO_UID=10001
VERDACCIO_GID=65533

install -d -m 755 \
  "${SCRIPTORIUM_REMOTE_ROOT}/verdaccio" \
  "${SCRIPTORIUM_REMOTE_ROOT}/verdaccio/storage" \
  "${SCRIPTORIUM_REMOTE_ROOT}/verdaccio/conf"

# ── Caddy ─────────────────────────────────────────────────────────────────────
install -d -m 755 \
  "${SCRIPTORIUM_REMOTE_ROOT}/caddy" \
  "${SCRIPTORIUM_REMOTE_ROOT}/caddy/data" \
  "${SCRIPTORIUM_REMOTE_ROOT}/caddy/config"

# ── Node-RED — data node (NO es el monorepo de projects) ─────────────────────
# Node-RED usa projectsDir=/data/projects dentro del container.
# El monorepo `ScriptoriumVps/node-red-projects/` se monta como volumen bind
# desde el repo clonado, no desde este árbol de ${SCRIPTORIUM_REMOTE_ROOT}/.
install -d -m 755 \
  "${SCRIPTORIUM_REMOTE_ROOT}/node-red" \
  "${SCRIPTORIUM_REMOTE_ROOT}/node-red/data"

# ── Aplicar ownership UID:GID ─────────────────────────────────────────────────
# Ownership general: SCRIPTORIUM_UID:SCRIPTORIUM_GID para Node-RED, MCP, ARCHIVO…
chown -R "${SCRIPTORIUM_UID}:${SCRIPTORIUM_GID}" "${SCRIPTORIUM_REMOTE_ROOT}"

# Verdaccio storage: sobreescribir con el UID:GID real del proceso en el contenedor.
# El proceso corre como verdaccio (10001:65533) independientemente de SCRIPTORIUM_UID.
# Sin este paso, Verdaccio no puede escribir htpasswd ni tarballs → EACCES.
chown -R "${VERDACCIO_UID}:${VERDACCIO_GID}" "${SCRIPTORIUM_REMOTE_ROOT}/verdaccio/storage"

echo "==> Layout creado:"
find "${SCRIPTORIUM_REMOTE_ROOT}" -maxdepth 5 | sort

echo ""
echo "==> OK. Owners finales:"
echo "    ${SCRIPTORIUM_REMOTE_ROOT}/ (excepto verdaccio/storage): ${SCRIPTORIUM_UID}:${SCRIPTORIUM_GID}"
echo "    ${SCRIPTORIUM_REMOTE_ROOT}/verdaccio/storage: ${VERDACCIO_UID}:${VERDACCIO_GID} (proceso verdaccio en contenedor)"
echo "    Referencia: docker-compose.yml → user: \"\${SCRIPTORIUM_UID}:\${SCRIPTORIUM_GID}\""
echo "    NOTA: node-red-projects/ se monta desde el repo clonado, no desde ${SCRIPTORIUM_REMOTE_ROOT}/."
