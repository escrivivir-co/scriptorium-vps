# Patrón MCP Mesh DevOps

El bootstrap inicial del VPS expone únicamente `MCPDevOpsServer`.

## Decisiones fijadas por el dossier

- transporte: Streamable HTTP
- autenticación: `Authorization: Bearer <token>`
- endpoint esperado: `https://mcp.scriptorium.escrivivir.co/mcp`
- validación oficial: `MCPGallery/mcp-inspector-sdk`
- persistencia reutilizada: `ARCHIVO/PLUGINS/MCP_DATA/devops-mcp-server/`

## Siguiente tarea

`VPS-05` sustituirá el placeholder del compose por el bootstrap real del servidor y dejará documentado el smoke test con inspector.
