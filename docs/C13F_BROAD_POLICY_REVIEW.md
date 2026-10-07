# C13-F · Broad Policy Hardening · v0.44.13

## Evidencia real verificada en Supabase

Las seis policies `FOR ALL` amplias detectadas originalmente se dividen en dos grupos:

- cuatro (`release_signoffs`, `uat_test_runs`, `uat_test_cases`, `uat_test_results`) pertenecen a C12;
- dos permanecen fuera de C12 y son el objetivo de C13-F:
  - `audit_plan_criteria_access`;
  - `job_role_competencies_access`.

Ambas policies actuales permiten `ALL` a cualquier sesión `authenticated`.

### audit_plan_criteria

- 0 filas actuales.
- FK a `internal_audits` mediante `audit_id`.
- `internal_audits` ya tiene control por sucursal y roles.
- Permisos existentes:
  - `INTERNAL_AUDIT_VIEW`;
  - `INTERNAL_AUDIT_WRITE`.
- El frontend usa `upsert()` sobre `audit_plan_criteria`, por lo que necesita SELECT + INSERT + UPDATE, no DELETE directo.

### job_role_competencies

- 0 filas actuales.
- Es una matriz global puesto ↔ competencia.
- Permisos existentes:
  - `COMPETENCY_VIEW`;
  - `COMPETENCY_WRITE`.
- El frontend usa `upsert()` sobre `job_role_competencies`, por lo que necesita SELECT + INSERT + UPDATE, no DELETE directo.

## Diseño de C13-F

### Auditoría

- SELECT: `INTERNAL_AUDIT_VIEW` o `INTERNAL_AUDIT_WRITE` + alcance de la sucursal del audit padre.
- INSERT/UPDATE: `INTERNAL_AUDIT_WRITE` + alcance de la sucursal del audit padre.
- DELETE: no concedido al navegador.

### Competencias

- SELECT: `COMPETENCY_VIEW` o `COMPETENCY_WRITE`.
- INSERT/UPDATE: `COMPETENCY_WRITE`.
- DELETE: no concedido al navegador.

## Compatibilidad con GitHub

`hemocura-core/internal-audit-data.js` usa `upsert()` en `audit_plan_criteria` y `hemocura-core/competency-data.js` usa `upsert()` en `job_role_competencies`; el candidato mantiene exactamente los privilegios necesarios para esos flujos.

`hemocura-core/access-control.js` protege las rutas con `INTERNAL_AUDIT_VIEW` y `COMPETENCY_VIEW`, alineado con las nuevas policies.

## Archivos

- `sql/C13F_00_PREFLIGHT_BROAD_POLICIES.sql`
- `sql/C13F_01_BROAD_POLICY_HARDENING_CANDIDATE.sql`
- `sql/C13F_90_VALIDATE_BROAD_POLICY_HARDENING.sql`

## Gate

Estado: **GENERADO / NO APLICADO**.

No aplicar C13-F antes de cerrar C12, ya que C12 elimina las otras cuatro policies `ALL` amplias. Después de C12 + C13-F, el diagnóstico global debe devolver 0 policies `FOR ALL` basadas únicamente en `auth.role()='authenticated'` para las seis tablas identificadas.
