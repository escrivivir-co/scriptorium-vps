#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env"
COMPOSE_FILE="$ROOT_DIR/PATTERN-DOCKER/docker-compose.yml"
COMMAND="${1:-plan}"

usage() {
  cat <<'EOF'
Uso: bash scripts/deploy.sh <comando>

Comandos seguros:
  plan            Imprime la ventana controlada y comandos exactos; no muta nada.
  preflight       Valida .env, compose config y placeholders; no levanta servicios.

Comandos mutantes (solo dentro del VPS y con aprobación PO justo antes):
  setup-volumes   Crea/ajusta /srv/scriptorium con UID:GID configurado.
  deploy-local    Ejecuta docker compose up -d --build.
  restart-local   Reinicia servicios del compose ScriptoriumVps.
  rollback-local  Detiene el compose ScriptoriumVps sin tocar OASIS_PUB.

Candado requerido para comandos mutantes:
  export SCRIPTORIUM_DEPLOY_CONFIRM=YES_DEPLOY_SCRIPTORIUM_VPS
EOF
}

load_env() {
  if [ ! -f "$ENV_FILE" ]; then
    echo "Falta $ENV_FILE. Copia .env.example a .env y rellena placeholders antes de operar."
    exit 1
  fi
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
}

assert_no_placeholders() {
  if grep -nE 'CHANGE_ME|TODO|REPLACE_ME' "$ENV_FILE"; then
    echo "El .env contiene placeholders. Sustitúyelos antes de preflight/deploy."
    exit 1
  fi
}

assert_confirmed() {
  if [ "${SCRIPTORIUM_DEPLOY_CONFIRM:-}" != "YES_DEPLOY_SCRIPTORIUM_VPS" ]; then
    echo "Operación mutante bloqueada. Falta: export SCRIPTORIUM_DEPLOY_CONFIRM=YES_DEPLOY_SCRIPTORIUM_VPS"
    exit 1
  fi
}

cmd_plan() {
  cat <<EOF
Ventana controlada VPS-08 — NO ejecuta nada por sí misma

Objetivo:
  Desplegar ScriptoriumVps junto al PUB existente sin parar ni reemplazar OASIS_PUB.

Rutas afectadas:
  - Código: /opt/oasis-scriptorium/ScriptoriumVps
  - Datos Scriptorium: \${SCRIPTORIUM_REMOTE_ROOT:-/srv/scriptorium}
  - Edge existente: BlockchainComPort/OASIS_PUB/caddy/Caddyfile

Comandos previstos dentro del VPS, tras aprobación explícita PO:
  cd /opt/oasis-scriptorium
  git pull --recurse-submodules
  git submodule update --init --recursive ScriptoriumVps BlockchainComPort
  cd ScriptoriumVps
  cp .env.example .env   # si no existe; rellenar secretos fuera de git
  bash scripts/deploy.sh preflight
  sudo -E bash scripts/deploy.sh setup-volumes
  export SCRIPTORIUM_DEPLOY_CONFIRM=YES_DEPLOY_SCRIPTORIUM_VPS
  bash scripts/deploy.sh deploy-local
  bash scripts/verify.sh

Rollback mínimo:
  cd /opt/oasis-scriptorium/ScriptoriumVps
  export SCRIPTORIUM_DEPLOY_CONFIRM=YES_DEPLOY_SCRIPTORIUM_VPS
  bash scripts/deploy.sh rollback-local
  cd ../BlockchainComPort/OASIS_PUB
  docker compose -f docker-compose.pub.yml restart pub-web

Condiciones de abortar:
  - DNS no apunta a \${SCRIPTORIUM_EXPECTED_VPS_IP:-<IP_VPS>}.
  - docker compose config falla.
  - falta .env o contiene placeholders.
  - pub.escrivivir.co deja de responder 200/30x antes del cambio.
EOF
}

cmd_preflight() {
  load_env
  assert_no_placeholders
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" config >/dev/null
  echo "preflight OK: compose válido y .env sin placeholders obvios."
}

cmd_setup_volumes() {
  load_env
  assert_no_placeholders
  assert_confirmed
  SCRIPTORIUM_UID="${SCRIPTORIUM_UID:-1000}" \
  SCRIPTORIUM_GID="${SCRIPTORIUM_GID:-1000}" \
  SCRIPTORIUM_REMOTE_ROOT="${SCRIPTORIUM_REMOTE_ROOT:-/srv/scriptorium}" \
    bash "$ROOT_DIR/scripts/setup-volumenes.sh"
}

cmd_deploy_local() {
  load_env
  assert_no_placeholders
  assert_confirmed
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d --build
}

cmd_restart_local() {
  load_env
  assert_no_placeholders
  assert_confirmed
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" restart
}

cmd_rollback_local() {
  load_env
  assert_confirmed
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down
}

case "$COMMAND" in
  plan) cmd_plan ;;
  preflight) cmd_preflight ;;
  setup-volumes) cmd_setup_volumes ;;
  deploy-local) cmd_deploy_local ;;
  restart-local) cmd_restart_local ;;
  rollback-local) cmd_rollback_local ;;
  help|-h|--help) usage ;;
  *) usage; exit 1 ;;
esac
