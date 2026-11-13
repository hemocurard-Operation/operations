# Auditoría §7 SGC (Sistema de Gestión de Calidad) — estado real

**Fecha:** 2026-11-13
**Base:** `origin/main` tras PR #83 pendiente (`e25c80b`)
**Alcance:** Prompt maestro §7 (SGC digital) contra el código fuente actual.
**Método:** lectura estática de `quality.js`, `qa.js`, `qms-governance.js`, `qms-action-board.js`, `integrated-actions.js`, `integrated-qms-data.js`, `blood-quality.js`, `iso-compliance.js`, `inspections.js`, `internal-audits.js`, `hemovigilance.js` y migraciones asociadas.

---

## Veredicto por sección

| Prompt | Entidad / módulo | Estado | Notas |
|---|---|---|---|
| **Formularios configurables, versiones, firmas, PDF, historial** | ❌ No hay `quality_forms` / `form_versions` / `form_submissions` genéricas. Cada captura (inspección, hemovigilancia, NC, CAPA, incidente, visita, control analítico) es **un formulario codificado**, no una definición de datos versionada | ❌ **Ausente como sistema** | Formularios específicos operativos; falta el motor genérico que el prompt describe. |
| **Novedades** (registro, clasificación, responsable, prioridad, seguimiento, cierre) | `incidents` vía `createIncident` en `quick-capture.js` + `work_tasks` para seguimiento | ✅ Operativo |
| **No conformidades** (identificación, descripción, área, causa raíz, impacto, contención, CAPA, responsables, fechas, evidencia, verificación de eficacia) | Tablas `nonconformities` + `capa` con RLS por sucursal y `QUALITY_VIEW/WRITE`. Trigger `qms_guard` **bloquea cierre** si falta: responsable, causa raíz, evidencia de cierre, revisor independiente (≠ owner), CAPAs resueltas | ✅ Operativo + **endurecido** |
| **CAPA** | Tabla `capa` con origen inmutable (`nonconformity_id` no modificable), RPC `qms_capa_action(action, data)` con security invoker, historial inmutable en `qms_change_history` | ✅ Operativo |
| **Acciones integradas** | Tabla `integrated_actions` + módulo `integrated-actions.js` + board `qms-action-board.js` | ✅ Operativo |
| **Inspecciones** → NC/CAPA | `branch_inspections` + `inspection_findings` + RPCs `inspection_finding_to_nonconformity`, `inspection_finding_create_capa` | ✅ Operativo (buen patrón de puente) |
| **Auditorías internas** | `internal_audits`, `audit_programs`, `audit_findings`, `audit_evidence`, `audit_criteria_catalog`, `audit_plan_criteria` | ✅ Operativo |
| **Hemovigilancia** (eventos adversos, casi-eventos, retiros) | `hemovigilance_events`, `product_recalls`, `recall_units`, `hemovigilance_delivery_details` (migración 2026-11-04) | ✅ Operativo |
| **ISO 9001/15189 por cláusula** | `iso_clause_evidence` + `iso-compliance.js` (166 líneas) | ✅ Operativo |
| **Riesgos** | `risk_register` + `capa` enlazada | ✅ Operativo |
| **Revisión por dirección + objetivos de calidad** | `management_reviews`, `management_review_actions`, `quality_objectives` | ✅ Operativo |
| **Indicadores** (NC abiertas, CAPA vencidas, cumplimiento mantenimiento/limpieza, desviaciones temp, auditorías, eficacia) | Vistas BI + `labSignals` + `command-center` + `predictive-data`; limpieza ya marcada como brecha en `AUDITORIA_v11_LABORATORIO.md` | ⚠ Parcial — indicador de limpieza no existe porque el módulo tampoco |
| **Firmas y aprobaciones** | `approvals` + segregación de funciones vía trigger `qms_guard` (revisor ≠ owner) | ✅ Operativo a nivel de registro; no como workflow visual firmable |
| **Exportación PDF / impresión** | `downloadText` genera `.txt`; no vi stack de PDF | ⚠ Parcial — informes gerenciales exportan texto plano, no PDF firmado |

---

## Fortalezas que no voy a tocar

- **`qms_guard` trigger**: bloquea cierre de NC si falta responsable + causa + evidencia + revisor independiente + CAPAs resueltas. Segregación de funciones a nivel de DB.
- **CAPA inmutable en origen**: `nonconformity_id` no puede modificarse después del insert — previene lavado de hallazgos.
- **`qms_change_history`**: historial de 6 entidades críticas (nonconformities, capa, risk_register, management_reviews, management_review_actions, document_changes) con trigger `qms_audit` after insert/update.
- **RLS granular**: `QUALITY_VIEW` para lectura, `QUALITY_WRITE` para escritura, `can_access_branch(branch_id)` para aislamiento por sucursal.
- **Puente inspección → NC/CAPA por RPC**: evita lógica dispersa en el cliente. Un hallazgo de inspección genera NC con `inspection_finding_to_nonconformity` o CAPA directa con `inspection_finding_create_capa`.
- **Integración con Hemovigilancia**: migración 2026-11-04 (`hemovigilance_delivery_nc.sql`) ya conecta entrega adversa con NC automática.

---

## Brechas

### Brecha Q1 — Motor de formularios configurables (§7)
**Severidad:** Media-alta.
**Qué dice el prompt:** *"Formularios configurables, versiones controladas, firmas y aprobaciones, exportación PDF, impresión, historial, evidencias"*.
**Realidad:** cada formulario es código. Añadir uno requiere PR, review, deploy. Un responsable de calidad no puede crear un formulario nuevo "de un día para otro".
**Decisión pendiente:** ¿realmente lo necesita HemoCura, o el modelo actual (un módulo por entidad clínica crítica) es más seguro?
**Argumento para mantener así:** los formularios codificados garantizan CHECKs de DB, RLS, segregación de funciones y auditoría que un motor genérico de forms no da gratis. Para un banco de sangre bajo ISO 15189, sobre-configurar es un riesgo clínico.
**Argumento para implementarlo:** el prompt lo pide explícitamente y los SGCs comerciales tipo iPassport, Qualio, etc. lo tienen.
**Si se decide implementar:** mínimo `quality_forms(id, code, title, version_current)`, `form_versions(id, form_id, version, definition_jsonb, published_by, published_at)`, `form_submissions(id, version_id, submitted_by, submitted_at, values_jsonb, signatures_jsonb, evidence_refs[])`. **No lo haría sin autorización por el peso del cambio.**

### Brecha Q2 — Exportación PDF firmada
**Severidad:** Media.
**Qué falta:** los exports gerenciales (`labReport`, `exportCsv`, etc.) producen `.txt` o `.csv`. Para auditoría externa / inspección sanitaria conviene PDF con metadatos de firma (quién, cuándo, hash del contenido, logo HemoCura).
**Trabajo:** elegir librería (probable `jsPDF` + `html2canvas`) dentro de la CSP actual — la CSP solo permite `script-src 'self'` y `wasm-unsafe-eval`, lo que implica incluir el bundle localmente. **Es compatible pero añade ~500KB al frontend; verificar `ux-performance-budget`.**

### Brecha Q3 — Indicador de limpieza
**Severidad:** Baja (depende de Brecha §5.8).
Ya reportada en `AUDITORIA_v11_LABORATORIO.md`. Cerrarla implementa este indicador automáticamente por `labSignals`.

---

## 🔎 Verificaciones vivas pendientes para §7

1. ¿Las vistas BI consumidas por `bi.js` incluyen todos los indicadores del prompt? (NC abiertas, CAPA vencidas, cumplimiento mantenimiento, cumplimiento limpieza — no existe, desviaciones temp, auditorías por vencer, eficacia de acciones).
2. ¿`qms_guard` tiene tests de regresión? No vi un `.yml` que lo cubra directamente.
3. ¿Hay algún formulario operativo que un usuario real quiera cambiar sin PR? Si la respuesta es "sí, y a menudo", Brecha Q1 es alta. Si es "no, los formularios son pocos y estables", mantener el modelo actual.

---

## Veredicto global

**§7 SGC es uno de los módulos más maduros del repo.** NC, CAPA, auditorías, hemovigilancia, ISO cláusulas, inspecciones, revisión por dirección, riesgos: todo está con tablas, RLS, trigger guards e historial inmutable.

Las dos brechas reales — motor de formularios y PDF firmado — son **ampliaciones**, no faltas operativas. Un auditor ISO 15189 aceptaría el estado actual con observaciones; no lo rechazaría.

---

## Preguntas de bloqueo

1. ¿Confirmas que mantenemos **formularios codificados** (no motor genérico) por seguridad clínica, o quieres que diseñe el motor de Brecha Q1?
2. ¿Autorizas trabajar PDF firmado (Brecha Q2) como PR independiente tras cerrar §5.8 (limpieza)?
3. ¿Hay una lista de indicadores exactos que la gerencia revisa para cerrar Verificación viva 1?
