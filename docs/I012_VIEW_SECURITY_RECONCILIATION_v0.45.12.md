# HemoCura I-012 · View Security Reconciliation · v0.45.12 RC

Fecha de corte: 2026-10-10
Proyecto Supabase: `tiothqiljipdamgudvcb`
Estado: `PASS_PREPARED_NOT_APPLIED`

## Objetivo

Reconciliar el bloque C13-B existente contra el esquema real de Supabase antes de cualquier cambio de permisos o semántica de vistas.

Esta iteración es de preflight y preparación. No aplica C13-B1 ni C13-B2, no cambia RLS, no modifica grants, no toca datos productivos y no altera guardrails clínicos.

## Estado observado en Supabase

- Views en `public`: 82.
- Views con `security_invoker=true`: 15.
- Views con privilegios del owner por no tener `security_invoker=true`: 67.
- Views con `SELECT` efectivo para `anon`: 82/82.
- Views con `SELECT` efectivo para `authenticated`: 82/82.
- Owner de las views observadas: `postgres`.

El Security Advisor y el inventario SQL coinciden en las 67 views owner-privilege.

## Clasificación de las 67 views owner-privilege

- Clinical/Blood: 13.
- Operations/BI: 7.
- QMS/Governance: 20.
- Security/Release/Diagnostic: 17.
- Other/technical: 10.

La clasificación es operativa para priorización; no autoriza conversiones masivas.

## Reconciliación del bloque C13-B existente

El repositorio ya contiene:

- `sql/C13B_00_PREFLIGHT_SECURITY_DEFINER_VIEWS.sql`
- `sql/C13B_01_REVOKE_ANON_OWNER_VIEWS_CANDIDATE.sql`
- `sql/C13B_02_SECURITY_INVOKER_CRITICAL_VIEWS_CANDIDATE.sql`
- `sql/C13B_03_RELEASE_READINESS_INVOKER_CANDIDATE.sql`
- `sql/C13B_91_VALIDATE_REVOKE_ANON_OWNER_VIEWS.sql`
- `sql/C13B_92_VALIDATE_SECURITY_INVOKER_CRITICAL_VIEWS.sql`

I-012 fortalece el preflight para medir no solo la exposición sino también la compatibilidad directa de los 10 targets críticos de C13-B2.

## Targets críticos C13-B2

1. `vw_app_migration_readiness`
2. `vw_blood_flow_status`
3. `vw_blood_inventory_available`
4. `vw_cold_chain_excursions`
5. `vw_hemovigilance_summary`
6. `vw_my_access`
7. `vw_my_security_context`
8. `vw_release_1_0_readiness`
9. `vw_screening_release_queue`
10. `vw_uat_summary`

Resultado del preflight real:

- Targets esperados: 10.
- Targets presentes: 10.
- Targets con compatibilidad directa: 10/10.
- Dependencias directas sin `SELECT` para `authenticated`: 0.
- Tablas base directas sin RLS: 0.

Resultado: `PASS_PREPARED_NOT_APPLIED`.

## Decisión de implementación

No ejecutar C13-B todavía fuera de la secuencia de remediación aprobada. La superficie anónima es crítica, pero la corrección debe respetar el orden de dependencias existente para evitar romper frontend, RPCs o diagnósticos de release.

C13-B1 mantiene su función como primera fase de views: retirar `anon` de views owner-privilege sin cambiar todavía la semántica para usuarios autenticados. C13-B2 permanece como conversión gradual de 10 views críticas a `security_invoker=true`.

## Gate para futura aplicación

Antes de aplicar C13-B1/B2 deben cumplirse las dependencias previas del plan de remediación vigente. Después de cada cambio se debe ejecutar su validator real y volver a ejecutar Security Advisor / Release Doctor.

No declarar C13-B como validado solo porque este preflight sea PASS.

## Referencia técnica

Supabase/Postgres 15+ recomienda `security_invoker=true` para que una view use los permisos del rol invocante y respete RLS de sus tablas subyacentes. La aplicación en HemoCura será gradual y controlada, no masiva.
