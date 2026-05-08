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

- `settings.js` definitivo con `adminAuth`
- manifiesto de contribs del monorepo
- flows y projects iniciales
- smoke tests del contenedor y de los dashboards
