# Patrón MCP Mesh DevOps

El bootstrap inicial del VPS expone únicamente `MCPDevOpsServer`.

## Decisiones fijadas por el dossier

- transporte: Streamable HTTP
- autenticación: `Authorization: Bearer <token>`
- endpoint esperado: `https://mcp.scriptorium.escrivivir.co/mcp`
- validación oficial: `MCPGallery/mcp-inspector-sdk`
- persistencia reutilizada: `ARCHIVO/PLUGINS/MCP_DATA/devops-mcp-server/`

## Siguiente tarea

`VPS-05` sustituyó el placeholder del compose por un gateway seguro delante de `DevOpsServer`.

## Artefactos integrados

- `Dockerfile` copia `MCPGallery/` y `ScriptoriumVps/` para construir el runtime aislado.
- `entrypoint.sh` enlaza la persistencia real montada en `/workspace/devops-data` con la ruta esperada por `mcp-mesh-sdk`.
- `secure-devops-bootstrap.ts` levanta `DevOpsServer` en puerto interno privado (`3004`) y expone un gateway público interno en `3003`.
- `mcp-inspector.streamable-http.json` deja la plantilla de validación Streamable HTTP + Bearer.

El gateway expone `/health`, `/healthz` y `/mcp`; exige `Authorization: Bearer <token>` en `/mcp`, aplica scopes y audita operaciones de escritura/borrado.
