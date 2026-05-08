# Scriptorium VPS

Bootstrap operativo para el VPS público de Scriptorium.

## Objetivo

Este repositorio concentra el patrón inicial para publicar cuatro superficies bajo `escrivivir.co`:

- `scriptorium.escrivivir.co` → Node-RED pedagógico (`/red`, `/ui`, `/dashboard`)
- `admin.scriptorium.escrivivir.co` → administración autenticada del mismo Node-RED
- `mcp.scriptorium.escrivivir.co` → MCP DevOps por Streamable HTTP + Bearer
- `npm.scriptorium.escrivivir.co` → Verdaccio público para `@alephscript/*`

## Qué trae el scaffold

- `PATTERN-DOCKER/` con el compose base y patrones por servicio
- `node-red-projects/` como monorepo para proyectos Node-RED
- `scripts/` con helpers de despliegue, verificación y SFTP
- `.env.example` con placeholders de configuración y secretos no reales
- `README-SCRIPTORIUM.md` para documentar la integración con el workspace padre

## Estado

Este scaffold deja lista la estructura de arranque y los patrones locales de los servicios principales:

- DNS/Caddy se modela contra el edge compartido `OASIS_PUB` mediante snippet y red externa.
- Node-RED se modela como contenedor único con `/red`, `/ui`, `/dashboard`, projects y contribs por manifiesto.
- MCP DevOps se modela con gateway Streamable HTTP + Bearer delante de `DevOpsServer`.
- Verdaccio se modela como registry público con auth `htpasswd`, scope `@alephscript/*` y pipeline de publicación en `dry-run`.
- Volúmenes/SFTP usan helpers y variables `SCRIPTORIUM_SSH_*`/`SCRIPTORIUM_REMOTE_ROOT`.

Las validaciones en vivo, DNS real, Docker remoto y publicación real quedan bloqueadas hasta ventana controlada de Aleph con aprobación explícita del PO.

## Estructura

```text
ScriptoriumVps/
├── README.md
├── README-SCRIPTORIUM.md
├── PATTERN-DOCKER/
├── node-red-projects/
├── scripts/
└── .env.example
```
