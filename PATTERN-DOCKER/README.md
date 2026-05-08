# PATTERN-DOCKER

Scaffold inicial del stack público de `ScriptoriumVps`.

## Servicios previstos

- `caddy` como único frontend público (`80/443`)
- `nodered` como contenedor pedagógico single-instance
- `mcp-devops` como superficie MCP pública para DevOps
- `verdaccio` como registry público de `@alephscript/*`

## Nota de alcance

En este bloque solo se deja el patrón base y los placeholders seguros. Las implementaciones completas y las validaciones en vivo se realizan en `VPS-03` a `VPS-07`.
