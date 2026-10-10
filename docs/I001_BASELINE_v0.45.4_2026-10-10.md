# I-001 · Línea base técnica HemoCura Operations v0.45.4

**Fecha de captura:** 2026-10-10  
**Alcance:** auditoría read-only de GitHub + Supabase.  
**Regla:** esta iteración no modifica datos, RLS, funciones, decisiones clínicas ni `js/config.js`.

## 1. Identidad del frontend desplegado

- Repositorio: `hemocurard-Operation/operations`
- Visibilidad: **público**
- Rama de despliegue: `main`
- Commit baseline: `c306ec88eaf2037599e171c49246cb87ea1b36fd`
- Mensaje del commit: `v0.45.4 · simpler forms with consistency guards`
- `VERSION.json`: `0.45.4`
- Canal: `RC`
- Núcleo clínico: `LIVE-LIMITED / CONTROLLED_RELEASE`
- Rama `main`: **sin protección** al momento de la captura.

### CI/Deploy asociado al commit baseline

- HemoCura Quick Capture Safety: **PASS**
- HemoCura Frontend Browser Smoke: **PASS**
- GitHub Pages build/deployment: **PASS**

**Conclusión frontend:** el commit `0.45.4` tiene evidencia de smoke y despliegue exitoso. No equivale a Release 1.0 READY.

## 2. Supabase baseline

- Project ref: `tiothqiljipdamgudvcb`
- Estado: `ACTIVE_HEALTHY`
- Región: `us-east-2`
- PostgreSQL: `17.11.0.002`
- Tablas `public`: **143**
- Tablas `public` con RLS habilitado: **143 / 143**

### Hardening registrado en `public.app_migrations`

Confirmado:

- `0.44.3` · `C12_SECURITY_HARDENING_v0_44_3`
- `0.44.4` · `C13A_RLS_NO_POLICY_v0_44_4`
- `0.44.5` · `C13C1_FUNCTION_EXECUTE_HARDENING_v0_44_5`
- `0.44.6` · `C13C2A_CONTROLLED_RPC_WRAPPERS_v0_44_6`

No se considera confirmado por esta línea base:

- C13-C2B retiro de RPC legacy
- C14 guardrails clínicos de base de datos
- cierre completo de anon surface
- cierre completo de vistas `SECURITY DEFINER`
- cierre completo de `search_path`
- Release Doctor final READY

## 3. Security Advisor · deuda activa

El Security Advisor reporta actualmente:

- **67** vistas `SECURITY DEFINER`.
- **19** funciones con `search_path` mutable.
- **34** funciones `SECURITY DEFINER` en `public`.
- **28** de esas funciones son ejecutables por `authenticated`.
- **0** funciones `SECURITY DEFINER` ejecutables por `anon` según la consulta directa realizada.
- Leaked Password Protection: **deshabilitada**.

### Superficie Data API observada

La consulta de privilegios efectivos detectó:

- `anon` con privilegio `SELECT` sobre **118 tablas** de `public`.
- `anon` con privilegio `SELECT` sobre **82 vistas** de `public`.

Esto no implica por sí solo acceso a filas de las tablas porque las 143 tablas tienen RLS habilitado. Sin embargo, las vistas requieren revisión prioritaria porque las vistas con privilegios del creador pueden eludir las expectativas de RLS.

## 4. Drift crítico GitHub ↔ Supabase

### P0 · Base de datos adelantada respecto de `main`

Supabase `supabase_migrations.schema_migrations` registra migraciones aplicadas el 2026-10-10 para el Reporte Operativo Diario, incluyendo:

- `daily_operational_report_v0_40`
- `daily_operational_report_governance_v0_41`
- `daily_operational_report_hardening_v0_42`
- `daily_operational_report_performance_v0_43`
- `daily_operational_report_anon_hardening_v0_44`

Ese trabajo está asociado al PR #5 `improve/usability-20261008`, que permanece **draft / no fusionado** con `main` y declara explícitamente que `main` avanzó mientras las migraciones ya fueron aplicadas.

**Riesgo:** producción Supabase contiene objetos y contratos que no están representados todavía por la línea principal desplegada de GitHub. Esto rompe el principio deseado de reproducibilidad `Git commit -> migraciones -> runtime`.

**Decisión I-001:** no aplicar nuevas migraciones ni expandir el backend hasta reconciliar este drift.

## 5. Deuda de gobierno del repositorio

### P0

1. Reconciliar PR #5 con `main` y decidir qué cambios de frontend acompañan a las migraciones ya aplicadas.
2. Generar un snapshot reproducible del esquema real y compararlo con SQL versionado.
3. Resolver la exposición de vistas `SECURITY DEFINER` y superficie `anon` antes de Release 1.0.

### P1

4. Proteger `main` con PR obligatorio y checks requeridos.
5. Sincronizar `VERSION.json` y `RELEASE_MANIFEST.json`; el manifiesto histórico no debe quedarse en una versión anterior.
6. Unificar el ledger de migraciones (`supabase_migrations` vs `public.app_migrations`) o documentar claramente sus propósitos y reglas de consistencia.
7. Cerrar/superceder ramas y PRs antiguos que ya fueron absorbidos por 0.45.x.

### P2

8. Inventariar duplicados raíz vs `hemocura-core/` y declarar fuente de verdad por módulo.
9. Eliminar archivos accidentales/legacy sólo tras confirmar que no son importados.
10. Crear fingerprint visible de frontend commit + schema baseline + versión de release.

## 6. Guardrails que permanecen obligatorios

- No determinar automáticamente elegibilidad del donante.
- No inferir resultados de tamizaje.
- No determinar automáticamente compatibilidad transfusional.
- No liberar automáticamente componentes sanguíneos.
- Toda liberación clínica requiere acción humana autorizada.
- No exponer `service_role` ni secretos en GitHub Pages.

## 7. Gate de salida de I-001

I-001 se considera **COMPLETA como auditoría** cuando:

- [x] commit frontend baseline identificado;
- [x] CI y Pages del commit verificados;
- [x] proyecto Supabase correcto identificado;
- [x] estado RLS medido;
- [x] Security Advisor capturado;
- [x] drift GitHub/Supabase identificado;
- [x] riesgos P0/P1/P2 documentados;
- [ ] documento fusionado a `main` mediante PR.

## 8. Próxima iteración segura

**I-002 · Reconciliación de versión, manifest y backend drift.**

Orden recomendado:

`snapshot schema actual -> comparar con main/PR #5 -> clasificar diferencias -> reconciliar migraciones -> actualizar manifest -> ejecutar CI/Doctor -> sólo entonces continuar hardening`.

No ejecutar migraciones destructivas durante I-002 sin preflight, rollback y evidencia de compatibilidad.