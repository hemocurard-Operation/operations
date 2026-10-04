# Hotfix v0.32.1 — Arranque congelado

## Defecto corregido

Antes:
```js
mountLayout(session);
```

`mountLayout()` es asíncrona. Si fallaba al cargar permisos, roles, RLS o vistas,
el error quedaba fuera del `try/catch` de `initApp()` y la pantalla permanecía
en "Inicializando v0.3.0…".

Ahora:
```js
await mountLayout(session);
```

El error llega al `catch` y se muestra en pantalla con código y acción sugerida.

## Si aparece un error después del hotfix

### vw_my_security_context / vw_my_access no existe
Ejecutar:
`sql/29_ACCESS_GOVERNANCE_v0_29.sql`

### diagnostic_events / vw_current_user_health no existe
Ejecutar:
`sql/30_UNIFIED_DIAGNOSTICS_v0_30.sql`

### approval_requests no existe
Ejecutar:
`sql/31_APPROVALS_SOD_v0_31.sql`

### columnas/documentos/CAPA faltantes
Ejecutar:
`sql/32_QMS_APPROVAL_INTEGRATION_v0_32.sql`

### RLS_DENIED / permission denied
Revisar:
- profiles
- user_roles
- branch_id
- role_permissions
- políticas RLS

No usar service_role en el navegador.
