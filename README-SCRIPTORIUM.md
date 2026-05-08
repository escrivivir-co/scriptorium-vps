# ScriptoriumVps — Integración con Aleph Scriptorium

**Submódulo**: `ScriptoriumVps`  
**Rama de integración**: `integration/beta/scriptorium`  
**Plugin destino**: `scriptorium-vps`  
**Repo remoto**: `https://github.com/escrivivir-co/scriptorium-vps.git`  
**Fecha**: 2026-05-08

---

## Propósito

`ScriptoriumVps` entra en el workspace como el submódulo operativo para el VPS público del Scriptorium. Su responsabilidad es agrupar el patrón Docker, el monorepo de proyectos Node-RED y los scripts de despliegue/verificación sin mezclar datos mutables del runtime con el código del submódulo.

## Superficies principales

| Superficie | Ruta | Uso |
|------------|------|-----|
| Patrón Docker | `PATTERN-DOCKER/` | Caddy, Node-RED, MCP DevOps y Verdaccio |
| Monorepo Node-RED | `node-red-projects/` | Projects del runtime pedagógico |
| Helpers operativos | `scripts/` | Deploy, verify, SFTP |
| Variables ejemplo | `.env.example` | Placeholders para dominios, tokens y credenciales |

## Relación con el plugin local

El plugin `.github/plugins/scriptorium-vps/` describe los agentes operativos que gobernarán este submódulo desde Copilot Chat. Los datos mutables del plugin viven fuera del repo, en `ARCHIVO/PLUGINS/SCRIPTORIUM_VPS/`.

## Datos y persistencia relacionados

- `ARCHIVO/PLUGINS/SCRIPTORIUM_VPS/` → snapshots de deploy, auditoría y plantillas de secretos
- `ARCHIVO/PLUGINS/MCP_DATA/devops-mcp-server/` → persistencia real del DevOps MCP ya existente
- `ARCHIVO/PLUGINS/MCP_PRESETS/` → presets/launcher reutilizables por la mesh MCP
- `/srv/scriptorium/ARCHIVO` y `/srv/scriptorium/ARCHIVO/DISCO` → volúmenes shared del VPS

## Reglas de integración

1. No guardar secretos reales en el submódulo.
2. Mantener `README-SCRIPTORIUM.md` actualizado cuando cambien rutas o contratos con el workspace padre.
3. Exponer al host solo Caddy (`80/443`); el resto del patrón opera detrás del proxy.
4. Tratar `node-red-projects/` como monorepo: cada subcarpeta podrá ser un project nativo de Node-RED.
5. Mantener la rama `integration/beta/scriptorium` como rama de integración por defecto.

## Validación mínima

- El submódulo figura en `.gitmodules` con path `ScriptoriumVps`.
- Existe `.env.example` con placeholders seguros.
- `PATTERN-DOCKER/docker-compose.yml` describe el arranque inicial sin publicar puertos directos salvo Caddy.
- `node-red-projects/.gitkeep` existe como ancla del monorepo.
