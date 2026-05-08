#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env"
COMPOSE_FILE="$ROOT_DIR/PATTERN-DOCKER/docker-compose.yml"

if [ ! -f "$ENV_FILE" ]; then
  echo "Falta $ENV_FILE. Copia .env.example a .env antes de validar."
  exit 1
fi

echo "==> Validando sintaxis de docker compose"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" config >/dev/null

echo "==> Endpoints esperados"
echo "- https://${SCRIPTORIUM_DOMAIN:-scriptorium.escrivivir.co}"
echo "- https://${SCRIPTORIUM_ADMIN_DOMAIN:-admin.scriptorium.escrivivir.co}"
echo "- https://${SCRIPTORIUM_MCP_DOMAIN:-mcp.scriptorium.escrivivir.co}/mcp"
echo "- https://${SCRIPTORIUM_NPM_DOMAIN:-npm.scriptorium.escrivivir.co}"
