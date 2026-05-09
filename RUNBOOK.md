# Runbook VPS-08 — Producción controlada

Este runbook despliega `ScriptoriumVps` junto al PUB existente sin sustituir `OASIS_PUB`.

## Arquitectura objetivo

- `pub.escrivivir.co` sigue servido por `BlockchainComPort/OASIS_PUB/pub-web`.
- `scriptorium.escrivivir.co`, `admin.scriptorium.escrivivir.co`, `mcp.scriptorium.escrivivir.co` y `npm.scriptorium.escrivivir.co` se añaden al mismo Caddy edge.
- `ScriptoriumVps` levanta servicios internos sin publicar `1880`, `3003` ni `4873` al host.
- Los datos persistentes de Scriptorium viven en `/srv/oasis/scriptorium`, dentro del volumen Gandi `scriptorium-oasis-pub-volumen` montado en `/srv/oasis`, no en el disco de arranque `vps-boot`.
- La comunicación edge → servicios usa `oasis-pub-scriptorium_oasis_pub_net` y aliases:
  - `scriptorium-nodered`
  - `scriptorium-mcp-devops`
  - `scriptorium-verdaccio`
  - `scriptorium-rooms` (alias adicional del servicio `nodered`; expone puerto `3010` internamente a `pub-web` sin publicarlo al host)

## Estado comprobado antes de operar

Preflight público del 2026-05-09:

- `pub.escrivivir.co` → `92.243.24.163`, responde `200` por Caddy.
- `scriptorium.escrivivir.co` → `92.243.24.163`.
- `admin.scriptorium.escrivivir.co` → `92.243.24.163`.
- `mcp.scriptorium.escrivivir.co` → `92.243.24.163`.
- `npm.scriptorium.escrivivir.co` → `92.243.24.163`.
- DNS Scriptorium ya apunta al VPS compartido; queda pendiente aplicar/verificar Caddy y servicios en ventana controlada.

## Precondiciones

1. DNS de los cuatro hosts Scriptorium debe apuntar a `92.243.24.163`.
2. El VPS debe tener el repo en `/opt/aleph-scriptorium`.
3. `BlockchainComPort/OASIS_PUB/caddy/Caddyfile` debe incluir los bloques Scriptorium aditivos.
4. `ScriptoriumVps/.env` debe existir en el VPS, no versionado y sin `CHANGE_ME`.
5. Docker Compose v2 operativo en el VPS.
6. El pub existente debe responder antes de tocar Scriptorium:

```bash
curl -I https://pub.escrivivir.co
```

## Ventana controlada obligatoria

Antes de mutar DNS/Gandi/VPS/Docker, Aleph debe presentar al PO:

- objetivo de la ventana;
- comandos exactos;
- rutas afectadas;
- rollback;
- backup/snapshot esperado;
- variables/llaves usadas desde entorno local no versionado;
- criterio de éxito;
- condición de abortar.

El PO debe aprobar explícitamente justo antes de operar.

## Comandos de despliegue previstos en el VPS

```bash
cd /opt/aleph-scriptorium
git pull --recurse-submodules
git submodule update --init --recursive ScriptoriumVps BlockchainComPort
cd ScriptoriumVps
cp .env.example .env  # solo si no existe; rellenar secretos fuera de git
bash scripts/deploy.sh preflight
sudo -E bash scripts/deploy.sh setup-volumes
export SCRIPTORIUM_DEPLOY_CONFIRM=YES_DEPLOY_SCRIPTORIUM_VPS
bash scripts/deploy.sh deploy-local
bash scripts/verify.sh
```

### Bootstrap Node-RED y paquetes AlephScript

El primer `deploy-local` levanta Node-RED limpio y Verdaccio. No instala todavía contribs AlephScript ni arranca `mcp-devops`.

En `docker-compose.yml`, `mcp-devops` está bajo el profile `mcp` para que no participe en el bootstrap inicial.

La publicación/instalación de paquetes AlephScript se realiza después de verificar que Verdaccio está vivo:

1. comprobar `https://npm.scriptorium.escrivivir.co/-/ping`;
2. publicar el lote inicial en modo controlado;
3. reinstalar/reconstruir Node-RED con contribs desde el registry propio si procede;
4. activar `mcp-devops` con `COMPOSE_PROFILES=mcp` cuando `@alephscript/mcp-core-sdk` y `mcp-mesh-sdk` ya estén disponibles desde Verdaccio o normalizados.

Esto evita el ciclo de bootstrap en el que Node-RED o MCP necesitan paquetes servidos por un Verdaccio que aún no existe.

## Node-RED Rooms MVP

Paquete candidato Dashboard 2 del MVP:

- `WiringEditor/packages/node-red-dashboard-2-alephscript-rooms`

Flow candidato exportable:

- `ScriptoriumVps/node-red-projects/rooms-mvp-candidate.flow.json`

Decisión operativa actual del MVP:

- modo recomendado: `managed-port`;
- runtime Rooms dentro del contenedor Node-RED, en puerto dedicado interno (por defecto `3010`);
- la UI Dashboard 2 no conecta directamente al runtime Rooms desde el navegador;
- el widget envía comandos al flow, y el flow delega en:
  - `alephscript-rooms-server`
  - `alephscript-rooms-agent-dummy`

Motivo: con el SDK actual, `same-origin` no es todavía la opción segura por defecto porque el runtime crea su propio Socket.IO sobre el path estándar `/socket.io`, lo que puede colisionar con el stack ya usado por Dashboard 2.

Checks locales/operativos del MVP:

```bash
cd WiringEditor/packages/node-red-dashboard-2-alephscript-rooms
npm install
npm run build:full
npm pack --dry-run
```

Checks funcionales una vez desplegado el flow en Node-RED:

- `/dashboard/rooms` responde con el widget Rooms;
- el nodo `alephscript-rooms-server` muestra snapshots `SET_SERVER_STATE`;
- `alephscript-rooms-agent-dummy` crea 3 agentes y los suscribe a `ROOMS_LAB`;
- la UI lista namespaces, rooms, usuarios y sockets;
- al hacer `Leave`, los agentes salen de la room y el estado se refresca.

### Estado validado en VPS — 2026-05-09

Resultado de la ventana controlada R09-06:

- `node-red-dashboard-2-alephscript-rooms@0.1.0` publicado en `https://npm.scriptorium.escrivivir.co`;
- `scriptorium-vps-nodered-1` con `@flowfuse/node-red-dashboard`, `node-red-dashboard` y `node-red-dashboard-2-alephscript-rooms` instalados;
- flow activo copiado desde `ScriptoriumVps/node-red-projects/rooms-mvp-candidate.flow.json` a `/data/flows.json` dentro del contenedor;
- endpoints verificados:
  - `https://scriptorium.escrivivir.co/ui/` → `200`
  - `https://scriptorium.escrivivir.co/dashboard/` → `200`
  - `https://scriptorium.escrivivir.co/dashboard/rooms` → `200`
  - `https://admin.scriptorium.escrivivir.co/red/` → `200`
- UI validada con 3 dummy agents en `ROOMS_LAB`, `managed-port`, `GET_SERVER_STATE` periódico y listado de namespaces/rooms/usuarios/sockets.

### Caveat actual de persistencia

La activación actual del MVP quedó operativa, pero todavía no totalmente endurecida frente a recreación completa del contenedor:

- los paquetes Node-RED del MVP se instalaron dentro de `/data` con `npm install` en el contenedor vivo;
- el flow activo reside en `/data/flows.json` dentro del contenedor;
- esto sobrevive a reinicios del contenedor, pero no está garantizado tras un `docker compose up -d --build` o recreación total.

Handoff operativo:

- mantener esta evidencia en `RUNBOOK.md` y la trazabilidad técnica en `TASK-04_STACK_NODERED.md`;
- no seguir usando `TASK-09` como runbook vivo;
- próximo endurecimiento: automatizar reinstalación de contribs y materializar el flow MVP como project persistente o procedimiento reproducible de bootstrap.

## Caddy/OASIS_PUB

El bloque `pub.escrivivir.co` debe permanecer intacto. Los hosts Scriptorium se añaden como bloques nuevos en `BlockchainComPort/OASIS_PUB/caddy/Caddyfile`.

Después de aplicar el Caddyfile en el VPS:

```bash
# Validar ANTES de recargar (nunca restart con config no validada)
cat /opt/oasis-scriptorium/OASIS_PUB/caddy/Caddyfile \
  | docker exec -i oasis-pub-web caddy validate --adapter caddyfile --config /dev/stdin

# Reload sin reiniciar el contenedor (preserva TLS/sessions de pub.escrivivir.co)
cat /opt/oasis-scriptorium/OASIS_PUB/caddy/Caddyfile \
  | docker exec -i oasis-pub-web caddy reload --adapter caddyfile --config /dev/stdin
```

⚠️ **NUNCA** `docker compose restart pub-web` con un Caddyfile no validado. Si algo falla, restaurar el backup `.before-*` y recargar por stdin.

⚠️ **Bind mount single-file:** un `cp` sobre el Caddyfile en el host cambia el inode; el contenedor sigue viendo el inode antiguo. Para editar en-lugar usa `cat > file` (preserva inode). Si ya se produjo el cambio de inode, carga la config por stdin como se muestra arriba.

## Pub.Rooms federado

> Operativo desde 2026-05-09 (TASK-10). Endpoint: `wss://rooms.scriptorium.escrivivir.co/runtime`.

### Verificación rápida del edge y upstream

```bash
# Edge Caddy (responde a nivel Caddy sin tocar el upstream)
curl -sI https://rooms.scriptorium.escrivivir.co/healthz
# Esperado: HTTP/2 200  body: "scriptorium rooms edge ok"

# Upstream real (desde dentro del contenedor nodered)
docker exec scriptorium-vps-nodered-1 curl -sf http://127.0.0.1:3010/healthz
# Esperado: ok

# Upstream desde pub-web (via alias Docker)
docker exec oasis-pub-web wget -qO- http://scriptorium-rooms:3010/healthz
# Esperado: ok
```

### Unirse como cliente (primera vez)

```bash
# Prerequisito: Node.js >= 18 y Node-RED instalado (npm install -g node-red)
git clone https://github.com/escrivivir-co/scriptorium-vps.git
cd scriptorium-vps
bash ScriptoriumVps/scripts/bootstrap-mesh-client.sh
# El script pide: ROOMS_USER, ROOMS_ROOM, ROOMS_SECRET (interactivo si no están en env)
# El secret lo proporciona el owner fuera de banda.
```

O con variables en entorno (modo no interactivo):

```bash
export ROOMS_USER=mi-handle
export ROOMS_ROOM=ROOMS_LAB
export ROOMS_SECRET=<secret-recibido-del-owner>
bash ScriptoriumVps/scripts/bootstrap-mesh-client.sh
```

Después:

```bash
source ~/.node-red/.env.rooms && node-red
# Abrir http://localhost:1880/red/ → Import → flows_pub-room-client.json → Deploy
# Verificar en https://scriptorium.escrivivir.co/dashboard/rooms que apareces
```

### Rotación del shared secret (R10-06)

El secret se almacena en `/srv/oasis/scriptorium/node-red/secrets/rooms-secrets.json` en el VPS (perms `600`, owner `1000:1000`). El fichero tiene la forma:

```json
{"ROOMS_LAB": "<secret-urlsafe-base64-43-chars>"}
```

Procedimiento de rotación:

```bash
# 1. Generar nuevo secret
nuevo=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
echo "nuevo secret-len: ${#nuevo} (no mostrar en logs)"

# 2. Escribir en el fichero de secrets del VPS
ssh debian@92.243.24.163 \
  "python3 -c \"import json; d={'ROOMS_LAB': '$nuevo'}; open('/srv/oasis/scriptorium/node-red/secrets/rooms-secrets.json','w').write(json.dumps(d))\""

# 3. Recargar el runtime Rooms (hot-reload de flows via API admin, sin recrear contenedor)
curl -s -X POST http://admin.scriptorium.escrivivir.co/red/flows \
  -H 'Node-RED-API-Version: v2' \
  -H 'Content-Type: application/json' \
  -d '{"deploymentType":"reload"}'

# 4. Distribuir el nuevo secret a los peers fuera de banda
# 5. Cada peer actualiza ~/.node-red/.env.rooms y reinicia node-red
```

⚠️ El secret NUNCA en git, en logs, ni en transcripts de sesiones de operaciones.

### Diagnóstico de conexión federada

```bash
# Ver logs de auth / JOIN / DISCONNECT en el contenedor
docker logs --since 10m scriptorium-vps-nodered-1 2>&1 \
  | grep -E "auth|JOIN|DISCONNECT|ROOM_MESSAGE|reject" | tail -20

# Smoke rápido desde cualquier máquina con Node.js
ROOMS_SECRET=<secret> node -e "
  const io = require('socket.io-client');
  const s = io('https://rooms.scriptorium.escrivivir.co/runtime', {
    auth: { token: process.env.ROOMS_SECRET, room: 'ROOMS_LAB', user: 'smoke' },
    transports: ['websocket'], timeout: 5000
  });
  s.on('connect', () => { console.log('OK connected', s.id); s.disconnect(); process.exit(0); });
  s.on('connect_error', e => { console.log('ERROR:', e.message); process.exit(1); });
  setTimeout(() => process.exit(2), 8000);
"
```

### Límites del sistema (no objetivos de TASK-10)

- No es identidad fuerte: el shared secret es MVP. No sustituye OASIS/SSB.
- Sin registro abierto: solo amigos con secret distribuido fuera de banda.
- Sin WebRTC, JWT ni identidad federada AT-Protocol en este ciclo.
- El endpoint `/socket.io` no está expuesto por `scriptorium.escrivivir.co` (solo por `rooms.scriptorium.escrivivir.co`).

## Verificación

Desde `ScriptoriumVps/`:

```bash
bash scripts/check_alive.sh --public
SCRIPTORIUM_ALLOW_REMOTE_READ=YES_READ_VPS bash scripts/check_idle.sh --remote --seconds 5
bash scripts/verify-dns.sh
bash scripts/verify-caddy.sh
bash scripts/verify-nodered.sh
bash scripts/verify-mcp-devops.sh
bash scripts/verify-verdaccio.sh
bash scripts/verify.sh
```

### Check alive / cierre rápido

`scripts/check_alive.sh` es el comando ligero para cierre de sesión Ops:

```bash
# Solo endpoints públicos; no requiere SSH ni secretos
bash scripts/check_alive.sh --public

# Endpoints públicos + Docker/health interno por SSH read-only
SCRIPTORIUM_ALLOW_REMOTE_READ=YES_READ_VPS bash scripts/check_alive.sh --all
```

Qué promete: confirmar que `pub.`, `scriptorium.`, `admin.`, `mcp.`, `npm.` y `rooms.` responden; y, en modo remoto, que los contenedores clave están arriba y que `rooms:3010/healthz` responde desde Node-RED y desde `pub-web`.

Qué **no** promete: medir saturación, actividad reciente o discos. Para eso usa `check_idle`.

### Check idle / decisión rápida de parar

`scripts/check_idle.sh` responde a la pregunta operativa: **"¿me están saturando el VPS y debo parar/degradar servicios?"**

```bash
# Emergencia: veredicto en ~5s
SCRIPTORIUM_ALLOW_REMOTE_READ=YES_READ_VPS bash scripts/check_idle.sh --remote --seconds 5

# Snapshot más estable: ventana de 20s
SCRIPTORIUM_ALLOW_REMOTE_READ=YES_READ_VPS bash scripts/check_idle.sh --remote --seconds 20
```

Salida esperada:

- `VERDICT: OK_IDLE` — CPU/RAM/disco/red/health sin señales críticas.
- `VERDICT: REVISAR` — hay presión o actividad; no invitar peers hasta mirar.
- `VERDICT: PARAR_TODO` — CPU/RAM/disco/health críticos; si no hay una ventana activa, parar o degradar servicios no esenciales y revisar.

El script no imprime secrets ni lee `rooms-secrets.json`. No muta Docker. Mide:

- `docker ps` y `docker stats` de `oasis-pub-*` y `scriptorium-vps-*`;
- delta de red del host durante la ventana;
- health interno de Rooms, Node-RED y edge→Rooms;
- `df` de `/`, `/srv/oasis` y rutas persistentes clave;
- logs recientes de Rooms filtrados a eventos no sensibles.

Verificación remota de volúmenes, solo si la ventana controlada lo permite:

```bash
export SCRIPTORIUM_ALLOW_REMOTE_READ=YES_READ_VPS
bash scripts/verify-volumes.sh
```

## Verdaccio — operación mínima

Manual canónico dev/ops: `sala/dossiers/scriptorium-vps/tasks/TASK-06_STACK_VERDACCIO.md`.

Resumen VPS:

- Registry: `https://npm.scriptorium.escrivivir.co`.
- Scope: `@alephscript/*`.
- Upstream interno Caddy: `scriptorium-verdaccio:4873`.
- Storage persistente: `/srv/oasis/scriptorium/verdaccio/storage`.
- Owner crítico storage: `10001:65533` (proceso `verdaccio` dentro del contenedor).
- Usuario/admin: gestionar con `scripts/create-verdaccio-user.sh`; no usar registro API (`max_users: -1`).
- Publicación: gestionar con `scripts/publish-package.sh`; los paquetes deben declarar `author` y `maintainers`.

Checks mínimos:

```bash
bash scripts/verify-verdaccio.sh
npm ping --registry https://npm.scriptorium.escrivivir.co/
npm view @alephscript/mcp-core-sdk author maintainers \
  --registry https://npm.scriptorium.escrivivir.co
```

Recovery rápido:

```bash
docker ps --filter name=scriptorium-vps-verdaccio-1
docker logs --tail 100 scriptorium-vps-verdaccio-1
sudo chown -R 10001:65533 /srv/oasis/scriptorium/verdaccio/storage
docker restart scriptorium-vps-verdaccio-1
```

Errores graves:

| Síntoma | Acción corta |
|---|---|
| `EACCES` en `/verdaccio/storage` | Reaplicar `chown -R 10001:65533` al storage. |
| `409` creando usuario por API | Esperado: usar `scripts/create-verdaccio-user.sh`. |
| `E401` en publish | Usar `scripts/publish-package.sh` o revisar `.npmrc.example`. |
| UI muestra `Anonymous` | Falta `author`/`maintainers` en `package.json`; ver `TASK-06`. |

## Criterios de éxito

- `pub.escrivivir.co` sigue respondiendo por Caddy.
- Los cinco hosts Scriptorium resuelven a `92.243.24.163`.
- `/healthz` responde en los cinco hosts Scriptorium (incluyendo `rooms.scriptorium.escrivivir.co`).
- `/red`, `/ui` y `/dashboard` responden en `scriptorium.escrivivir.co`.
- `admin.scriptorium.escrivivir.co/red/` exige autenticación o responde de forma controlada.
- `mcp.scriptorium.escrivivir.co/mcp` devuelve `401/403` sin Bearer y `200` con Bearer válido.
- `npm.scriptorium.escrivivir.co/-/ping` responde.
- `rooms.scriptorium.escrivivir.co/healthz` responde `200` y el upstream real devuelve `ok`.
- Handshake Socket.IO con token válido conecta a `ROOMS_LAB`; con token inválido se rechaza con `unauthorized`.
- Los volúmenes bajo `/srv/oasis/scriptorium` existen y usan UID:GID `1000:1000` salvo decisión distinta.

## Rollback mínimo

```bash
cd /opt/aleph-scriptorium/ScriptoriumVps
export SCRIPTORIUM_DEPLOY_CONFIRM=YES_DEPLOY_SCRIPTORIUM_VPS
bash scripts/deploy.sh rollback-local
cd ../BlockchainComPort/OASIS_PUB
docker compose -f docker-compose.pub.yml restart pub-web
```

Si el problema es DNS, revertir los registros Scriptorium en el proveedor DNS. No tocar `pub.escrivivir.co`, `escrivivir.co` raíz ni registros Bluesky/`_atproto`.

## Operaciones prohibidas fuera de ventana

- editar DNS real;
- SSH/SCP/SFTP al VPS;
- `docker compose up/restart/down` remoto;
- publicar paquetes npm reales;
- editar secretos o claves;
- reemplazar el Caddy edge de `OASIS_PUB`.
