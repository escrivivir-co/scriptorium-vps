#!/usr/bin/env bash
# bootstrap-mesh-client.sh — Bootstraps a local Node-RED to join Pub.Rooms
#
# Uso:
#   bash ScriptoriumVps/scripts/bootstrap-mesh-client.sh
#
# Variables de entorno (o se piden interactivamente):
#   ROOMS_USER    — nombre de usuario en la room (tu handle, sin espacios)
#   ROOMS_ROOM    — room a la que unirse (por defecto: ROOMS_LAB)
#   ROOMS_SECRET  — shared secret recibido del owner (NUNCA en git)
#
# Prerequisitos:
#   - Node-RED instalado localmente (npm install -g node-red)
#   - Node.js >= 18
#   - bash (Linux / macOS / WSL / Git Bash en Windows)
#
# Qué hace:
#   1. Detecta el directorio de usuario de Node-RED (~/.node-red)
#   2. Backup timestampeado del directorio actual
#   3. Escribe .npmrc apuntando al registry @alephscript (Verdaccio público)
#   4. npm install de los dos contribs del MVP
#   5. Copia pub-room-client.flow.json al directorio Node-RED
#   6. Escribe .env.rooms con las variables de sesión (fuera de git)
#   7. Instrucciones para arrancar Node-RED con las variables
#
# Más info: sala/dossiers/scriptorium-vps/tasks/TASK-10_PUB_ROOMS_FEDERATED.md

set -euo pipefail

REGISTRY="https://npm.scriptorium.escrivivir.co"
CORE_PKG="node-red-contrib-alephscript-core@0.2.0"
ROOMS_PKG="node-red-dashboard-2-alephscript-rooms@0.2.0"
FLOW_TEMPLATE="pub-room-client.flow.json"

# ── localizar el directorio del script y del repo ────────────────────────────
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
FLOW_SRC="$REPO_ROOT/node-red-projects/$FLOW_TEMPLATE"

# ── banner ────────────────────────────────────────────────────────────────────
echo ""
echo "┌─────────────────────────────────────────────────────┐"
echo "│   Pub.Rooms — bootstrap cliente Node-RED federado   │"
echo "│   rooms.scriptorium.escrivivir.co                   │"
echo "└─────────────────────────────────────────────────────┘"
echo ""

# ── verificar Node-RED instalado ──────────────────────────────────────────────
if ! command -v node-red >/dev/null 2>&1 && ! command -v node >/dev/null 2>&1; then
  echo "ERROR: Node.js no encontrado. Instala Node.js >= 18 desde https://nodejs.org"
  exit 1
fi

NODE_VERSION=$(node --version 2>/dev/null || echo "unknown")
echo "Node.js: $NODE_VERSION"

if ! command -v node-red >/dev/null 2>&1; then
  echo ""
  echo "AVISO: node-red no encontrado en PATH."
  echo "  Puedes instalarlo con: npm install -g node-red"
  echo "  O continuar si ya lo tienes en otro path."
  echo ""
fi

# ── detectar directorio de usuario Node-RED ───────────────────────────────────
NR_HOME="${NODE_RED_HOME:-$HOME/.node-red}"
echo "Directorio Node-RED: $NR_HOME"
mkdir -p "$NR_HOME"

# ── pedir variables interactivamente si no están en el entorno ────────────────
echo ""
echo "── Credenciales de conexión (no se guardan en git) ──"

if [ -z "${ROOMS_USER:-}" ]; then
  printf "  Tu nombre de usuario en la room (handle, sin espacios): "
  read -r ROOMS_USER
fi
if [ -z "${ROOMS_ROOM:-}" ]; then
  printf "  Room a la que unirte [ROOMS_LAB]: "
  read -r ROOMS_ROOM
  ROOMS_ROOM="${ROOMS_ROOM:-ROOMS_LAB}"
fi
if [ -z "${ROOMS_SECRET:-}" ]; then
  printf "  Shared secret recibido del owner: "
  read -rs ROOMS_SECRET
  echo ""
fi

if [ -z "$ROOMS_USER" ] || [ -z "$ROOMS_ROOM" ] || [ -z "$ROOMS_SECRET" ]; then
  echo "ERROR: ROOMS_USER, ROOMS_ROOM y ROOMS_SECRET son obligatorios."
  exit 1
fi

echo ""
echo "  Usuario: $ROOMS_USER"
echo "  Room:    $ROOMS_ROOM"
echo "  Secret:  [redacted — ${#ROOMS_SECRET} caracteres]"
echo ""

# ── backup del directorio Node-RED ───────────────────────────────────────────
TS=$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%Y%m%dT%H%M%SZ)
NR_BAK="${NR_HOME}-backup-$TS"
if [ -d "$NR_HOME" ] && [ "$(ls -A "$NR_HOME" 2>/dev/null)" ]; then
  echo "Backup de $NR_HOME → $NR_BAK"
  cp -a "$NR_HOME" "$NR_BAK"
  echo "OK backup"
else
  echo "Directorio Node-RED vacío — sin backup necesario"
fi

# ── .npmrc con registry @alephscript ─────────────────────────────────────────
NPMRC="$NR_HOME/.npmrc"
echo ""
echo "Configurando registry @alephscript en $NPMRC"
# Aseguramos la línea sin duplicar
if [ -f "$NPMRC" ]; then
  # Eliminar línea previa si existe
  grep -v "@alephscript:registry" "$NPMRC" > "$NPMRC.tmp" 2>/dev/null && mv "$NPMRC.tmp" "$NPMRC" || true
fi
echo "@alephscript:registry=$REGISTRY" >> "$NPMRC"
echo "OK .npmrc"

# ── npm install de los contribs ───────────────────────────────────────────────
echo ""
echo "Instalando contribs en $NR_HOME"
cd "$NR_HOME"

# Inicializar package.json mínimo si no existe (Node-RED lo crea al primer arranque,
# pero npm install lo necesita antes)
if [ ! -f "package.json" ]; then
  echo '{"name":"node-red-user","version":"1.0.0","private":true}' > package.json
fi

npm install \
  "$CORE_PKG" \
  "$ROOMS_PKG" \
  --registry "$REGISTRY" \
  --prefer-online \
  --no-fund \
  --no-audit \
  2>&1 | grep -E "added|changed|up to date|error|warn" || true

echo "OK contribs instalados"

# ── copiar flow cliente ───────────────────────────────────────────────────────
echo ""
FLOW_DST="$NR_HOME/flows_pub-room-client.json"
if [ -f "$FLOW_SRC" ]; then
  # Inyectar valores de usuario/room directamente en el flow JSON
  # Los campos authToken/authRoom/authUser quedan VACÍOS en el JSON del repo;
  # el nodo lee las env vars ROOMS_SECRET, ROOMS_ROOM, ROOMS_USER al arrancar.
  cp "$FLOW_SRC" "$FLOW_DST"
  echo "Flow copiado → $FLOW_DST"
  echo "(carga desde Node-RED admin: Import → fichero → selecciona flows_pub-room-client.json)"
else
  echo "AVISO: no se encontró $FLOW_SRC — descargando desde el registry público"
  curl -fsSL \
    "https://raw.githubusercontent.com/escrivivir-co/scriptorium-vps/integration/beta/scriptorium/node-red-projects/$FLOW_TEMPLATE" \
    -o "$FLOW_DST" 2>/dev/null || {
    echo "AVISO: no se pudo descargar el flow template. Importa pub-room-client.flow.json manualmente."
  }
fi

# ── escribir .env.rooms (fuera de git; para source antes de arrancar Node-RED) ──
ENV_ROOMS="$NR_HOME/.env.rooms"
cat > "$ENV_ROOMS" << ENVEOF
# .env.rooms — generado por bootstrap-mesh-client.sh — NO añadir a git
# Source este fichero antes de arrancar Node-RED:
#   source ~/.node-red/.env.rooms && node-red
ROOMS_USER=$ROOMS_USER
ROOMS_ROOM=$ROOMS_ROOM
ROOMS_SECRET=$ROOMS_SECRET
ENVEOF
chmod 600 "$ENV_ROOMS"
echo "Variables de sesión → $ENV_ROOMS (permisos 600)"

# ── instrucciones finales ─────────────────────────────────────────────────────
echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  Bootstrap completado. Pasos para unirte a Pub.Rooms:           │"
echo "│                                                                 │"
echo "│  1. source ~/.node-red/.env.rooms && node-red                   │"
echo "│  2. Abre http://localhost:1880/red/                             │"
echo "│  3. Importa el flow:                                            │"
echo "│       Menu → Import → Clipboard → pega el contenido de:        │"
echo "│       $FLOW_DST"
echo "│     (o arrastra el fichero en el editor)                        │"
echo "│  4. Deploy                                                      │"
echo "│  5. Verifica en el dashboard del VPS que apareces en la room:   │"
echo "│       https://scriptorium.escrivivir.co/dashboard/rooms         │"
echo "│                                                                 │"
echo "│  Para salir: Ctrl+C en la terminal de node-red                  │"
echo "│  Para rotar el secret: pide uno nuevo al owner y repite el      │"
echo "│    bootstrap o edita ~/.node-red/.env.rooms directamente.       │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo ""
