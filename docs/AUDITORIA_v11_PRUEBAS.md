# Auditoría §17 Pruebas obligatorias — estado real

**Fecha:** 2026-11-13
**Base:** rama tras `75f6a42`
**Alcance:** los 10 bullets de pruebas por módulo + 9 escenarios críticos del prompt §17.
**Método:** inventario de `.github/workflows/` (40 archivos), `tests/` (29 carpetas + 23 smokes), `tools/` (linters), `sql/C11_90_VALIDATE_FRONTEND_BACKEND.sql`, `sql/C11_91_SECURITY_DOCTOR_READONLY.sql`.

---

## 1. Infraestructura de pruebas existente

| Capa | Realidad |
|---|---|
| **Workflows CI** | 40 en `.github/workflows/` — safety suites (`*-safety.yml`) por dominio, smoke frontend, performance budget, migration security linter, runtime contract gate, release readiness doctor |
| **Tests por módulo** | 29 carpetas en `tests/` — agent-followup, area-agenda, commercial-agenda, coordination, crm, crm-planner, daily-photo, donors, improvement-agents, inventory-output, job-roles, lab-management, logistics-*, module-views, procurement, qms, quotations, release, roles, security, sgc-implementation, team-deliveries, twelve-week, username-accounts, wave50 |
| **Smoke tests** | 23 archivos `SMOKE_TESTS_*.md` versionados por release (0.20 → 0.44) |
| **Concurrency** | `tests/area-agenda/concurrency.py`, `tests/commercial-agenda/concurrency.py` |
| **Business rules** | `tests/*/business-rules.sql` para area-agenda, logistics-roles, twelve-week |
| **Doctor scripts** | `C11_90` validate frontend↔backend, `C11_91` security doctor read-only, `C12_00` preflight hardening |

---

## 2. Mapeo de los 10 bullets del prompt §17 contra workflows

| Bullet prompt §17 | Cobertura |
|---|---|
| 1. Creación de registros | Cubierto implícitamente en `commercial-crm.yml`, `donor-management.yml`, `lab-management.yml`, `purchase-receiving.yml`, `twelve-week.yml`, `sgc-implementation.yml` |
| 2. Edición | Idem; revisión concurrente con `revision integer` en 8+ tablas garantiza detección de conflictos |
| 3. Consulta | Smoke frontend (`frontend-browser-smoke.yml`) lista rutas; `frontend-source-truth.yml` verifica contratos |
| 4. Validación | `migration-security-linter.yml`, `runtime-contract-gate.yml`, CHECKs en DB, `aria-invalid` en frontend |
| 5. Restricciones de permisos | `super-user-access.yml`, `role-module-views.yml`, `users-admin-safety.yml`, `tests/security/`, `tests/roles/` |
| 6. Integridad referencial | `migration-security-linter.yml` — grep de patrones FK/RLS; `tests/*/business-rules.sql` |
| 7. Operaciones simultáneas | `tests/area-agenda/concurrency.py` + `tests/commercial-agenda/concurrency.py` — **solo 2 dominios cubiertos** |
| 8. Exportación e impresión | ❌ **No encontré workflow específico** — `labReport` y exports comerciales no tienen smoke test propio |
| 9. Errores y recuperación | `tests/release/` + `release-readiness-doctor.yml` cubre gates de release; errores de boot cubiertos por `frontend-browser-smoke` |
| 10. Auditoría | ❌ **No encontré test dedicado** que verifique que un cambio deja `audit_events` correcto |

---

## 3. Mapeo de los 9 escenarios críticos del prompt §17 contra pruebas reales

| # | Escenario crítico | Dónde se prueba | Estado |
|---|---|---|---|
| 1 | Una unidad sanguínea no puede despacharse dos veces | `tests/release/`, `tests/lab-management/`, trigger `qms_guard` indirecto. **No vi test explícito "intentar doble dispatch"** | ⚠ Parcial |
| 2 | Un equipo con temperatura fuera de rango genera una alerta | Migración `20261104174434_production_security_privacy_readiness.sql` tiene auto-detection de `storage_excursions`. **Test dedicado no visible** | ⚠ Parcial |
| 3 | Una lectura inválida no se acepta | CHECKs en DB (temp range, enum) + `private.crm_clean` + `aria-invalid`. **Test negativo específico no visible** | ⚠ Parcial |
| 4 | Un mantenimiento vencido se identifica | `labSignals` + `next_maintenance_date`. No vi workflow que lo ejercite. | ⚠ Parcial |
| 5 | Una sucursal no puede consultar datos restringidos de otra | `tests/security/` existe. **🔎 verificar si cubre RLS cross-sucursal con usuarios reales** | 🔎 Verif viva |
| 6 | Una venta actualiza correctamente sus registros relacionados | `tests/qms/`, `commercial-crm.yml`, workflow `purchase-receiving.yml`. Transacciones en RPC ya aisladas. | ✅ |
| 7 | Una donación no puede duplicarse por reintentos | `crm_requests(actor_id, request_id)` idempotency confirmada; `donor_visit_active_unique` evita 2 activas. **Falta test "mismo request_id dos veces"** | ⚠ Parcial |
| 8 | Una no conformidad conserva su historial | `qms_change_history` + trigger `qms_audit` cubren 6 entidades. Workflow `quality-information.yml` existe. | ✅ |
| 9 | Un usuario sin autorización no puede aprobar su propio registro cuando se requiera segregación de funciones | **Segregación a nivel DB** vía `qms_guard` (revisor ≠ owner); `inspection_finding_create_capa` separa autor de aprobador. Tests existen en `tests/qms/`. | ✅ |

---

## 4. Brechas de pruebas detectadas

### Brecha T1 — **Trazabilidad end-to-end de unidad sanguínea** (prompt §17 escenario 1)
**Severidad:** Alta — es el escenario crítico #1 del prompt.
**Qué falta:** workflow CI que insertó donación → tamizaje → liberación → inventario → despacho → retiro, y verifique cada paso con assertions.
**Trabajo:** `.github/workflows/traceability-blood-unit.yml` con script Python que:
1. Crea un donante de prueba.
2. Registra donación con `collection_effective=true`.
3. Crea `blood_unit` ligada.
4. Registra tamizaje `NO_REACTIVO`.
5. Marca liberación (`release_decision='APTO'`).
6. Crea movimiento de inventario.
7. Despacha a cliente.
8. Intenta despachar segunda vez → **debe fallar**.
9. Dispara `product_recall` → verifica que `recall_units` incluye la unidad.
10. Verifica `audit_events` tiene las 7–8 filas ligadas por `entity_reference`.

### Brecha T2 — **RLS cross-sucursal con usuarios reales** (prompt §17 escenario 5)
**Severidad:** Alta.
**Qué falta:** test que cree 2 perfiles (Santiago-user, PuertoPlata-user) y verifique que cada uno al hacer SELECT sobre `blood_units`, `donations`, `collections`, `customers` **solo ve filas de su branch**. Y que super_usuario ve todas.
**Trabajo:** workflow Python con Supabase client autenticando a cada JWT y assertions.

### Brecha T3 — **Idempotency formal** (prompt §17 escenario 7)
**Severidad:** Media.
**Qué falta:** test que invoque la misma mutación 2 veces con el mismo `request_id` y confirme que solo crea 1 registro. Hoy el patrón existe (`crm_requests`, `crm_weekly_visits.request_id unique`) pero no se ejercita en CI.
**Trabajo:** script que cubra `crm_plan_action`, `createDonation`, `createDispatch`.

### Brecha T4 — **Auditoría como test** (prompt §17 bullet 10)
**Severidad:** Media.
**Qué falta:** test que valide que operar sobre tablas críticas (`sales`, `collections`, `cost_entries`, `purchase_orders`) deja fila en `audit_events` con `before_data`/`after_data` no nulos. Depende de Brecha S3 del §15.
**Trabajo:** workflow Python + queries de verificación.

### Brecha T5 — **Exportación / impresión** (prompt §17 bullet 8)
**Severidad:** Baja.
**Qué falta:** smoke de que `downloadText` del informe gerencial de `laboratory.js` produce archivo no vacío; que `collections` export CSV funciona; que PDF (si llega Q2) rendea.
**Trabajo:** test headless con el browser smoke actual.

### Brecha T6 — **Alertas negativas** (escenario #2, #3, #4)
**Severidad:** Media.
**Qué falta:** scripts que ingresen una lectura de temperatura fuera de rango y verifiquen que se crea `storage_excursions` y se dispara `audit_events` con prioridad CRITICA.
**Trabajo:** workflow `lab-safety-alerts.yml` con escenarios negativos y positivos.

### Brecha T7 — **Smoke tests versionados dejaron de actualizarse** (observación)
**Severidad:** Baja.
**Observación:** `tests/SMOKE_TESTS_*.md` llega a v0.44, pero la versión actual es v0.66. Hay un gap de 22 versiones sin smoke actualizado.
**Trabajo:** reconsolidar smoke tests como un solo `tests/SMOKE_TESTS.md` vivo, versionado por git — no por nombre de archivo.

---

## 5. Fortalezas

- **Concurrency tests** para dominios más expuestos a race (area-agenda, commercial-agenda).
- **`tests/security/`** dedicado — aunque falta cubrir RLS cross-sucursal con usuarios reales.
- **Business rules en SQL** (`tests/*/business-rules.sql`) permiten validar triggers y CHECKs sin frontend.
- **`frontend-browser-smoke.yml`** garantiza que la app arranca y cada ruta monta. Base buena para extensión.
- **40 workflows** por dominio con nomenclatura consistente (`*-safety.yml`).
- **Doctor read-only** en producción (`C11_91`, `C12_00`) permite verificar seguridad sin mutar.
- **Concurrency.py** — el patrón ya está aplicado. Replicarlo en más dominios es trabajo mecánico.

---

## 6. Verificaciones vivas pendientes (para firmar §17)

1. ¿`tests/security/` cubre RLS cross-sucursal con JWTs reales?
2. ¿`tests/release/` ejercita el escenario "doble dispatch"?
3. ¿Existe un workflow de regresión end-to-end más allá de los safety suites por dominio?
4. ¿Qué rutas del router smoke actualmente fallan? (El workflow lista pero no vi su último report).

---

## 7. Veredicto global §17

**Infraestructura de pruebas rica y disciplinada** — 40 workflows, 29 dominios con tests dedicados, concurrency en 2 dominios, business rules SQL, smoke frontend, doctor read-only.

**Los 10 bullets genéricos** del prompt están cubiertos salvo **8 (export/print) y 10 (auditoría dedicada)**.

**Los 9 escenarios críticos** están cubiertos parcialmente — solo 3 de los 9 tienen prueba dedicada evidente (ventas relacionadas, historial NC, segregación de funciones). Los 6 restantes están respaldados por constraints/triggers de DB pero sin test que los ejercite explícitamente.

**El gap mayor es trazabilidad end-to-end de la unidad sanguínea** (escenario crítico #1 + bullet de auditoría + RLS cross-sucursal) — ya identificado en §15 como bloqueador del Sprint 0 del plan ejecutivo.

---

## 8. Propuesta — Sprint 1b (dentro del Sprint 1 del plan ejecutivo)

Todos bajos en riesgo (tests no tocan producción) y altos en valor:

- **PR-T1** — `traceability-blood-unit.yml` + script. Resuelve Brecha T1 y escenario #1 del prompt.
- **PR-T2** — `rls-cross-branch.yml` + fixtures de 2 usuarios. Resuelve Brecha T2 y escenario #5.
- **PR-T3** — `idempotency.yml` cubriendo 3 RPCs. Resuelve Brecha T3 y escenario #7.
- **PR-T6** — `lab-safety-alerts.yml` positivo+negativo. Resuelve Brecha T6 y escenarios #2/#3/#4.
- **PR-T7** — reconsolidar `tests/SMOKE_TESTS.md` como archivo vivo único.

Trabajo de `T4` depende de Brecha S3 (auditoría financiera) — se difiere a cuando se decida ese cambio.
Trabajo de `T5` es menor — se puede añadir a cualquier PR que toque export.

---

## 9. Pregunta de bloqueo

1. ¿Autorizas abrir el bloque **PR-T1…T7** en el Sprint 1b? Son solo workflows y scripts, no tocan schema ni producción.
2. ¿Hay credenciales de pruebas (JWT de Santiago-user y PuertoPlata-user) que yo pueda usar en `PR-T2`, o las tengo que crear como parte del PR con permisos mínimos?
3. ¿El doctor script `C11_91` corre hoy en CI o solo manual? Si no corre, lo integro en `release-readiness-doctor.yml`.
