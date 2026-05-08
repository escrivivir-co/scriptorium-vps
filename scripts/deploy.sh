#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env"
COMPOSE_FILE="$ROOT_DIR/PATTERN-DOCKER/docker-compose.yml"

if [ ! -f "$ENV_FILE" ]; then
  echo "Falta $ENV_FILE. Copia .env.example a .env y rellena los placeholders antes de desplegar."
  exit 1
fi

echo "==> Levantando stack Scriptorium VPS"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d --build
