#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENV_FILE="${SCRIPTORIUM_ENV_FILE:-$ROOT_DIR/.env}"
MODE="public"
ALLOW_REMOTE_PRESET="${SCRIPTORIUM_ALLOW_REMOTE_READ:-}"

usage() {
  cat <<'EOF'
Usage: bash scripts/check_alive.sh [--public] [--remote] [--all]

Read-only alive check for the Scriptorium/OASIS shared VPS.

Modes:
  --public   Check public HTTPS endpoints only (default).
  --remote   Check Docker/internal health via SSH. Requires:
             SCRIPTORIUM_ALLOW_REMOTE_READ=YES_READ_VPS and SCRIPTORIUM_SSH_*.
  --all      Run public checks and remote checks.
  --help     Show this help.

No secrets are printed. The script does not restart, reload, deploy, mutate Docker,
or read rooms-secrets.json.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --public) MODE="public" ;;
    --remote) MODE="remote" ;;
    --all) MODE="all" ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi
if [ -n "$ALLOW_REMOTE_PRESET" ]; then
  SCRIPTORIUM_ALLOW_REMOTE_READ="$ALLOW_REMOTE_PRESET"
fi

SCRIPTORIUM_DOMAIN="${SCRIPTORIUM_DOMAIN:-scriptorium.escrivivir.co}"
SCRIPTORIUM_ADMIN_DOMAIN="${SCRIPTORIUM_ADMIN_DOMAIN:-admin.scriptorium.escrivivir.co}"
SCRIPTORIUM_MCP_DOMAIN="${SCRIPTORIUM_MCP_DOMAIN:-mcp.scriptorium.escrivivir.co}"
SCRIPTORIUM_NPM_DOMAIN="${SCRIPTORIUM_NPM_DOMAIN:-npm.scriptorium.escrivivir.co}"
SCRIPTORIUM_ROOMS_DOMAIN="${SCRIPTORIUM_ROOMS_DOMAIN:-rooms.scriptorium.escrivivir.co}"
SCRIPTORIUM_PUB_DOMAIN="${SCRIPTORIUM_PUB_DOMAIN:-pub.escrivivir.co}"

status=0

check_code() {
  local label="$1"
  local url="$2"
  local allowed="$3"
  local code
  code=$(curl -k -sS -o /dev/null -w '%{http_code}' --max-time 12 -I "$url" || true)
  printf '%-34s %s -> %s\n' "$label" "$url" "$code"
  case ",$allowed," in
    *",$code,"*) ;;
    *) status=1 ;;
  esac
}

check_body() {
  local label="$1"
  local url="$2"
  local expected="$3"
  local body
  body=$(curl -k -fsS --max-time 12 "$url" 2>/dev/null || true)
  printf '%-34s %s -> %s\n' "$label" "$url" "${body:-<empty>}"
  if [ "$body" != "$expected" ]; then
    status=1
  fi
}

run_public() {
  echo "== Public alive checks =="
  check_code "pub landing" "https://${SCRIPTORIUM_PUB_DOMAIN}/" "200,301,302"
  check_code "scriptorium /red" "https://${SCRIPTORIUM_DOMAIN}/red/" "200,301,302,401,403"
  check_code "scriptorium /dashboard" "https://${SCRIPTORIUM_DOMAIN}/dashboard/" "200,301,302"
  check_code "scriptorium /ui" "https://${SCRIPTORIUM_DOMAIN}/ui/" "200,301,302"
  check_code "admin /red" "https://${SCRIPTORIUM_ADMIN_DOMAIN}/red/" "200,301,302,401,403"
  check_code "mcp /healthz" "https://${SCRIPTORIUM_MCP_DOMAIN}/healthz" "200,401,403"
  check_code "npm /-/ping" "https://${SCRIPTORIUM_NPM_DOMAIN}/-/ping" "200"
  check_body "rooms /healthz" "https://${SCRIPTORIUM_ROOMS_DOMAIN}/healthz" "scriptorium rooms edge ok"
}

remote_ssh() {
  : "${SCRIPTORIUM_SSH_HOST:?SCRIPTORIUM_SSH_HOST no definido}"
  : "${SCRIPTORIUM_SSH_USER:?SCRIPTORIUM_SSH_USER no definido}"
  : "${SCRIPTORIUM_SSH_KEY_PATH:?SCRIPTORIUM_SSH_KEY_PATH no definido}"
  local port="${SCRIPTORIUM_SSH_PORT:-22}"
  ssh -i "$SCRIPTORIUM_SSH_KEY_PATH" -p "$port" -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
    "${SCRIPTORIUM_SSH_USER}@${SCRIPTORIUM_SSH_HOST}" "$@"
}

run_remote() {
  if [ "${SCRIPTORIUM_ALLOW_REMOTE_READ:-}" != "YES_READ_VPS" ]; then
    echo "Remote alive bloqueado. Exporta SCRIPTORIUM_ALLOW_REMOTE_READ=YES_READ_VPS para lectura remota."
    return 1
  fi

  echo "== Remote Docker/internal alive checks =="
  remote_ssh 'set -eu
printf "%s\n" "-- docker ps --"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "^(NAMES|oasis-pub-|scriptorium-vps-)" || true
printf "\n%s\n" "-- internal health --"
docker exec scriptorium-vps-nodered-1 sh -lc "printf rooms:; curl -fsS http://127.0.0.1:3010/healthz; echo; printf node-red:; curl -fsS -o /dev/null -w %{http_code} http://127.0.0.1:1880/red/; echo" || exit 1
docker exec oasis-pub-web sh -lc "printf edge-to-rooms:; wget -qO- http://scriptorium-rooms:3010/healthz; echo" || exit 1
docker exec scriptorium-vps-verdaccio-1 sh -lc "printf verdaccio:; wget -qO- http://127.0.0.1:4873/-/ping; echo" || true
printf "\n%s\n" "-- mounts --"
docker exec scriptorium-vps-nodered-1 sh -lc "mount | grep -E '\''/data |/run/secrets/rooms'\'' || true"
'
}

case "$MODE" in
  public) run_public ;;
  remote) run_remote || status=1 ;;
  all) run_public; echo; run_remote || status=1 ;;
esac

if [ "$status" -eq 0 ]; then
  echo "OK: alive checks passed"
else
  echo "FAIL: revisar uno o más alive checks" >&2
fi
exit "$status"
