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

Este scaffold deja lista la estructura de arranque. Las implementaciones profundas de DNS/Caddy, Node-RED, MCP DevOps, Verdaccio y volúmenes se completan en tareas posteriores del dossier.

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
