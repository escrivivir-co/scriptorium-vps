# PATTERN-DOCKER

Scaffold inicial del stack público de `ScriptoriumVps`.

## Servicios previstos

- `caddy` como perfil `standalone` local/documental del edge (`80/443`)
- `nodered` como contenedor pedagógico single-instance
- `mcp-devops` como superficie MCP pública para DevOps
- `verdaccio` como registry público de `@alephscript/*`

## Edge compartido para el MVP

En el VPS compartido del MVP, el edge productivo **no** es este `caddy`, sino `pub-web` de `BlockchainComPort/OASIS_PUB`.

Por tanto:

- este `caddy` queda como patrón `standalone` para desarrollo/documentación;
- los servicios `nodered`, `mcp-devops` y `verdaccio` se preparan para conectarse a la red externa `oasis-pub-scriptorium_oasis_pub_net`;
- los aliases esperados desde `OASIS_PUB` son `scriptorium-nodered`, `scriptorium-mcp-devops` y `scriptorium-verdaccio`;
- no debe levantarse un segundo edge productivo que compita por `80/443` en el VPS compartido.

## Nota de alcance

En este bloque solo se deja el patrón base y los placeholders seguros. Las implementaciones completas y las validaciones en vivo se realizan en `VPS-03` a `VPS-07`.
