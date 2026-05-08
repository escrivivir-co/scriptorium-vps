#!/usr/bin/env sh
set -eu

CMD="${1:-help}"
HOST="${SFTP_HOST:-}"
PORT="${SFTP_PORT:-22}"
USER="${SFTP_USER:-scriptorium}"
REMOTE_ROOT="${SFTP_REMOTE_ROOT:-/srv/scriptorium}"

bootstrap_remote_layout() {
  if [ -z "$HOST" ]; then
    echo "Define SFTP_HOST en el entorno o en .env antes de ejecutar bootstrap."
    exit 1
  fi

  ssh -p "$PORT" "$USER@$HOST" "mkdir -p '$REMOTE_ROOT/ARCHIVO/DISCO' '$REMOTE_ROOT/caddy/data' '$REMOTE_ROOT/caddy/config' '$REMOTE_ROOT/verdaccio/storage'"
}

print_vscode_template() {
  cat <<EOF
{
  "name": "scriptorium-vps",
  "host": "${HOST:-vps.example.com}",
  "protocol": "sftp",
  "port": ${PORT},
  "username": "${USER}",
  "remotePath": "${REMOTE_ROOT}",
  "uploadOnSave": false,
  "ignore": [
    ".git",
    "node_modules",
    "**/.env"
  ]
}
EOF
}

case "$CMD" in
  bootstrap)
    bootstrap_remote_layout
    ;;
  vscode-template)
    print_vscode_template
    ;;
  *)
    echo "Uso: $0 {bootstrap|vscode-template}"
    ;;
esac
