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
chown -R "${SCRIPTORIUM_UID}:${SCRIPTORIUM_GID}" "${SCRIPTORIUM_REMOTE_ROOT}"

echo "==> Layout creado:"
find "${SCRIPTORIUM_REMOTE_ROOT}" -maxdepth 5 | sort

echo ""
echo "==> OK. Verifica que UID:GID del proceso nodered/verdaccio/caddy coincide con ${SCRIPTORIUM_UID}:${SCRIPTORIUM_GID}."
echo "    Referencia: docker-compose.yml → user: \"\${SCRIPTORIUM_UID}:\${SCRIPTORIUM_GID}\""
echo "    NOTA: node-red-projects/ se monta desde el repo clonado, no desde ${SCRIPTORIUM_REMOTE_ROOT}/."
