#!/usr/bin/env bash
set -u

seconds="${IDLE_SECONDS:-20}"
warn_cpu="${WARN_CPU:-80}"
crit_cpu="${CRIT_CPU:-95}"
warn_mem="${WARN_MEM:-80}"
crit_mem="${CRIT_MEM:-95}"
warn_disk="${WARN_DISK:-80}"
crit_disk="${CRIT_DISK:-90}"
warn_net_mib="${WARN_NET_MIB:-50}"
crit_net_mib="${CRIT_NET_MIB:-500}"
crit=0
warn=0
reasons=""

mark_warn() { warn=1; reasons="${reasons}\nWARN: $*"; }
mark_crit() { crit=1; reasons="${reasons}\nCRIT: $*"; }
now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date; }

read_net_bytes() {
  awk '
    FILENAME ~ /statistics\/rx_bytes$/ { rx += $1 }
    FILENAME ~ /statistics\/tx_bytes$/ { tx += $1 }
    END { printf "%s %s\n", rx+0, tx+0 }
  ' /sys/class/net/*/statistics/rx_bytes /sys/class/net/*/statistics/tx_bytes 2>/dev/null || echo "0 0"
}

mib() {
  awk -v bytes="$1" 'BEGIN { printf "%.2f", bytes / 1024 / 1024 }'
}

printf '== VPS idle/saturation snapshot ==\n'
printf 'timestamp: %s\n' "$(now_utc)"
printf 'window: %ss\n' "$seconds"
printf 'thresholds: cpu warn/crit=%s/%s mem warn/crit=%s/%s disk warn/crit=%s/%s net warn/crit=%s/%s MiB\n' "$warn_cpu" "$crit_cpu" "$warn_mem" "$crit_mem" "$warn_disk" "$crit_disk" "$warn_net_mib" "$crit_net_mib"
printf '\n'

if ! command -v docker >/dev/null 2>&1; then
  mark_crit "docker no disponible en este host"
else
  before_net=$(read_net_bytes)
  before_rx=${before_net%% *}
  before_tx=${before_net##* }
  sleep "$seconds"
  after_net=$(read_net_bytes)
  after_rx=${after_net%% *}
  after_tx=${after_net##* }
  rx_delta=$((after_rx - before_rx))
  tx_delta=$((after_tx - before_tx))
  total_delta=$((rx_delta + tx_delta))
  total_mib=$(mib "$total_delta")

  printf '== Docker containers ==\n'
  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E '^(NAMES|oasis-pub-|scriptorium-vps-)' || true
  printf '\n'

  printf '== Docker stats (one-shot after window) ==\n'
  stats_file=$(mktemp)
  docker stats --no-stream --format '{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}' > "$stats_file" 2>/dev/null || true
  printf 'NAME\tCPU\tMEM_USAGE\tMEM%%\tNET_IO\n'
  cat "$stats_file"
  awk -F '\t' -v wc="$warn_cpu" -v cc="$crit_cpu" -v wm="$warn_mem" -v cm="$crit_mem" '
    {
      cpu=$2; mem=$4;
      gsub(/%/, "", cpu); gsub(/%/, "", mem);
      gsub(/,/, ".", cpu); gsub(/,/, ".", mem);
      if (cpu+0 >= cc) printf "CRIT: CPU %s%% en %s\n", cpu, $1;
      else if (cpu+0 >= wc) printf "WARN: CPU %s%% en %s\n", cpu, $1;
      if (mem+0 >= cm) printf "CRIT: RAM %s%% en %s\n", mem, $1;
      else if (mem+0 >= wm) printf "WARN: RAM %s%% en %s\n", mem, $1;
    }
  ' "$stats_file" > "$stats_file.flags"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in
      CRIT:*) mark_crit "${line#CRIT: }" ;;
      WARN:*) mark_warn "${line#WARN: }" ;;
    esac
  done < "$stats_file.flags"
  rm -f "$stats_file" "$stats_file.flags"
  printf '\n'

  printf '== Host network delta ==\n'
  printf 'rx_delta=%s MiB tx_delta=%s MiB total=%s MiB over %ss\n' "$(mib "$rx_delta")" "$(mib "$tx_delta")" "$total_mib" "$seconds"
  net_level=$(awk -v v="$total_mib" -v w="$warn_net_mib" -v c="$crit_net_mib" 'BEGIN { if (v >= c) print "crit"; else if (v >= w) print "warn"; else print "ok" }')
  case "$net_level" in
    crit) mark_crit "red host ${total_mib}MiB/${seconds}s >= ${crit_net_mib}MiB" ;;
    warn) mark_warn "red host ${total_mib}MiB/${seconds}s >= ${warn_net_mib}MiB" ;;
  esac
  printf '\n'

  printf '== Docker health / restart count ==\n'
  health_file=$(mktemp)
  ids=$(docker ps -q --filter name=scriptorium-vps- --filter name=oasis-pub- 2>/dev/null || true)
  if [ -n "$ids" ]; then
    docker inspect $ids --format '{{.Name}} status={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}no-health{{end}} restarts={{.RestartCount}}' 2>/dev/null \
      | sed 's#^/##' | sort | tee "$health_file"
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      case "$line" in *'status=running'*) ;; *) mark_crit "container no running: $line" ;; esac
      case "$line" in
        *'health=unhealthy'*) mark_crit "container unhealthy: $line" ;;
        *'health=starting'*) mark_warn "container health starting: $line" ;;
      esac
    done < "$health_file"
  else
    mark_crit "no se encontraron contenedores oasis-pub/scriptorium-vps"
  fi
  rm -f "$health_file"
  printf '\n'

  printf '== Internal health ==\n'
  rooms=$(docker exec scriptorium-vps-nodered-1 sh -lc 'curl -fsS http://127.0.0.1:3010/healthz' 2>/dev/null || true)
  nodered=$(docker exec scriptorium-vps-nodered-1 sh -lc 'curl -fsS -o /dev/null -w %{http_code} http://127.0.0.1:1880/red/' 2>/dev/null || true)
  edge_rooms=$(docker exec oasis-pub-web sh -lc 'wget -qO- http://scriptorium-rooms:3010/healthz' 2>/dev/null || true)
  printf 'rooms=%s\nnode-red=%s\nedge-to-rooms=%s\n' "${rooms:-FAIL}" "${nodered:-FAIL}" "${edge_rooms:-FAIL}"
  [ "$rooms" = "ok" ] || mark_crit "rooms health interno no responde ok"
  case "$nodered" in 200|301|302|401|403) ;; *) mark_warn "node-red interno respondió ${nodered:-FAIL}" ;; esac
  [ "$edge_rooms" = "ok" ] || mark_crit "pub-web no alcanza scriptorium-rooms:3010"
  printf '\n'
fi

printf '== Disk usage ==\n'
df_file=$(mktemp)
for path in / /srv/oasis /srv/oasis/scriptorium /srv/oasis/scriptorium/node-red/data /srv/oasis/scriptorium/verdaccio/storage; do
  [ -e "$path" ] && df -P -h "$path"
done 2>/dev/null | awk '!seen[$6]++' | tee "$df_file"
awk -v wd="$warn_disk" -v cd="$crit_disk" 'NR>1 { used=$5; gsub(/%/, "", used); if (used+0 >= cd) printf "CRIT: disco %s%% en %s\n", used, $6; else if (used+0 >= wd) printf "WARN: disco %s%% en %s\n", used, $6; }' "$df_file" > "$df_file.flags"
while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in
    CRIT:*) mark_crit "${line#CRIT: }" ;;
    WARN:*) mark_warn "${line#WARN: }" ;;
  esac
done < "$df_file.flags"
rm -f "$df_file" "$df_file.flags"
printf '\n'

printf '== Recent Rooms activity (%ss) ==\n' "$seconds"
activity=""
if command -v docker >/dev/null 2>&1; then
  activity=$(docker logs --since "${seconds}s" scriptorium-vps-nodered-1 2>&1 \
    | grep -E 'JOIN|DISCONNECT|ROOM_MESSAGE|runtime.auth.reject|connect_error|CLIENT_REGISTER' \
    | tail -20 || true)
fi
if [ -n "$activity" ]; then
  printf '%s\n' "$activity"
  count=$(printf '%s\n' "$activity" | wc -l | tr -d ' ')
  [ "$count" -gt 10 ] && mark_warn "actividad Rooms reciente (${count} líneas sanitizadas mostradas)"
else
  echo 'sin eventos Rooms relevantes en la ventana'
fi
printf '\n'

printf '== Verdict ==\n'
if [ "$crit" -eq 1 ]; then
  printf 'VERDICT: PARAR_TODO\n'
  printf 'Motivo: umbral crítico o health crítico detectado. Si no hay una ventana activa, parar/degradar servicios no esenciales y revisar.\n'
  printf '%b\n' "$reasons"
  exit 2
fi
if [ "$warn" -eq 1 ]; then
  printf 'VERDICT: REVISAR\n'
  printf 'Motivo: hay señales de presión o actividad. No invites peers hasta revisar.\n'
  printf '%b\n' "$reasons"
  exit 1
fi
printf 'VERDICT: OK_IDLE\n'
printf 'Motivo: sin CPU/RAM/disco/health críticos; VPS parece apto para seguir/esperar peer.\n'
exit 0
