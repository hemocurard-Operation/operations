# Auditoría §8 Compliance (República Dominicana) — estado real

**Fecha:** 2026-11-13
**Base:** `origin/claude/vibrant-babbage-8q8oc8` tras §7 SGC (`8e12f32`)
**Alcance:** Prompt maestro §8 contra el stack de compliance, ISO, training y competencias.
**Método:** lectura estática de `compliance.js`, `compliance-penal-data.js`, `iso-compliance.js`, `training.js`, `competencies.js`, migración `202610120345_compliance_penal_program.sql` y `sql/34_COMPETENCY_TRAINING_v0_34.sql`, cruzado con `docs/recursos/HC-CMP-MC-001_Manual_Compliance_Penal.md` y `docs/recursos/HC-SGC-Arquitectura-Documental-v1.html`.

---

## Estado por norma / sección del prompt

| Norma pedida por prompt §8 | Dónde está en el repo | Estado |
|---|---|---|
| Ley General de Salud 42-01 | Mencionada en `docs/recursos/HC-SGC-MC-01_Documento_Maestro_Consolidado_v2.html:368` y `HC-SGC-Arquitectura-Documental-v1.html`; **no existe tabla** `regulatory_requirements` general | ⚠ Documentada, no digitalizada |
| Requisitos MSP (Ministerio de Salud Pública) | Mencionado en documentos como "Manual Inmunohematología MSP", "Disp. MSP" (ver `HC-SGC-Arquitectura-Documental-v1.html:687,690`); sin registro trazable en DB | ⚠ Documentado, no digitalizado |
| Normativa bancos de sangre y transfusión | Decreto 349-04 + Norma de Habilitación citados en `HC-CMP-MC-001:44` y `HC-SGC-Arquitectura-Documental-v1.html:215`; sin tabla de requisitos | ⚠ Documentado, no digitalizado |
| Habilitaciones sanitarias | Mencionadas en Plan Maestro; **no veo expediente de habilitación por sucursal ni fecha de vencimiento** | ❌ Sin digitalizar |
| Cámara hiperbárica — regulación aplicable | No encontré regulación específica digitalizada. Módulo `hyperbaric` existe pero cubre operaciones, no compliance | ❌ Sin digitalizar |
| Seguridad y salud ocupacional | Ley 87-01 citada en docs; **ningún registro operacional** | ❌ Sin digitalizar |
| Protección de datos personales (Ley 172-13 RD) | Reconocida en `HC-CMP-MC-001:52,154,336`; política implementada en código (CSP estricta, no imágenes de ID, RLS por sucursal), pero **no hay matriz de cumplimiento Ley 172-13** | ⚠ Implementada en código, sin matriz de evidencia |
| Normas de calidad y documentación exigibles | ISO 9001/15189 cubierto por `iso_clause_evidence` + `iso_clause_assessments` | ✅ Operativo |
| **Compliance Penal (Ley 74-25 + Ley 44-26)** | `compliance_penal_requirements` (11 sequence_no 1-11), `_assessments` (estado + madurez 0-4 + evidencia), `_actions` (plan de remediación) + `compliance.js` UI con KPIs y fecha de control 2026-11-05 | ✅ Operativo + muy completo |
| **Capacitaciones** (tema, objetivo, convocatoria, asistencia, evaluación, competencia, certificados, vigencia, próxima) | `training_events`, `training_participation`, `competency_catalog`, `competency_assessments`, `job_roles`, `job_role_competencies`, `staff_job_assignments` | ✅ Operativo (7 tablas) |

---

## Fortalezas

- **Compliance Penal es un módulo de referencia**: catálogo fijo de 11 requisitos con secuencia obligatoria, scope corporativo o por sucursal, madurez 0-4, evaluación por responsable con evidencia, acciones con prioridad/vencimiento/verificador, y UI que cuenta días al hito regulatorio.
- **Manual HC-CMP-MC-001** documenta correctamente el mapeo entre delitos del Código Penal y controles operativos (segregación de funciones, auditoría de evidencia, trazabilidad, etc.).
- **Decisiones de privacidad ya en código**: CSP estricta, no se guardan imágenes de cédula, RLS por sucursal, datos serológicos con `SCREENING_WRITE` + revisor independiente — todo alineado con Ley 172-13.
- **Capacitaciones + Competencias** cubre la función transversal que pide el prompt (Compliance + Calidad + RH). Vigencias y próxima capacitación están modeladas.

---

## Brechas

### Brecha C1 — Matriz regulatoria **general** inexistente (§8 bullet por bullet)
**Severidad:** Alta.
**Qué dice el prompt:** *"Crear una matriz de requisitos regulatorios aplicables a HemoCura"* con campos "Fuente oficial · Norma · Artículo · Aplicabilidad · Obligación · Responsable · Evidencia · Fecha límite · Estado · Última revisión".
**Realidad:** solo existe matriz **penal** (`compliance_penal_requirements`). La matriz **sanitaria / laboral / datos / ambiental** vive como texto en documentos de arquitectura, no como registros con estado y responsable.
**Impacto:** una inspección del MSP o de DIDA no puede recibir del sistema un listado de "qué norma aplica, quién responde, última revisión, próxima revisión, evidencia vigente". Toca armarlo a mano.
**Trabajo:** una tabla genérica `regulatory_requirements` con mismas columnas del prompt + `regulatory_assessments` con estado por sucursal + `regulatory_evidence` + módulo `regulatory-matrix.js`. Carga inicial desde `docs/recursos/HC-SGC-Arquitectura-Documental-v1.html` (ya catalogó 60+ normas).
**Riesgo:** modelar mal una norma puede dar falsa sensación de cumplimiento. Carga inicial requiere revisión jurídica.

### Brecha C2 — Expediente de habilitaciones sanitarias por sucursal
**Severidad:** Alta.
**Qué falta:** registro de habilitación sanitaria MSP por sucursal (Santiago, Puerto Plata, Tenares): número de resolución, fecha de emisión, fecha de vencimiento, alcance autorizado, documentación de respaldo, alertas de renovación.
**Trabajo:** tabla `facility_licenses(branch_id, license_type, authority, number, issued_at, expires_at, scope, document_ref, status)` + alertas automatizadas 90/60/30 días antes del vencimiento.
**Nota:** el prompt §13 dice no almacenar PDFs sensibles en navegador; las habilitaciones sí pueden ir en Supabase Storage con RLS por sucursal.

### Brecha C3 — Compliance específico de cámara hiperbárica
**Severidad:** Media.
**Qué falta:** normativa aplicable a cámara hiperbárica en RD (si existe). El módulo `hyperbaric` cubre operación (citas, sesiones, factura, cobro) pero no habilitación, certificación del equipo, calibración de presión, formación del personal.
**Trabajo previo:** investigación normativa — no está en los documentos del repo. **Necesita confirmación de qué norma aplica.**

### Brecha C4 — Evidencia Ley 172-13 fuera de código
**Severidad:** Media.
**Qué falta:** aunque la privacidad está implementada en código y RLS, no hay una matriz operacional Ley 172-13: inventario de datos, base legal por campo, DPO, procedimiento de brecha, DPIA.
**Trabajo:** incluir en la matriz regulatoria general (Brecha C1) como subconjunto Ley 172-13 con sus artículos, o como submódulo dedicado.

---

## 🔎 Verificaciones vivas pendientes

1. ¿Las 11 evaluaciones penales `compliance_penal_assessments` están completas al 2026-11-13, a 8 días del hito del 2026-11-05 (que ya pasó)?
2. ¿Qué habilitaciones MSP vigentes tiene HemoCura por sucursal? No están en el sistema.
3. ¿El equipo legal interno ya mapeó Ley 42-01 / Decreto 349-04 / Ley 172-13 como requisitos operacionales, o solo como referencia bibliográfica?
4. ¿Hay oficial de cumplimiento asignado como `profiles.id` para que las acciones penales no queden huérfanas?
5. ¿Las capacitaciones de hemovigilancia, bioseguridad, protección de datos están programadas en `training_events` o solo en papel?

---

## Veredicto global §8

- **Compliance Penal:** maduro y operativo.
- **Capacitaciones y competencias:** maduro y operativo.
- **ISO 9001/15189:** operativo.
- **Marco regulatorio sanitario / laboral / datos / ambiental:** **no digitalizado**, solo vive en documentos de arquitectura. **Esta es la brecha mayor del módulo.**

Un inspector MSP pediría "muéstreme su matriz de cumplimiento Ley 42-01" y el sistema hoy no la produce. El Manual HC-CMP-MC-001 la referencia pero no la contiene como registro operacional.

---

## Propuesta de siguiente PR

**PR-C1** — Matriz regulatoria general:
1. Migración `regulatory_requirements` + `regulatory_assessments` + `regulatory_evidence` (schema aditivo, RLS por sucursal donde aplique).
2. Módulo `regulatory-matrix.js` siguiendo patrón de `compliance.js`.
3. Carga inicial parseada desde `docs/recursos/HC-SGC-Arquitectura-Documental-v1.html` (como seed data en migración, pendiente de validación jurídica).
4. Permisos `REGULATORY_VIEW`, `REGULATORY_WRITE`, `REGULATORY_REVIEW`.

**Pre-requisito:** autorización por schema change + confirmación del equipo legal interno de que la carga inicial parseada es aceptable como punto de partida.

---

## Pregunta de bloqueo

1. ¿Autorizas abrir **PR-C1** (matriz regulatoria general)? Requiere schema change y seed data.
2. ¿Autorizas **PR-C2** (habilitaciones sanitarias por sucursal)? Es más acotado y crítico operacionalmente.
3. ¿El equipo legal interno puede revisar la carga inicial antes de mergear, o lo haces tú como reviewer?
