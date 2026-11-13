# Auditoría §12 Modelo de datos + §15 Seguridad y Protección de datos

**Fecha:** 2026-11-13
**Base:** `origin/claude/vibrant-babbage-8q8oc8` tras §11 BI (`a7faf71`)
**Alcance:** §12 Modelo de datos (tablas, restricciones, trazabilidad) + §15 Seguridad (auth, RLS, audit, protección).
**Método:** lectura de funciones `can_access_branch`, `has_permission`, `wf_active_actor`, trigger `qms_guard`, scripts `C11_91_SECURITY_DOCTOR_READONLY.sql` y `C12_00_PREFLIGHT_SECURITY_HARDENING.sql`, migraciones de hardening, CSP en `index.html`.

---

## §12 Modelo de datos — cobertura vs prompt

### Entidades del prompt mapeadas al código

| Prompt §12 bloque | Tablas reales | Estado |
|---|---|---|
| **Organización** (branches, users, roles, permissions, user_branch_access) | `branches`, `profiles`, `roles`, `app_permissions`, `role_permissions`, `user_roles(user_id, role_id, branch_id)` | ✅ |
| **Laboratorio** (equipment, usage, maintenance, temp, cleaning, tasks) | `laboratory_equipment`, `maintenance_plans`/`_records`, `storage_devices`, `storage_excursions`, `temperature_readings`, `work_tasks` | ⚠ **falta cleaning_* (§5.8)** y `equipment_usage` (§5.6) |
| **Inventario** (products, lots, blood_units, movements, balances, alerts) | `products`, `product_lots`, `blood_units`, `inventory_movements`, `inventory_balances`, `vw_stock_risk_projection` | ✅ |
| **Donantes** (donors, eligibility, donations, deferrals, appointments, referrals) | `donors`, `donations`, `donor_contacts`, `donor_visits`, `donor_lab_comments` | ⚠ **falta donor_referrals (§6.5)** |
| **Logística** (transport_requests, services, events, deliveries, returns, payments) | `transport`, `dispatches`, `team_deliveries`, `extra_trips` | ✅ |
| **Calidad** (forms, versions, submissions, incidents, NC, CAPA, audits) | `nonconformities`, `capa`, `audit_programs`, `internal_audits`, `audit_findings`, `audit_evidence`, `branch_inspections`, `inspection_findings`, `hemovigilance_events`, `product_recalls` | ⚠ **falta motor genérico de forms (Q1)** |
| **Compliance** (regulatory_requirements, evidence, trainings, training_records) | `compliance_penal_requirements`/`_assessments`/`_actions`, `iso_clause_assessments`/`_evidence`, `training_events`, `training_participation`, `competency_catalog`, `competency_assessments` | ⚠ **falta matriz regulatoria general (C1)** |
| **Comercial** (crm_contacts, accounts, sales, items, visit_rules, visits, promotional_tasks) | `crm_contacts`, `crm_activities`, `crm_history`, `crm_visit_rules`, `crm_weekly_visits`, `commercial_calendar`, `congresses`, `customers`, `sales` | ⚠ **falta commercial_goals + crm_opportunities (CM1)** |
| **Finanzas** (suppliers, quotations, requisitions, POs, expenses, receivables, payables, reconciliations) | `suppliers`, `supplier_quotations`, `quotation_decisions`, `requisitions`, `purchase_orders`, `purchase_receipts`, `monthly_cost_periods`, `cost_entries`, `collections` | ❌ **falta payables / payments (F1)** · **falta budgets (F3)** · **falta cash_flow_projection (F2)** |
| **Auditoría** (audit_events, attachments, notifications) | `audit_events`, `access_events`, `qms_change_history`, `work_task_history`, `donor_visit_history`, `lab_event_log` | ✅ Múltiples historiales |

### Integridad y trazabilidad

- **Claves foráneas con `on delete restrict`** en `compliance_penal_assessments.requirement_id`, `donor_visits.donor_id`, `crm_contacts.customer_id`, etc. — evita huérfanos.
- **UNIQUE parciales** correctos:
  - `donor_identity_cedula_unique on donors(cedula) where cedula is not null` (donante puede no tener cédula, pero si la tiene es única).
  - `donor_visit_active_unique on donor_visits(donor_id) where status in ('POR_CONFIRMAR','CONFIRMADA')` (no dos visitas activas).
  - `crm_referrer_identity on crm_contacts(branch_id, referrer_id) where referrer_id is not null`.
- **Revisión concurrente** vía `revision integer` en 8+ tablas (`donor_visits`, `crm_contacts`, `crm_visit_rules`, `crm_weekly_visits`, `nonconformities`, `sgc_projects`, etc.).
- **Checks de dominio** sólidos: ABO/Rh enum, `cedula ~ '^[0-9]{11}$'`, `representative_limit between 1 and 100`, `slots jsonb_array_length <= 14`, teléfono normalizado antes de insertar.

### Trazabilidad end-to-end de una unidad sanguínea

**Camino teórico según schema:** `donations` (con `donor_id`, `collection_effective`) → `blood_units` (con `donation_id`) → `screenings` → `blood_units.release_decision` → `inventory_movements` → `dispatches` / `sales` → `recall_units` si hay retiro.

**🔎 Lo que NO pude verificar sin DB viva:**
1. Que cada `blood_unit` tenga `donation_id NOT NULL`.
2. Que un dispatch verifique `screening_status='APROBADO'` antes de aceptar la salida.
3. Que un retiro desde `hemovigilance_events` propague correctamente a todas las unidades hijas del lote.

---

## §15 Seguridad — cobertura vs prompt

| Prompt §15 bullet | Implementación | Estado |
|---|---|---|
| Autenticación | Supabase Auth (JWT, email+password) | ✅ |
| Autorización por roles | `has_permission(permission_code)` + `role_permissions` + `app_permissions.active` | ✅ |
| Permisos por sucursal | `can_access_branch(target_branch)` + `user_roles.branch_id` | ✅ |
| Restricción de datos clínicos | RLS granular: `DONORS_VIEW` separado de `SCREENING_WRITE`; `donor_lab_comments` solo con permiso técnico | ✅ |
| Registro de auditoría | `audit_events`, `access_events`, `qms_change_history`, `lab_event_log`, trigger `qms_audit` | ✅ |
| Protección de sesiones | Delegado a Supabase Auth; no vi configuración explícita de timeout o rotación | 🔎 Verificar config Supabase |
| Validación de entradas | `private.crm_clean`, `private.crm_phone`, CHECKs en DB, `aria-invalid` en frontend | ✅ |
| Prevención SQL injection | Uso consistente de `sb.from().select()` parametrizado y RPCs con `set search_path=public,pg_temp` | ✅ |
| Protección XSS/CSRF | CSP estricta (`index.html`): `script-src 'self' 'wasm-unsafe-eval'`; `esc()` helper por módulo escapando `<>&"'`; CSRF implícito en JWT bearer (Supabase no usa cookies) | ✅ |
| Gestión segura de secretos | `js/config.js` protegido, `config.example.js` como plantilla; `admin-users` edge function tiene `change_password` | ✅ |
| Copias de seguridad / recuperación | `.github/workflows/private-database-backup.yml` + `supabase/migrations/20261107181249_web_performance_security.sql` | 🔎 Verificar política y restauración probada |
| RLS en todas las tablas expuestas | Grep de `enable row level security` da **~150+ tablas con RLS**. `C12_00_PREFLIGHT_SECURITY_HARDENING.sql` detecta policies `cmd='ALL' with authenticated` demasiado anchas | ✅ con doctor |
| Usuario de una sucursal no accede a otra | `can_access_branch` + legacy fallback; RLS por `branch_id` en todas las tablas operativas | ✅ en teoría — 🔎 test en vivo |

### Protecciones específicas detectadas

- **`wf_active_actor()`**: función que verifica actor activo antes de cualquier policy. Previene que un usuario deshabilitado siga operando con sesión caliente.
- **SUPER_USUARIO** es explícito y auditable; no es un alias oculto de root.
- **`ACCESS_ADMIN`** permiso crítico **excluido** del flujo normal de `has_permission` — solo SUPER_USUARIO lo recibe. Buena decisión.
- **`private.legacy_can_access_branch`** mantiene compatibilidad hacia atrás clonando el código anterior en schema privado — permite revertir si la nueva versión tiene bug.
- **Trigger `qms_guard`**: segregación de funciones a nivel DB (no se puede cerrar NC si eres el owner y no hay revisor independiente).
- **`storage_excursions` auto-detection**: temperaturas fuera de rango generan evento automático con prioridad CRITICA — no depende del operador.
- **`audit_events` con `before_data` + `after_data`**: diff completo, no solo flag binario.
- **Daily report migration (2026-11-09)**: lock del padre previene race condition al adjuntar foto a reporte cerrado.

---

## Brechas

### Brecha S1 — MFA / sesión / política de contraseñas
**Severidad:** Media-alta para una app clínica.
**Qué falta en código:** no vi referencia a MFA habilitado, session timeout, password complexity, rate limiting en login.
**Dónde debería estar:** panel de Supabase Auth → Config. No en migraciones.
**Trabajo:** documentar y auditar la configuración actual en Supabase; no hay que escribir código, pero sí evidencia.

### Brecha S2 — Prueba de restauración de backup
**Severidad:** Media-alta.
**Qué veo:** workflow `private-database-backup.yml` existe. **No vi** evidencia de `restore drill` documentado (último ejercicio de restauración validado).
**Trabajo:** correr ejercicio periódico y documentar en `docs/`. Operativo, no código.

### Brecha S3 — `audit_events` completitud entre módulos
**Severidad:** Media.
**Observación:** `qms_audit` cubre 6 entidades QMS. `lab_event_log` cubre lab. `crm_history` cubre CRM. `work_task_history` cubre agenda. **Pero** no veo auditoría centralizada de operaciones financieras (`sales`, `collections`, `purchase_orders`, `cost_entries`) — ¿se escriben a `audit_events`?
**Trabajo:** verificar en vivo o añadir triggers si faltan.

### Brecha S4 — RLS en vistas predictivas
**Severidad:** Media.
**Observación:** las vistas `vw_predictive_*` usan `with (security_invoker=true)` en algunos casos. Las que **no** lo usan heredan permisos del creador, no del lector — riesgo si un usuario con menos privilegios consulta una vista basada en tablas sensibles.
**Trabajo:** grep + añadir `security_invoker=true` donde falte.

### Brecha S5 — Contraseña en edge function
**Severidad:** Media.
**Observación:** `supabase/functions/admin-users/index.ts` expone `change_password`. No vi por aquí si:
- Requiere contraseña anterior o solo admin override.
- Emite `audit_events` del cambio.
- Rate-limita intentos.
**Trabajo:** verificar función.

---

## 🔎 Verificaciones vivas prioritarias (bloqueantes para firmar §15)

1. **Trazabilidad end-to-end de una unidad sanguínea**: insertar donación, tamizar, liberar, despachar, retirar — y confirmar que `audit_events` tiene las 5 filas correctamente ligadas.
2. **RLS cross-sucursal**: usuario de Santiago, usuario de Puerto Plata, cada uno hace SELECT en `blood_units`, `donations`, `collections` — confirmar aislamiento.
3. **Correr `C11_91_SECURITY_DOCTOR_READONLY.sql`** y revisar policies ALL demasiado anchas.
4. **Correr `C12_00_PREFLIGHT_SECURITY_HARDENING.sql`** y revisar roles faltantes (`ENCARGADA_LABORATORIO`, `TI`) + duplicate signers + policies anchas.
5. **Última restauración de backup**: fecha y resultado.
6. **Supabase Auth config**: MFA, session duration, password policy.

---

## Veredicto global §12 + §15

**Modelo de datos (§12):** cobertura cercana a 100% de las entidades del prompt, con las brechas ya listadas en auditorías previas (donor_referrals, cleaning, payables, forms genéricos, regulatory_requirements, commercial_goals). Integridad referencial sólida, revisión concurrente, UNIQUE parciales inteligentes, CHECKs de dominio reales.

**Seguridad (§15):** **uno de los módulos más maduros** del repo. RLS consistente, funciones security-definer con `set search_path` correcto, segregación de funciones a nivel de DB, CSP estricta, audit trail en ≥4 tablas, CHECKs en entrada, SUPER_USUARIO auditable, `wf_active_actor()` como primer guardia, storage_excursions automático. Los scripts `C11_91` y `C12_00` demuestran que el equipo ya tiene disciplina de doctor read-only.

**Lo que falta es ejecutar las verificaciones vivas** — este audit no puede firmar §15 sin corroborar la implementación contra la DB y la config de Supabase.

---

## Propuesta de siguiente acción

**PR-SEC1 (bajo)** — correr `C11_91` + `C12_00`, snapshotear salida como `docs/C11_91_doctor_report_2026-11-13.md` y `docs/C12_00_preflight_report_2026-11-13.md`. Es evidencia, no código. Requiere acceso SQL read-only.

**PR-SEC2 (medio)** — test de trazabilidad end-to-end en workflow CI: insertar donación de prueba, recorrer el flujo completo, verificar `audit_events`. Workflow `.yml` + script de prueba.

**PR-SEC3 (bajo)** — documento `docs/SUPABASE_AUTH_CONFIG_2026-11-13.md` con snapshot de la configuración de Auth (sin secretos). Requiere acceso al panel de Supabase.

---

## Pregunta de bloqueo

1. ¿Me das acceso SQL read-only a Supabase para correr `C11_91` + `C12_00` (PR-SEC1) y cerrar las 6 verificaciones vivas prioritarias?
2. ¿Hay ya un snapshot de la configuración de Auth (MFA, session, password policy) que yo pueda leer?
3. ¿Está ya documentada la última prueba de restauración de backup?
