# I-002 · Reconciliación de release y drift GitHub ↔ Supabase

**Fecha:** 2026-10-10  
**Baseline:** I-001 fusionada en `main`  
**Alcance:** análisis y documentación; sin DDL, sin cambios clínicos y sin mutación de datos.

## 1. Estado de versión

- `VERSION.json`: **0.45.4**
- `RELEASE_MANIFEST.json`: **0.44.0**
- Resultado: **DRIFT DE METADATOS**.

`RELEASE_MANIFEST.json` no debe considerarse evidencia vigente del runtime 0.45.4 hasta regenerarse desde la línea principal reconciliada.

## 2. Estado del código desplegado

`main` contiene el frontend 0.45.4 y conserva los flujos `quick-capture` y guardrails de interfaz. La línea principal no contiene las cinco migraciones del Reporte Operativo Diario que están en el PR #5:

- `sql/40_DAILY_OPERATIONAL_REPORT_v0_40.sql`
- `sql/41_DAILY_OPERATIONAL_REPORT_GOVERNANCE_v0_41.sql`
- `sql/42_DAILY_OPERATIONAL_REPORT_HARDENING_v0_42.sql`
- `sql/43_DAILY_OPERATIONAL_REPORT_PERFORMANCE_v0_43.sql`
- `sql/44_DAILY_OPERATIONAL_REPORT_ANON_HARDENING_v0_44.sql`

PR #5 permanece draft y contiene además cambios de frontend sobre router, views, layout, access-control, screening, donors, CSS y dashboard.

## 3. Estado real de Supabase

La base productiva sí contiene los objetos del Reporte Operativo Diario:

- `public.daily_operational_closes`: existe.
- `public.daily_operational_report_versions`: existe.
- `save_daily_operational_report(...)`: existe.
- `submit_daily_operational_report(uuid)`: existe.
- `close_daily_operational_report(uuid)`: existe.
- `reopen_daily_operational_report(uuid,text)`: existe.

Además, `supabase_migrations.schema_migrations` registra las cinco migraciones del reporte como aplicadas el 2026-10-10.

## 4. Drift del ledger de migraciones

`public.app_migrations` no contiene registros correspondientes al Reporte Operativo Diario, aunque `supabase_migrations.schema_migrations` sí los contiene.

Esto confirma que actualmente existen dos mecanismos de registro con semánticas distintas y sin reconciliación automática:

1. `supabase_migrations.schema_migrations`: historial técnico de migraciones aplicadas.
2. `public.app_migrations`: ledger funcional/operacional de HemoCura.

**Riesgo:** una validación que consulte sólo `public.app_migrations` puede concluir erróneamente que una capacidad no está instalada, mientras el esquema real ya cambió.

## 5. Clasificación del drift

### D1 · Metadata drift — P1

`VERSION.json=0.45.4` vs `RELEASE_MANIFEST.json=0.44.0`.

### D2 · Database-ahead-of-main — P0

El backend del Reporte Operativo Diario existe en Supabase antes de que su SQL y frontend estén fusionados en `main`.

### D3 · Migration-ledger drift — P0

Las migraciones del reporte están en `supabase_migrations` pero no en `public.app_migrations`.

### D4 · Branch divergence — P0

PR #5 contiene una cantidad amplia de cambios sobre archivos que también evolucionaron en 0.45.x. No debe fusionarse por arrastre completo sin reconciliación archivo por archivo.

## 6. Decisiones de I-002

1. **No regenerar aún `RELEASE_MANIFEST.json`**: hacerlo antes de reconciliar PR #5 produciría un manifiesto técnicamente nuevo pero conceptualmente incompleto.
2. **No revertir las migraciones del reporte**: el backend ya existe y debe tratarse como estado productivo a reconciliar, no como cambio descartable.
3. **No fusionar PR #5 completo**: usar `main` como base y portar de forma selectiva el comportamiento que falta.
4. **Unificar el criterio de instalación**: todo gate futuro debe consultar `supabase_migrations` y, cuando corresponda, `app_migrations`, dejando explícita la diferencia entre migración técnica y registro funcional.
5. **Regenerar el Release Manifest sólo después del cutover reconciliado**.

## 7. Secuencia segura de reconciliación

1. Crear rama de integración desde `main` actual.
2. Portar primero los cinco SQL del reporte para que Git represente el estado que ya existe en Supabase.
3. Marcar esos SQL como **ya aplicados en producción**; no reejecutarlos ciegamente.
4. Portar router + views para exponer `#dailyinventory` sin romper `quick-capture`.
5. Portar layout/dashboard/access-control de forma selectiva.
6. Portar screening/donors sólo si la simplificación no elimina trazabilidad ni guardrails existentes.
7. Ejecutar smoke/CI.
8. UAT autenticado por rol y sucursal.
9. Regenerar `RELEASE_MANIFEST.json` desde el commit reconciliado.
10. Ejecutar Security Advisor + Release Doctor.

## 8. Gate de salida I-002

I-002 queda **cerrada como análisis de reconciliación** cuando:

- [x] mismatch VERSION/manifest identificado;
- [x] SQL ausente en main identificado;
- [x] objetos reales en Supabase verificados;
- [x] doble ledger de migraciones verificado;
- [x] estrategia de no-reaplicación definida;
- [x] orden de integración definido;
- [ ] rama técnica de integración selectiva creada;
- [ ] SQL ya aplicado portado a Git;
- [ ] frontend reconciliado;
- [ ] manifest regenerado.

Los cuatro últimos puntos pasan a **I-003/I-004**, para mantener cambios pequeños, auditables y reversibles.

## 9. Próxima iteración

**I-003 · Source of Truth + Port de migraciones ya aplicadas.**

Objetivo: hacer que el repositorio represente fielmente el esquema productivo sin ejecutar nuevamente las migraciones.