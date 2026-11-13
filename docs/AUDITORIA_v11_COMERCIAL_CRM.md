# Auditoría §9 Comercial y CRM — estado real

**Fecha:** 2026-11-13
**Base:** `origin/claude/vibrant-babbage-8q8oc8` tras §8 Compliance (`8e7bbc0`)
**Alcance:** Prompt §9 contra el stack comercial.
**Método:** lectura estática de `crm.js`, `crm-planner.js`, `crm-planner-domain.js`, `crm-import.js`, `commercial.js`, `commercial-calendar.js`, `customers.js`, `medical-network.js`, `congresses.js`, `sales.js` (299 líneas), y migraciones `20261105235241_commercial_crm_contacts.sql` + `20261106004735_crm_weekly_visit_planner.sql` + `20261106112104_commercial_agenda_union.sql`.

---

## Veredicto por sección

| Prompt §9 | Realidad | Estado |
|---|---|---|
| Registrar **médicos, centros, hospitales, clientes, contactos** | `crm_contacts(kind=PROSPECTO/REFERIDOR/CENTRO)`, `customers`, `medical_referrers`, `crm_center_locations`, `crm_contact_sources`, `crm_contact_branch_access` | ✅ Operativo |
| **Historial comercial** | `crm_activities` (visita/llamada/WhatsApp/correo/nota) + `crm_history` con `before_data`/`after_data` | ✅ Operativo |
| **Servicios utilizados, ventas** | `crm_services` + `crm_contacts.service_ids[]` + `crm_contacts.goal_service_id` + `sales` (299 líneas de módulo); vínculo automático contacto ↔ cliente ↔ venta | ✅ Operativo |
| **Metas comerciales** | ❌ **No encontré** `commercial_goals` ni `sales_targets` ni `agent_quotas`. Solo hay `objective` como texto libre en ficha | ❌ **Brecha** |
| **Oportunidades / pipeline** | ❌ `crm_contacts.stage` ∈ PROSPECTO/CONTACTADO/SEGUIMIENTO/ACTIVO/NO_INTERESADO/ARCHIVADO (ciclo relacional, no pipeline comercial con valor y probabilidad) | ❌ **Brecha** |
| **Visitas** | `commercial_visits` (histórico), `crm_weekly_visits` (planificación) con duración, objetivo, agente, status PLANIFICADA/CANCELADA, revisión concurrente, request_id idempotente | ✅ Operativo |
| **Actividades de promoción** | `commercial_calendar`, `congresses` (222 líneas: congresos médicos, noticias, asistencia por referidor) | ✅ Operativo |
| **Reglas de visitas** (frecuencia, prioridad, especialidad, ubicación, horarios, preferencias, restricciones, objetivos) | `crm_visit_rules`: slots (hasta 14 franjas día+tanda), appointment_required, after_patients, arrival_order, representative_limit, priority ALTA/MEDIA/BAJA, rule_text, needs_review. Revisión incremental y auditoría | ✅ Operativo + **muy sólido** |
| **Recomendaciones inteligentes** (metas, historial, tiempo desde última visita, reglas, oportunidades, disponibilidad) | `candidates()` en `crm-planner-domain.js` filtra por especialidad/centro/regla/día/tanda y ordena por prioridad+centro+nombre | ⚠ **Parcial** — priorización sí, pero no por metas (no existen) ni por "días sin contacto" ni por oportunidad abierta |
| **Mapa de centros** | Leaflet local (vendor), OpenStreetMap tiles opt-in, CSP incluye `tile.openstreetmap.org`. Coordenadas verificadas con `source` documentado | ✅ Operativo |
| **Agenda promoción cámara hiperbárica / banco de sangre / campañas** | `commercial_calendar` (visitas), `donor_campaigns` (campañas donación), `hyperbaric` (operación), `congresses` (eventos externos) | ✅ Operativo pero dispersado entre módulos |
| **No recomendaciones clínicas basadas solo en objetivos comerciales** | El planner solo ordena fichas por reglas administrativas; no toca criterios clínicos | ✅ Alineado con §9 último punto |

---

## Fortalezas

- **Deduplicación fuerte**: `private.crm_matches` compara por teléfono normalizado, email lowercase y nombre+centro al guardar. Evita fichas dobles del mismo médico.
- **RLS por sucursal** vía `private.crm_scope(branch_id, 'COMMERCIAL_VIEW/WRITE')` en las 9 tablas CRM. Super usuario como bypass controlado.
- **Idempotency**: `crm_requests(actor_id, request_id)` evita que un reintento cree una visita o un contacto duplicado.
- **Revisión concurrente**: `crm_contacts.revision` + `crm_visit_rules.revision` + `crm_weekly_visits.rule_revision`. Un cambio en la regla fuerza a reconfirmar visitas planificadas.
- **Teléfonos validados**: `private.crm_phone` normaliza y verifica formato `(809|829|849)XXXXXXX` dominicano.
- **Valores controlados** en campos sensibles (email regex, phone regex, length checks en `private.crm_clean`).
- **Feature flag**: `commercial_crm` y `crm_weekly_planner` permiten rollout controlado.
- **Mapa opt-in** con OpenStreetMap: no envía nombres ni teléfonos a terceros al activarlo (solo tiles). CSP lo permite.
- **`candidates()` excluye** contactos `ARCHIVADO`, `NO_INTERESADO` y `NO_CONTACTAR` — respeta la decisión del médico.

---

## Brechas

### Brecha CM1 — Metas y seguimiento (§9 "Metas, oportunidades")
**Severidad:** Alta.
**Qué dice el prompt:** *"metas, oportunidades"* y *"recomendaciones basadas en cumplimiento de metas, historial de ventas, tiempo desde la última visita, reglas establecidas, oportunidades, disponibilidad"*.
**Qué falta:**
- `commercial_goals(period, branch_id, agent_id, service_id, metric, target_value)` — p.ej. 20 nuevos referidores este trimestre en Puerto Plata.
- `commercial_progress` vista agregada que compare `target` vs. `achieved` por `commercial_visits` + `sales`.
- `crm_opportunities(contact_id, service_id, expected_value, expected_close, probability, stage)` — pipeline distinto del ciclo relacional en `crm_contacts.stage`.
- Scoring del planner que ordene por: (prioridad regla) + (meta en riesgo) + (días desde última actividad) + (oportunidad abierta).
**Trabajo:** migración + planner domain extendido + UI de metas.

### Brecha CM2 — Visita "promocional" tipificada (§9 "Promoción: banco, campañas, cámara, hospitales, educación")
**Severidad:** Media.
**Realidad:** `commercial_visits` registra la visita, pero el tipo "educación institucional" vs. "venta" vs. "post-donación" vive en `objective` como texto. Reportes sectoriales (cuántas horas en educación este mes) no son triviales de calcular.
**Trabajo:** añadir `commercial_visits.purpose` enum (VENTA, PROMOCION_DONACION, EDUCACION_INSTITUCIONAL, CAMARA_HIPERBARICA, POST_SERVICIO, OTRO) + reportes.

### Brecha CM3 — Alineación de agendas comerciales (§9 "Agenda unificada")
**Severidad:** Baja.
**Observación:** `commercial_calendar`, `crm_weekly_visits`, `donor_campaigns`, `hyperbaric`, `congresses` son 5 fuentes de eventos con calendarios propios. La migración `20261106112104_commercial_agenda_union.sql` ya avanzó un intento de unión.
**Trabajo:** verificar en vivo si esa unión muestra agenda consolidada por agente / sucursal / semana.

---

## 🔎 Verificaciones vivas

1. ¿`commercial_crm` y `crm_weekly_planner` están **enabled** en `app_feature_flags`?
2. ¿Hay metas comerciales ya en uso aunque sea como objetivo en texto libre que debamos migrar a tabla?
3. ¿Qué consume hoy el equipo comercial — la vista `commercial_agenda_union`, el planner, o fuera del sistema?
4. ¿Hay reportes/dashboard por agente con pipeline y tasa de conversión que no esté auditado aquí?

---

## Veredicto global §9

**Núcleo CRM muy maduro.** Dedup, RLS, idempotency, revisión concurrente, teléfono RD validado, mapa opt-in, 9 tablas con historial inmutable, planner semanal con filtros reales. Para gestión relacional médica, cumple e incluso pasa el nivel típico de un SaaS mediano.

**Donde queda corto es en gestión de meta / pipeline comercial**: metas cuantitativas, oportunidades con probabilidad, scoring de recomendaciones basado en desempeño. El prompt las pide; el código las menciona solo como texto libre.

Promoción (cámara, campañas, educación) está capturada pero sin tipificación que permita medir mix por tipo de actividad.

---

## Propuesta de siguientes PRs

1. **PR-CM1 (alto)** — Metas + Pipeline. Schema change con `commercial_goals` y `crm_opportunities` + extensión del planner. Requiere autorización por peso.
2. **PR-CM2 (bajo)** — `commercial_visits.purpose` enum + 1 reporte. Migración aditiva corta.
3. **PR-CM3 (bajo)** — Verificación viva de la unión de agendas.

---

## Preguntas de bloqueo

1. ¿Autorizas abrir **PR-CM1** (metas + pipeline) o quieres que primero cerremos deuda técnica más prioritaria (§5.8 limpieza, §8 matriz regulatoria)?
2. ¿Autorizas **PR-CM2** (tipificación de visitas)? Es barato y habilita reportes gerenciales.
3. ¿El comercial usa hoy herramienta externa para metas (Excel, otra app)? Si sí, PR-CM1 debería contemplar import.
