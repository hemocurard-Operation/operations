# I-003 · Source of Truth del Reporte Operativo Diario

**Fecha:** 2026-10-10  
**Principio:** distinguir entre lo realmente aplicado en Supabase y el SQL candidato existente en una rama no fusionada.

## Hallazgo que modifica el plan

La estrategia inicial de I-003 era portar a `main` los cinco SQL del PR #5 porque las cinco migraciones ya existen en Supabase. La comparación directa demostró que **los archivos del PR #5 no constituyen una copia exacta del historial aplicado**.

Por esa razón I-003 no copia esos archivos a `main` como si fueran migraciones históricas autoritativas.

## Evidencia autoritativa

Para saber qué ocurrió realmente en producción se usan dos fuentes:

1. `supabase_migrations.schema_migrations`: versión técnica, nombre y fingerprint del SQL aplicado.
2. Catálogo PostgreSQL actual: funciones, RLS, policies, grants y objetos existentes.

El PR #5 se clasifica como **fuente candidata de intención funcional**, no como historial inmutable de producción.

## Fingerprints de producción

| Versión técnica | Migración | MD5 del SQL aplicado | Relación con PR #5 |
|---|---|---|---|
| 20261010003020 | daily_operational_report_v0_40 | `464613766201281cd2def588dcea95be` | Difiere |
| 20261010003155 | daily_operational_report_governance_v0_41 | `5b7a069604be62069945eaaab6624e23` | Difiere |
| 20261010003228 | daily_operational_report_hardening_v0_42 | `2b1a3154ad371ff35d63ab7961bb7d0c` | Cercano semánticamente, no idéntico |
| 20261010065356 | daily_operational_report_performance_v0_43 | `dd58c75e04b87e98cbdb53bf85e4a3f0` | Coincidencia semántica |
| 20261010065410 | daily_operational_report_anon_hardening_v0_44 | `945ccd53166ca4cd9d33df5031e37e02` | Coincidencia semántica |

## Diferencias relevantes

### v0.40

El archivo candidato del PR #5 añade un registro a `public.app_migrations`. Ese insert no forma parte del SQL almacenado como aplicado por Supabase. Por ello el ledger funcional permanece sin entrada DAILY_REPORT aunque la capacidad sí exista.

### v0.41

El historial aplicado creó temporalmente `close_daily_operational_report` y `reopen_daily_operational_report` como `SECURITY DEFINER`. El archivo v0.41 del PR #5 no conserva esa misma secuencia histórica. La migración v0.42 aplicada posteriormente corrigió ambas a `SECURITY INVOKER`.

### v0.42

El archivo candidato incluye setup adicional del schema `private`; el SQL aplicado registrado no incluye esas mismas líneas. El efecto operacional principal de la migración —control de transiciones y RPC de cierre/reapertura como `SECURITY INVOKER`— sí está reflejado en el estado actual.

## Estado productivo actual verificado

Los cuatro RPC del reporte están actualmente en modo **SECURITY INVOKER**, con `search_path=public`, sin `EXECUTE` para `anon` y con `EXECUTE` para `authenticated`:

- `save_daily_operational_report`
- `submit_daily_operational_report`
- `close_daily_operational_report`
- `reopen_daily_operational_report`

Las policies activas verificadas son:

- `daily_operational_closes_insert`
- `daily_operational_closes_select`
- `daily_operational_closes_update`
- `daily_report_versions_select`

Todas operan para `authenticated` y combinan acceso de sucursal con permisos `DAILY_REPORT_*`.

## Regla de gobierno creada en I-003

A partir de esta iteración:

- **Applied truth:** `supabase_migrations` + catálogo productivo.
- **Functional intent:** SQL versionado en ramas/PR.
- **Release truth:** sólo existe cuando Git, schema, manifest, CI y UAT apuntan al mismo estado.
- Una migración candidata nunca se etiqueta como “aplicada” sólo porque su nombre se parece a una migración productiva.
- Ningún SQL histórico se reejecuta para “hacer coincidir” los ledgers.

## Qué NO hizo I-003

- No ejecutó DDL.
- No cambió RLS.
- No modificó funciones.
- No alteró datos clínicos.
- No copió SQL divergente a `main` como historial falso.

## Estado del drift

- D1 Metadata drift: **OPEN**.
- D2 Database ahead of main: **OPEN, pero ahora fingerprinted**.
- D3 Migration ledger drift: **OPEN, explicado**.
- D4 Branch divergence: **OPEN**.

## Próxima iteración: I-004

Crear un **baseline SQL reconciliado del estado actual**, generado a partir del catálogo productivo y diseñado para instalaciones nuevas. Este baseline será distinto del historial aplicado y deberá estar explícitamente marcado como `RECONCILED_BASELINE / DO_NOT_APPLY_TO_CURRENT_PRODUCTION`.

Luego se podrá integrar selectivamente el frontend del Reporte Operativo Diario sobre `main` sin confundir historial con estado deseado.