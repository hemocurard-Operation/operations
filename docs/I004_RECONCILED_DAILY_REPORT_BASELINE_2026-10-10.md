# I-004 · Baseline reconciliado del Reporte Operativo Diario

**Fecha:** 2026-10-10

## Objetivo

Crear una fuente SQL reproducible del **estado final deseado** del Reporte Operativo Diario para instalaciones nuevas/reconstruidas, sin falsificar el historial aplicado y sin tocar la producción actual.

## Artefactos

- `sql/reconciled/45_DAILY_OPERATIONAL_REPORT_RECONCILED_BASELINE.sql`
- `sql/reconciled/45_DAILY_OPERATIONAL_REPORT_RECONCILED_VALIDATE.sql`

El baseline integra en una sola definición final:

- captura consolidada del reporte;
- permisos `DAILY_REPORT_*`;
- snapshots/versionado;
- RLS por sucursal + permiso;
- transiciones BORRADOR/REABIERTO → EN_REVISION → CERRADO;
- reapertura con motivo;
- RPCs save/submit/close/reopen como `SECURITY INVOKER`;
- revocación de `anon`;
- grants mínimos para `authenticated`;
- índices de soporte.

## Regla de uso

`45_DAILY_OPERATIONAL_REPORT_RECONCILED_BASELINE.sql` está marcado explícitamente:

**DO NOT APPLY TO CURRENT PRODUCTION** `tiothqiljipdamgudvcb`.

La producción ya contiene esta capacidad a través de cinco migraciones aplicadas el 2026-10-10. El baseline reconciliado existe para reconstrucción y nuevas instalaciones, no para modificar el proyecto actual.

## Verificación read-only contra producción

Se confirmó:

- todos los prerrequisitos del baseline existen;
- existe la restricción única `(close_date, branch_id)` necesaria para el upsert;
- los cuatro RPC existen actualmente como `SECURITY INVOKER`;
- los cuatro RPC tienen `search_path=public`;
- `anon` no tiene `EXECUTE` sobre esos RPC;
- ambos objetos del reporte tienen RLS activo;
- `anon` no tiene SELECT/INSERT/UPDATE sobre `daily_operational_closes` ni `daily_operational_report_versions`;
- policies activas: `daily_operational_closes_insert`, `daily_operational_closes_select`, `daily_operational_closes_update`, `daily_report_versions_select`.

## Mejora de CI

La workflow `HemoCura Migration Security Linter` ahora incluye `sql/reconciled/**/*.sql`, por lo que los baselines reconciliados quedan sujetos a las mismas reglas HC001–HC010 utilizadas para migraciones gobernadas.

## Limitación de validación

No se ejecutó el baseline contra producción, ni siquiera dentro de una transacción de rollback. Crear una rama temporal de Supabase tiene coste y requiere confirmación explícita, por lo que esta iteración se limita a:

1. comparación con el catálogo productivo real;
2. validación read-only;
3. linter estático de CI.

## Gate I-004

- [x] Baseline reconciliado creado.
- [x] Validador read-only creado.
- [x] Prerrequisitos verificados en producción.
- [x] Contrato actual de RPC/RLS/grants verificado.
- [x] SQL reconciliado incorporado al security linter.
- [ ] CI del PR en PASS.
- [ ] Merge a `main`.

## Próxima iteración

**I-005 · Integración selectiva del frontend del Reporte Operativo Diario.**

Partir de `main`, no del branch antiguo. Integrar primero Router + Views y añadir `#dailyinventory` sin eliminar `quick-capture` ni reactivar decisiones clínicas automáticas.