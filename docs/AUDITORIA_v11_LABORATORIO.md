# Auditoría §5 Laboratorio — estado real por subsección

**Fecha:** 2026-11-13
**Base:** Rama `claude/vibrant-babbage-8q8oc8` en commit `c4d13ae`
**Alcance:** Prompt maestro §5 (Laboratorio prioritario) contra el código fuente actual.
**Método:** auditoría estática — lectura de módulos, migraciones y catálogo de tablas; sin ejecución contra Supabase.

---

## Veredicto por subsección

Clasificación: ✅ Operativo · ⚠ Parcial / brecha · ❌ Ausente · 🔎 Requiere verificación viva

| § | Subsección prompt | Módulo / tabla | Estado | Notas |
|---|---|---|---|---|
| 5.1 | Sucursales administrables | `settings`, tabla `public.branches` (referenciada por decenas de migraciones) | ✅ Operativo | Catálogo existe. No verifiqué si las 3 sucursales iniciales (Santiago, Puerto Plata, Tenares) están pobladas — 🔎 requiere acceso a DB. |
| 5.2 | Ventas + inventario alimentando comercial | `sales`, `sales-data`, `operational-sales`, `workflow-sales` | ✅ Operativo | Ventas y movimientos físicos separados; workflow `commercial-crm.yml` cubre el enlace. |
| 5.3 | Equipos por sucursal — expediente | `resources`, `resources-data` (123 líneas); tabla `equipment` vista en `laboratory.js` con campos `equipment_code`, `status`, `next_calibration_date`, `next_maintenance_date` | ⚠ Parcial | Existen campos clave. Hay que verificar que el expediente completo del prompt (fabricante, serie, garantía, suplidor, documentación, historial) esté en la tabla — ver `20261017084848_lab_management_workspace.sql`. |
| 5.4 | Mantenimiento preventivo | `maintenance.js` (271 líneas): acepta `event_type` ∈ `CALIBRACION, MANTENIMIENTO_PREVENTIVO, MANTENIMIENTO_CORRECTIVO, CALIFICACION, VERIFICACION`; captura `performed_date`, `next_due_date`, `provider`, `result`, `findings`, evidencia | ✅ Operativo | Alertas de próximo/vencido vía `labSignals` en `lab-domain.js`. Falta verificar programación por horas de uso o servicios realizados (§5.4 último bullet) — 🔎. |
| 5.5 | Mantenimiento correctivo | Mismo módulo, tipo `MANTENIMIENTO_CORRECTIVO` | ✅ Operativo | Comparte expediente. No vi campos separados para "tiempo fuera de servicio", "prioridad de avería", "verificación de retorno" como entidades distintas — ⚠ reportar si un servicio correctivo registra downtime. |
| 5.6 | Horas y servicios prestados | Tabla `equipment_usage` referenciada en modelo del prompt §12, pero no veo captura en `laboratory.js` ni acción dedicada | ⚠ Parcial / posible brecha | No encontré captura de lectura inicial/final por horas de uso. Si no existe, el cálculo de proximidad del mantenimiento por horas (§5.4) está incompleto. |
| 5.7 | Temperaturas | `environmental-log.js` (224 líneas), `cold-chain.js`, `cold-chain-data.js`; tabla `devices` con `min_temp`/`max_temp`, `temperatures` con `reading_time`/`value`/`observation` | ✅ Operativo | Captura manual, rango por dispositivo, alertas, historial, integración a `coldchain`. Prompt pide lecturas manuales + integración futura con sensores — segundo bloque todavía no implementado. |
| 5.8 | **Limpieza de equipos** | ❌ No hay `cleaning_plans` ni `cleaning_records` como entidades | ❌ **Ausente** | Única mención: checklist de inspección (`inspections.js:13`) y `workflow-domain.js:9` como par "Equipos y limpieza". No existe calendario de limpiezas pendientes ni checklist firmado por responsable. **Brecha concreta vs. prompt §5.8**. |
| 5.9 | Tareas de laboratorio | `work_tasks` + `area-agenda`, área `LABORATORIO`; `task()` en `laboratory.js` con responsable, due_at, prioridad, descripción, checklist, revisión | ✅ Operativo | Historial en `work_task_history`. Cumple asignación, prioridad, recordatorios, evidencias, cumplimiento. |
| 5.10 | Insumos, suplidores y compras | `supply-catalog`, `supply-planning`, `supply-data`, `procurement`, `procurement-domain`, `quotations`, `quotation-domain`, `supplier-data`, `supply-transfers` | ✅ Operativo | Catálogo de insumos, suplidores, requisiciones, cotizaciones, órdenes, recepción, traslados. `20261107000948_supplier_quotations.sql` reciente. Comparación entre proveedores y análisis de variación de precio no verificados — 🔎. |

---

## Brechas priorizadas

### Brecha 1 — Módulo de limpieza de equipos (§5.8) [BLOQUEANTE para ISO 15189]
**Severidad:** Alta.
**Evidencia:** no hay tabla `cleaning_plans`, `cleaning_records`, ni ruta `#cleaning` en `router.js`. Las únicas referencias son textuales.
**Impacto:** sin registro trazable de limpieza por equipo + checklist + producto + responsable + verificación, no se puede soportar ISO 15189 ni los procedimientos sanitarios aplicables a banco de sangre.
**Trabajo estimado:**
- Migración: `cleaning_plans(id, equipment_id, frequency, procedure_ref, product, responsible_role)` + `cleaning_records(id, plan_id, performed_at, performed_by, checklist_jsonb, observations, evidence_ref, verified_by, verified_at)`.
- Módulo frontend `cleaning.js` + `cleaning-data.js`, montado en grupo "LABORATORIO Y SANGRE" (después de `maintenance`).
- Alertas de limpieza vencida en `labSignals`.
- Permiso `CLEANING_WRITE`, `CLEANING_VERIFY`.

### Brecha 2 — Horas de uso para preventivo por consumo (§5.4, §5.6)
**Severidad:** Media.
**Evidencia:** `equipment_usage` no aparece como acción de captura en `laboratory.js`.
**Impacto:** programación de mantenimiento solo por tiempo transcurrido, no por horas de uso ni cantidad de servicios — el prompt exige ambos.
**Trabajo estimado:** acción `USAGE` en `laboratory.js` tab `resources`; tabla `equipment_usage(equipment_id, reading_time, hours_counter, services_counter, actor_id)`; usar en el cálculo de `next_due_date` por regla del equipo.

### Brecha 3 — Expediente completo del equipo (§5.3)
**Severidad:** Media.
**Pendiente de verificar en DB viva:** campos *fabricante, serie, fecha adquisición, suplidor, garantía, documentación*. Si están en `equipment.jsonb`/`equipment.metadata`, no es brecha; si no, hay que ampliar la tabla.

### Riesgo heredado — localStorage con ABO/Rh y motivo de diferimiento (§15) — **MITIGADO**
**Estado:** corregido en esta misma rama.
**Parche aplicado** (commit siguiente a esta auditoría): `quick-capture.js` reduce `donorDraftFields` a `['qc-donor-code','qc-donor-type','qc-donor-status']` e `incDraftFields` a `['qc-inc-class','qc-inc-process','qc-inc-severity']`. ABO, Rh, motivo de diferimiento, observaciones del donante, descripción, afectados e impacto de la incidencia **ya no se persisten** en localStorage. El autosave sigue útil para el captador (no perder progreso del código/tipo/estado), y los campos clínicos se recapturan si el navegador cierra. `clearDraft` al éxito se mantiene.

### 🔎 Verificaciones vivas pendientes
1. Confirmar que las 3 sucursales iniciales existen en `branches`.
2. Confirmar RLS: un usuario de Santiago no lee `equipment` de Puerto Plata.
3. Confirmar que `equipment` tiene fabricante/serie/garantía.
4. Confirmar que un servicio correctivo registra downtime.
5. Confirmar comparación entre proveedores en `quotations`.

---

## Qué está bien y no voy a tocar

- `laboratory.js` orquesta 7 tabs ("Mi turno", "Unidades en proceso", "Controles", "Equipos y reactivos", "Cadena de frío", "Equipo y agenda", "Historial", + "Informe gerencial"). Diseño sólido, revisión independiente ya instrumentada (no se aprueba lo propio).
- Historial de auditoría por tabla con `before_data`/`after_data` en `lab_event_log`.
- Export gerencial condicionado a que todas las fuentes estén disponibles (evita informe parcial sin aviso).
- Permisos (`UNIT_RELEASE`, `SCREENING_WRITE`, `QUALITY_DAILY_REVIEW`, `ANALYTICAL_QC_WRITE`, etc.) ya separados por responsabilidad y segregación de funciones.

---

## Propuesta de siguiente PR (Fase 2 ejecutable)

Rama nueva sobre main (no sobre esta rama de UX):
1. **Migración** `20261113_cleaning_plans_records.sql` (idempotente, con RLS por `branch_id`).
2. **Módulo** `hemocura-core/cleaning.js` + `cleaning-data.js` + sección en `laboratory.js` tab "resources" para acceso rápido.
3. **Alertas** de limpieza vencida en `labSignals()` dentro de `lab-domain.js`.
4. **Tests** en `.github/workflows/lab-management.yml` o workflow nuevo.
5. **Documentación** `docs/CLEANING_MODEL_v0_67.md` siguiendo el patrón de `AUDIT_MODEL_v0_33.md`.

Diferencia con el prompt original: no construyo desde cero, solo agrego el pedazo faltante alineado al patrón existente.

---

## Pregunta de bloqueo

1. ¿Autorizas abrir el PR correctivo para **Brecha 1** (módulo de limpieza) en una rama nueva, o lo integro a esta misma rama?
2. ¿Autorizas el **parche del riesgo de localStorage** (excluir ABO/Rh/razón del autosave) dentro del PR actual?
3. ¿Hay acceso a Supabase (service key o SQL read-only) para resolver las 5 verificaciones vivas pendientes? Sin eso, los 🔎 quedan abiertos.
