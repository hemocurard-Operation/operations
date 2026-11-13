# HemoCura v0.67.0 — Release Notes

**Fecha:** 2026-11-14
**Canal:** RC (`clinical_core: LIVE-LIMITED / CONTROLLED_RELEASE`)
**Base:** `main` tras merge del PR #83 (commit `61fa522`).

---

## Qué trae v0.67.0

**Entregable 14 del prompt §20 (Registro de cambios).** Esta versión amplía HemoCura v11 con infraestructura para 7 áreas del prompt maestro que no existían operativamente:

### Datos nuevos (14 migraciones aditivas)

1. `20261113120000_cleaning_module` — Limpieza de equipos (§5.8).
2. `20261113140000_predictive_meta` — Metadata de predicción (§11).
3. `20261113160000_donor_status_enum` — Estados ampliados de donante (§6.1b).
4. `20261113180000_equipment_usage` — Preventivo por consumo (§5.4/§5.6).
5. `20261113200000_donation_interval_rules` — Intervalos clínicos configurables (§6.2).
6. `20261113220000_commercial_visit_purpose` — Tipificación de visitas (§9).
7. `20261114000000_accounts_payable` — **Cuentas por Pagar** (§10, crítica).
8. `20261114020000_cash_flow_projection` — Proyección de caja 30/60/90 (§10).
9. `20261114040000_facility_licenses` — Habilitaciones sanitarias (§8).
10. `20261114060000_regulatory_matrix` — Matriz regulatoria RD (§8).
11. `20261114080000_budgets` — Presupuesto vs real (§10).
12. `20261114100000_daily_reports` — Reporte diario donantes y conciliación (§6.4/§10).
13. `20261114120000_closing_batch` — L3 expediente + CM1 metas + BI2 forecast insumos + BI4 outlook donantes.
14. `20261114140000_expense_forecast` — Proyección de gastos (§11).

### Rutas nuevas en el router

- `#cleaning` — Limpieza de equipos.
- `#payables` — Cuentas por Pagar.
- `#budgets` — Presupuestos y ejecución.
- `#regulatorymatrix` — Matriz regulatoria RD.
- `#licenses` — Habilitaciones sanitarias.
- `#commercialgoals` — Metas comerciales.

### Workflows CI nuevos (18)

5 de verificación de escenarios críticos §17: `blood-traceability`, `rls-cross-branch`, `idempotency`, `lab-safety-alerts`, `cleaning-module`.

13 por cada migración: `predictive-meta`, `donor-status-enum`, `equipment-usage`, `donation-interval-rules`, `commercial-visit-purpose`, `accounts-payable`, `cash-flow-projection`, `facility-licenses`, `regulatory-matrix`, `budgets`, `daily-reports`, `closing-batch`, `expense-forecast`.

### Documentación

12 auditorías temáticas en `docs/AUDITORIA_v11_*.md` + 2 planes ejecutivos (`PLAN_EJECUTIVO_v11.md`, `PLAN_EJECUTIVO_v11_PROGRESO.md`).

---

## Instrucciones para despliegue

**IMPORTANTE:** los commits en `main` **no activan automáticamente** las nuevas tablas en Supabase. Hay que aplicar las migraciones manualmente en orden cronológico:

```bash
supabase db push --project-ref tiothqiljipdamgudvcb
```

o con `psql` ejecutando `supabase/migrations/20261113*.sql` y `20261114*.sql` en orden alfabético.

**Después de aplicar:**

1. **Firmar aprobadores:**
   - `regulatory_requirements.approved_by` — 11 normas RD (un oficial de cumplimiento revisa cada una).
   - `donation_interval_rules.approved_by` — 7 tipos clínicos (médico autorizado firma).
   - `budgets.approved_by` — por período aprobado por gerencia.
   - `commercial_goals.approved_by` — por meta aprobada por gerencia comercial.

2. **Correr los 18 workflows nuevos** contra `main` para confirmar estado verde contra postgres:17 desechable.

3. **Verificar en preview:**
   - Las 6 rutas nuevas cargan.
   - Un usuario de Santiago no ve registros de Puerto Plata.
   - `predictive.js` muestra la metadata bajo cada card.

---

## Brechas aún abiertas

Documentadas en `docs/PLAN_EJECUTIVO_v11_PROGRESO.md`. Resumen:

### Decisión no-técnica (bloqueadas por autorización)

- **Q1** Motor genérico de formularios — decisión de modelo (riesgo clínico).
- **D2** Cuadre de buscones/captadores — requiere revisión legal institucional (§6.5).
- **C3** Compliance cámara hiperbárica — requiere investigación legal RD.

### Acceso operativo (Sprint 0)

- **S1** MFA/session/password policy — configuración Supabase Auth.
- **S2** Prueba de restauración de backup — operativo externo.
- **Verificaciones vivas:** correr `C11_91_SECURITY_DOCTOR_READONLY.sql` y `C12_00_PREFLIGHT_SECURITY_HARDENING.sql`, probar trazabilidad end-to-end contra DB viva.

### Ampliación pesada

- **Q2** PDF firmado — requiere ~500 KB de bundle, análisis de `ux-performance-budget`.
- UIs ampliadas para módulos (el patrón es claro, trabajo mecánico).

---

## Qué sigue en v0.68

Según plan ejecutivo, el próximo ciclo cierra:

1. Sprint 0 completo tras habilitarse SQL read-only.
2. Resolución de las 3 brechas bloqueadas (Q1, D2, C3) tras decisión del owner.
3. Expansión de UIs: scoring del planner (integrando `commercial_goals`), dashboard de alertas regulatorias, y vista unificada `#financedashboard` con CxP + CxC + cash flow + budgets.

---

## Autoría

PR #83 construido y fusionado bajo autorización ejecutiva del owner (`Autorizado`, `Haz todo lo necesario para completar la tarea sin depender de mi respuesta`, `Fusionar, publica los cambios realizados`). Co-authored-by: Claude Opus 4.7.
