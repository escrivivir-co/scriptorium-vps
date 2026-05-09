#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENV_FILE="${SCRIPTORIUM_ENV_FILE:-$ROOT_DIR/.env}"
PAYLOAD="$ROOT_DIR/scripts/check_idle_payload.sh"
MODE="auto"
IDLE_SECONDS=20
WARN_CPU=80
CRIT_CPU=95
WARN_MEM=80
CRIT_MEM=95
WARN_DISK=80
CRIT_DISK=90
WARN_NET_MIB=50
CRIT_NET_MIB=500
ALLOW_REMOTE_PRESET="${SCRIPTORIUM_ALLOW_REMOTE_READ:-}"

usage() {
  cat <<'EOF'
Usage: bash scripts/check_idle.sh [--remote|--local] [--seconds N]

Quick read-only saturation / idle snapshot for the shared OASIS + Scriptorium VPS.

Default verdicts:
  OK_IDLE       no critical saturation signals detected
  REVISAR       warning threshold reached (watch before inviting peers)
  PARAR_TODO    critical threshold reached (stop/degrade non-essential work)

Options:
  --seconds N        Sampling window, default 20 (allowed 5..120)
  --remote           Run through SSH using ScriptoriumVps/.env credentials
  --local            Run against local Docker daemon (when executed on VPS)
  --warn-cpu N       CPU warning threshold per container, default 80
  --crit-cpu N       CPU critical threshold per container, default 95
  --warn-mem N       RAM warning threshold per container, default 80
  --crit-mem N       RAM critical threshold per container, default 95
  --warn-disk N      Disk warning threshold, default 80
  --crit-disk N      Disk critical threshold, default 90
  --help             Show this help

Safety:
  - Does not restart/reload/deploy/mutate Docker.
  - Does not read rooms-secrets.json or .env contents into output.
  - Remote mode requires SCRIPTORIUM_ALLOW_REMOTE_READ=YES_READ_VPS.
EOF
}

need_number() {
  local name="$1" value="$2" min="$3" max="$4"
  case "$value" in
    ''|*[!0-9]*) echo "$name must be an integer" >&2; exit 2 ;;
  esac
  if [ "$value" -lt "$min" ] || [ "$value" -gt "$max" ]; then
    echo "$name must be between $min and $max" >&2
    exit 2
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --remote) MODE="remote" ;;
    --local) MODE="local" ;;
    --seconds|-s) shift; IDLE_SECONDS="${1:-}" ;;
    --warn-cpu) shift; WARN_CPU="${1:-}" ;;
    --crit-cpu) shift; CRIT_CPU="${1:-}" ;;
    --warn-mem) shift; WARN_MEM="${1:-}" ;;
    --crit-mem) shift; CRIT_MEM="${1:-}" ;;
    --warn-disk) shift; WARN_DISK="${1:-}" ;;
    --crit-disk) shift; CRIT_DISK="${1:-}" ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

need_number --seconds "$IDLE_SECONDS" 5 120
need_number --warn-cpu "$WARN_CPU" 1 999
need_number --crit-cpu "$CRIT_CPU" 1 999
need_number --warn-mem "$WARN_MEM" 1 100
need_number --crit-mem "$CRIT_MEM" 1 100
need_number --warn-disk "$WARN_DISK" 1 100
need_number --crit-disk "$CRIT_DISK" 1 100

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi
if [ -n "$ALLOW_REMOTE_PRESET" ]; then
  SCRIPTORIUM_ALLOW_REMOTE_READ="$ALLOW_REMOTE_PRESET"
fi

run_local() {
  IDLE_SECONDS="$IDLE_SECONDS" \
  WARN_CPU="$WARN_CPU" CRIT_CPU="$CRIT_CPU" \
  WARN_MEM="$WARN_MEM" CRIT_MEM="$CRIT_MEM" \
  WARN_DISK="$WARN_DISK" CRIT_DISK="$CRIT_DISK" \
  WARN_NET_MIB="$WARN_NET_MIB" CRIT_NET_MIB="$CRIT_NET_MIB" \
  bash "$PAYLOAD"
}

run_remote() {
  if [ "${SCRIPTORIUM_ALLOW_REMOTE_READ:-}" != "YES_READ_VPS" ]; then
    echo "Remote idle bloqueado. Exporta SCRIPTORIUM_ALLOW_REMOTE_READ=YES_READ_VPS para lectura remota."
    exit 2
  fi
  : "${SCRIPTORIUM_SSH_HOST:?SCRIPTORIUM_SSH_HOST no definido}"
  : "${SCRIPTORIUM_SSH_USER:?SCRIPTORIUM_SSH_USER no definido}"
  : "${SCRIPTORIUM_SSH_KEY_PATH:?SCRIPTORIUM_SSH_KEY_PATH no definido}"
  local port="${SCRIPTORIUM_SSH_PORT:-22}"
  IDLE_ENV="IDLE_SECONDS=$IDLE_SECONDS WARN_CPU=$WARN_CPU CRIT_CPU=$CRIT_CPU WARN_MEM=$WARN_MEM CRIT_MEM=$CRIT_MEM WARN_DISK=$WARN_DISK CRIT_DISK=$CRIT_DISK WARN_NET_MIB=$WARN_NET_MIB CRIT_NET_MIB=$CRIT_NET_MIB"
  ssh -i "$SCRIPTORIUM_SSH_KEY_PATH" -p "$port" -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
    "${SCRIPTORIUM_SSH_USER}@${SCRIPTORIUM_SSH_HOST}" \
    "$IDLE_ENV bash -s" < "$PAYLOAD"
}

case "$MODE" in
  local) run_local ;;
  remote) run_remote ;;
  auto)
    if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
      run_local
    else
      run_remote
    fi
    ;;
esac
