# Patrón Node-RED

Este directorio deja preparada la superficie del contenedor único `nodered` que el dossier pide para el MVP pedagógico.

## Contrato vigente

- Un solo contenedor `nodered`
- Editor en `/red`
- Dashboard clásico en `/ui`
- Dashboard 2 en `/dashboard`
- Público anónimo con permisos de lectura
- Admin autenticado con permisos de escritura/deploy
- `projects.enabled=true` contra `../node-red-projects`

## Qué falta materializar en tareas posteriores

- flows y projects iniciales
- smoke tests reales del contenedor y de los dashboards durante ventana controlada

## Artefactos integrados

- `Dockerfile` construye la imagen Node-RED a partir de `NODERED_BASE_IMAGE`.
- `settings.js` fija `/red`, `/ui`, `/dashboard`, `adminAuth.default=read` y admin `permissions="*"`.
- `node-red-contribs.json` declara contribs de registry y paquetes del monorepo.
- `build-local-contribs.mjs` compila paquetes locales y valida smoke files antes de instalar.
- `install-contribs.mjs` instala solo si los artefactos compilados existen.

## Bootstrap en dos fases

El primer despliegue levanta Node-RED limpio, sin instalar todavía contribs AlephScript ni depender de `@alephscript/mcp-core-sdk`.

Motivo: Verdaccio forma parte del mismo bootstrap. Hasta que `npm.scriptorium.escrivivir.co` esté vivo, no debe usarse como origen de paquetes, y tampoco conviene bloquear el arranque inicial por `.tgz` locales.

Fase posterior, con Verdaccio ya verificado:

1. publicar paquetes iniciales con `PATTERN-DOCKER/verdaccio/publish-initial-packages.mjs`;
2. instalar contribs Node-RED desde el registry propio o mediante un rebuild controlado;
3. ejecutar smoke tests de dashboards/contribs.

El diseño sigue sin publicar `1880` al host; la exposición pública pasa por el edge definido en `VPS-03`.
