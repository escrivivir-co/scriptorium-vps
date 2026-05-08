# DNS esperado y verificación — VPS-03

## Registros esperados (diseño, no aplicados)

> Todos los hosts son **aditivos**. No sustituyen `pub.escrivivir.co`, no tocan `escrivivir.co` raíz y no modifican registros Bluesky / `_atproto`.

| Host | Tipo | Valor esperado | Uso |
|------|------|----------------|-----|
| `scriptorium.escrivivir.co` | `A` | `<IP_DEL_VPS_COMPARTIDO>` | Node-RED público en read-only + `/ui` + `/dashboard` |
| `admin.scriptorium.escrivivir.co` | `A` | `<IP_DEL_VPS_COMPARTIDO>` | Node-RED admin autenticado |
| `mcp.scriptorium.escrivivir.co` | `A` | `<IP_DEL_VPS_COMPARTIDO>` | MCP DevOps Streamable HTTP + Bearer |
| `npm.scriptorium.escrivivir.co` | `A` | `<IP_DEL_VPS_COMPARTIDO>` | Verdaccio público |

Si el host dispone de IPv6, añadir `AAAA` equivalentes como operación separada y explícita.

## Verificación de solo lectura propuesta

### DNS

```text
dig +short scriptorium.escrivivir.co A
dig +short admin.scriptorium.escrivivir.co A
dig +short mcp.scriptorium.escrivivir.co A
dig +short npm.scriptorium.escrivivir.co A
```

### Edge/Caddy

```text
curl -I https://scriptorium.escrivivir.co/healthz
curl -I https://admin.scriptorium.escrivivir.co/healthz
curl -I https://mcp.scriptorium.escrivivir.co/healthz
curl -I https://npm.scriptorium.escrivivir.co/healthz
```

### Upstreams esperados por host

```text
curl -I https://scriptorium.escrivivir.co/red/
curl -I https://scriptorium.escrivivir.co/ui/
curl -I https://scriptorium.escrivivir.co/dashboard/
curl -I https://admin.scriptorium.escrivivir.co/red/
curl -I https://mcp.scriptorium.escrivivir.co/mcp
curl -I https://npm.scriptorium.escrivivir.co/
```

## Operaciones bloqueadas hasta aprobación PO

- Crear/modificar registros reales en Gandi o WordPress DNS
- SSH/SCP al VPS
- `docker compose up` en el VPS real
- editar `BlockchainComPort/OASIS_PUB/caddy/Caddyfile` en producción
- tocar `pub.escrivivir.co`, `escrivivir.co` raíz o Bluesky/`_atproto`
- copiar secretos desde `GANDI_DEVOPS_FOLDER/`
