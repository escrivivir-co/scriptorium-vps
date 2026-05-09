#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ENV_FILE="${SCRIPTORIUM_ENV_FILE:-$ROOT_DIR/.env}"
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

public_host="${SCRIPTORIUM_DOMAIN:-scriptorium.escrivivir.co}"
admin_host="${SCRIPTORIUM_ADMIN_DOMAIN:-admin.scriptorium.escrivivir.co}"
paths=(/red/ /ui/ /dashboard/)
status=0

for path in "${paths[@]}"; do
  url="https://${public_host}${path}"
  echo "HEAD $url"
  if ! curl -fsSI --max-time 10 "$url" >/dev/null; then
    status=1
  fi
done

admin_url="https://${admin_host}/red/"
echo "HEAD $admin_url"
code=$(curl -k -sS -o /dev/null -w '%{http_code}' --max-time 10 -I "$admin_url" || true)
echo "admin /red status: $code"
case "$code" in
  200|301|302|401|403) ;;
  *) status=1 ;;
esac

exit "$status"
