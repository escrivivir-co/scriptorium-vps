# Patrón Verdaccio

Registry público del MVP Scriptorium para paquetes `@alephscript/*` y contribs Node-RED `node-red-contrib-alephscript*`.

## Contrato vigente

- Host público esperado: `https://npm.scriptorium.escrivivir.co`.
- Auth: `htpasswd` en `/verdaccio/storage/htpasswd`.
- Publicación: usuarios autenticados.
- Lectura/instalación: pública.
- Storage persistente: `/srv/scriptorium/verdaccio/storage`.
- Exposición: sin `4873` público al host; el edge compartido de `OASIS_PUB` proxya al alias `scriptorium-verdaccio`.

## Artefactos

- `config.yaml` — configuración Verdaccio del registry.
- `.npmrc.example` — plantilla segura para uso con token npm.
- `publish-initial-packages.manifest.json` — lote inicial publicable y bloqueos explícitos.
- `publish-initial-packages.mjs` — pipeline de build/smoke/publish en `dry-run` por defecto.

## Seguridad operacional

El script de publicación no debe ejecutarse en modo real (`PUBLISH_MODE=publish`) sin ventana controlada de Aleph y aprobación explícita del PO.
