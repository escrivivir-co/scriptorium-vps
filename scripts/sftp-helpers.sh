#!/usr/bin/env bash
# sftp-helpers.sh — Utilidades SFTP para gestión del VPS desde VS Code / terminal
#
# Requiere: openssh-client (sftp), rsync (opcional para sync-down/sync-up)
# Variables de entorno necesarias (definir en .env o exportar manualmente).
# Nombres canónicos decididos en RESPUESTAS.md:
#
#   SCRIPTORIUM_SSH_HOST     — hostname o IP del VPS (ej: scriptorium.escrivivir.co)
#   SCRIPTORIUM_SSH_USER     — usuario SSH (ej: deploy)
#   SCRIPTORIUM_SSH_PORT     — puerto SSH (default: 22)
#   SCRIPTORIUM_SSH_KEY_PATH — ruta a clave privada SSH (default: ~/.ssh/id_ed25519)
#   SCRIPTORIUM_REMOTE_ROOT  — root de datos en el VPS (default: /srv/oasis/scriptorium)
#
# Nota: SCRIPTORIUM_SSH_KEY_PASSPHRASE se lee desde el keyring del SO / ssh-agent;
# NO se pasa como variable de entorno en scripts no interactivos.

set -euo pipefail

SCRIPTORIUM_SSH_HOST="${SCRIPTORIUM_SSH_HOST:?SCRIPTORIUM_SSH_HOST no definido}"
SCRIPTORIUM_SSH_USER="${SCRIPTORIUM_SSH_USER:?SCRIPTORIUM_SSH_USER no definido}"
SCRIPTORIUM_SSH_PORT="${SCRIPTORIUM_SSH_PORT:-22}"
SCRIPTORIUM_SSH_KEY_PATH="${SCRIPTORIUM_SSH_KEY_PATH:-${HOME}/.ssh/id_ed25519}"
SCRIPTORIUM_REMOTE_ROOT="${SCRIPTORIUM_REMOTE_ROOT:-/srv/oasis/scriptorium}"

_ssh_opts="-i ${SCRIPTORIUM_SSH_KEY_PATH} -p ${SCRIPTORIUM_SSH_PORT} -o StrictHostKeyChecking=accept-new"

usage() {
  echo "Uso: bash sftp-helpers.sh <comando> [args]"
  echo ""
  echo "Comandos:"
  echo "  health          Comprueba conectividad SSH al VPS"
  echo "  tree            Muestra árbol de volúmenes en el VPS"
  echo "  sync-down <dir> Descarga carpeta remota a ./tmp-vps-sync/"
  echo "  sync-up <local> <remote> Sube carpeta local al VPS"
  echo "  open-sftp       Abre sesión SFTP interactiva"
}

cmd_health() {
  echo "==> Probando conexión a ${SCRIPTORIUM_SSH_USER}@${SCRIPTORIUM_SSH_HOST}:${SCRIPTORIUM_SSH_PORT} ..."
  # shellcheck disable=SC2086
  ssh ${_ssh_opts} "${SCRIPTORIUM_SSH_USER}@${SCRIPTORIUM_SSH_HOST}" "echo OK && uname -a"
}

cmd_tree() {
  echo "==> Árbol de volúmenes en ${SCRIPTORIUM_REMOTE_ROOT} ..."
  # shellcheck disable=SC2086
  ssh ${_ssh_opts} "${SCRIPTORIUM_SSH_USER}@${SCRIPTORIUM_SSH_HOST}" \
    "find '${SCRIPTORIUM_REMOTE_ROOT}' -maxdepth 5 | sort"
}

cmd_sync_down() {
  local remote_dir="${1:?Falta directorio remoto}"
  local local_dest="./tmp-vps-sync"
  mkdir -p "${local_dest}"
  echo "==> Descargando ${remote_dir} → ${local_dest}/ ..."
  rsync -avz \
    -e "ssh ${_ssh_opts}" \
    "${SCRIPTORIUM_SSH_USER}@${SCRIPTORIUM_SSH_HOST}:${remote_dir}/" \
    "${local_dest}/"
  echo "==> Descarga completada en ${local_dest}/"
}

cmd_sync_up() {
  local local_dir="${1:?Falta directorio local}"
  local remote_dir="${2:?Falta directorio remoto}"
  echo "==> Subiendo ${local_dir}/ → ${SCRIPTORIUM_SSH_USER}@${SCRIPTORIUM_SSH_HOST}:${remote_dir}/ ..."
  rsync -avz \
    -e "ssh ${_ssh_opts}" \
    "${local_dir}/" \
    "${SCRIPTORIUM_SSH_USER}@${SCRIPTORIUM_SSH_HOST}:${remote_dir}/"
  echo "==> Subida completada."
}

cmd_open_sftp() {
  echo "==> Abriendo sesión SFTP interactiva en ${SCRIPTORIUM_SSH_USER}@${SCRIPTORIUM_SSH_HOST}:${SCRIPTORIUM_SSH_PORT} ..."
  # shellcheck disable=SC2086
  sftp ${_ssh_opts} "${SCRIPTORIUM_SSH_USER}@${SCRIPTORIUM_SSH_HOST}"
}

case "${1:-help}" in
  health)     cmd_health ;;
  tree)       cmd_tree ;;
  sync-down)  cmd_sync_down "${2:-}" ;;
  sync-up)    cmd_sync_up "${2:-}" "${3:-}" ;;
  open-sftp)  cmd_open_sftp ;;
  *)          usage ;;
esac

exit 0
