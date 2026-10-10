# PR #5 — Plan de integración controlada con `main`

Fecha: 2026-10-10
Rama: `improve/usability-20261008`
Base objetivo: `main`

## Estado confirmado

- `main` avanzó 32 commits desde el merge-base `72b0e10d6f72ff3d97eaa56764f3ef56292fc744`.
- La rama del PR conserva cambios funcionales del Reporte Operativo Diario y simplificación operativa.
- El PR permanece `draft` y no debe promoverse hasta resolver divergencia y completar UAT.

## Archivos con solapamiento probable

1. `.github/workflows/frontend-browser-smoke.yml`
2. `css/ui-v0442.css`
3. `hemocura-core/access-control.js`
4. `hemocura-core/donors.js`
5. `hemocura-core/layout.js`
6. `hemocura-core/ops-dashboard.js`
7. `hemocura-core/router.js`
8. `hemocura-core/screening.js`
9. `hemocura-core/views.js`

## Cambios de `main` que deben preservarse

- flujo `quick-capture` y archivos `quick-capture*.js`;
- workflow `quick-capture-safety.yml`;
- actualizaciones de `VERSION.json`;
- cambios C13C2B de cutover RPC;
- pruebas `frontend-c11-2-smoke.html`;
- mejoras de simplicidad/ergonomía v0.45.x.

## Cambios del PR #5 que deben preservarse

- Reporte Operativo Diario consolidado (`#dailyinventory`);
- tamizaje individual inactivo como captura operativa principal;
- inventario unitario inactivo como captura operativa principal;
- despacho individual inactivo como captura operativa principal;
- permisos DAILY_REPORT_VIEW/WRITE/SUBMIT/CLOSE/REOPEN;
- estados BORRADOR/REABIERTO → EN_REVISION → CERRADO;
- firma, reapertura motivada y versionado;
- migraciones v0.40–v0.44;
- cierre de acceso `anon` al reporte;
- índices específicos de performance del reporte.

## Regla de resolución

Para cada archivo solapado:

1. partir de la versión actual de `main`;
2. reintroducir únicamente el comportamiento del PR #5 que no contradiga `quick-capture`;
3. evitar reactivar captura individual de tamizaje/inventario/despachos como flujo principal;
4. conservar rutas nuevas de `main` y añadir `#dailyinventory` sin duplicar navegación;
5. ejecutar smoke tests y revisión visual después de cada grupo de archivos.

## Orden recomendado

1. Router + Views
2. Layout + Mi trabajo
3. Access control
4. Screening
5. Donors
6. CSS
7. Frontend smoke workflow
8. Validación completa

## Gates antes de merge

- rama 0 commits detrás de `main`;
- CI del nuevo head ejecutado;
- 65 smoke tests existentes revisados;
- RLS probado con sesiones autenticadas de dos sucursales/roles;
- móvil/tablet/impresión;
- UAT con LABORATORIO/ENCARGADA y supervisión/calidad;
- ninguna liberación clínica automatizada.
