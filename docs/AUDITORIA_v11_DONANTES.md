# Auditoría §6 Donantes — estado real por subsección

**Fecha:** 2026-11-13
**Base:** `origin/main` tras merge de PRs #80/#81/#82 (`e25c80b`)
**Alcance:** Prompt maestro §6 (Donantes como familia independiente) contra el código fuente actual.
**Método:** lectura estática del stack `donors.js`, `donor-management-data.js`, `donor-outreach.js`, `donor-coordination.js`, `donor-agenda.js`, `cedula-reader-ui.js` y migraciones donor_* (4 archivos).

---

## Veredicto por subsección

| § | Subsección prompt | Módulo / tabla | Estado |
|---|---|---|---|
| 6.1 | Expediente del donante | `donors` tabla ampliada en `20261013183215_donor_management.sql` (full_name, cedula 11 dígitos con regex y UNIQUE, sex, phone, preferred_channel, abo, rh, status, deferral_reason, observations) + birth_date en `20261013200735` | ✅ Operativo |
| 6.1b | Estados de elegibilidad (aceptado / diferido temp / diferido perm / hemoglobina baja / pendiente) | Campo `status` en `donors` + `deferral_reason` libre; `donor_lab_comments` para observaciones clínicas con responsable | ⚠ **Estados libres**: no vi CHECK enumerado con los valores que lista el prompt. `deferral_reason` es texto. 🔎 verificar en vivo si hay enum o se usa texto libre. |
| 6.1c | Protección de datos personales/salud | RLS restrictive: `donor_identity_read` requiere `DONORS_VIEW`, `donor_lab_comments` requiere `SCREENING_WRITE` para insertar | ✅ Operativo |
| 6.2 | Registro de donación (donante, fecha, sucursal, tipo, resultado, responsable, evento, ID donación, próxima elegibilidad) | Tabla `donations` (`sql/23_BLOOD_OPERATIONS_BI_PM_v0_23.sql`), vínculo a campaña vía `campaign_id`, vista `vw_donor_next_donation` | ⚠ **Próxima donación hardcoded a +84 días** en la vista. El prompt §6.2 exige "criterios clínicos vigentes y validación del personal autorizado". 84 días es el intervalo estándar para sangre total pero no cubre aféresis (48 h) ni plaquetas (14 días) ni diferimientos clínicos. **Brecha.** |
| 6.3 | Citaciones (calendario, campañas, recordatorios, confirmaciones, reprogramaciones, cancelaciones, historial) | `donor_visits` con estados POR_CONFIRMAR/CONFIRMADA/ASISTIO/NO_ASISTIO/CANCELADA + campo `history jsonb` + UNIQUE que impide dos visitas activas por donante; `donor_contacts` con `next_contact_at`; `donor_campaigns` para campañas | ✅ Operativo |
| 6.4 | Reporte diario (programados, recibidos, aceptados, diferidos, rechazados, motivos, donaciones, tasa de aceptación, comparación por sucursal) | `donor-outreach` tiene KPIs de **campañas** (contactos, conversión, costo por donación), no de **jornada diaria** | ❌ **Ausente** — No hay módulo "reporte diario de donantes" con las métricas exactas del prompt. Tasa de aceptación por motivo de diferimiento no la vi. 🔎 verificar si el dashboard operativo cubre algo similar. |
| 6.5 | Cuadre de buscones y donantes (captador, donantes referidos/recibidos/efectivos, compensación, conciliación diaria) | ❌ No existe tabla `donor_referrals` ni ruta `#buscones` ni mención en 211 módulos | ❌ **Ausente completamente** — grep de `buscon|captador|referral` en `hemocura-core/` solo arroja un comentario del commit de privacidad. **Brecha vs prompt §6.5.** |

---

## Fortalezas que no voy a tocar

- **Cédula dominicana validada** por regex `^[0-9]{11}$` y UNIQUE parcial para no-nulos (permite donante sin cédula pero impide duplicados). Alineado con §15.
- **No se guardan imágenes de cédula** (comentario en `20261013200735_donor_identity_capture.sql`: "no identity images are stored or sent to an OCR service"). Decisión correcta de privacidad.
- **`donor_visit_active_unique`** impide dos visitas activas para el mismo donante — previene duplicados por retry.
- **RLS por `can_access_branch(branch_id)`** aplica a lectura/escritura/actualización en `donors`, `donor_lab_comments`, `donor_contacts`, `donor_visits`. 🔎 falta verificar que un usuario de Santiago no lea donantes de Puerto Plata.
- **Vista `vw_donor_next_donation`** diferencia `last_donation_date` de registros HemoCura vs. historial importado desde Excel y expone `reference_source` + `invalid_date_count` (datos sucios de la importación).
- **Historial inmutable** vía `history jsonb` en `donor_visits` con revisión incremental.

---

## Brechas priorizadas

### Brecha D1 — Reporte diario de donantes (§6.4)
**Severidad:** Alta (es un entregable operativo diario del banco de sangre).
**Qué falta:** una ruta `#donorsdaily` o tab dentro de `donors` que por sucursal y fecha reporte:
- Programados (de `donor_visits` ∩ fecha).
- Recibidos (count de `donor_visits` con `status='ASISTIO'`).
- Aceptados (join a `donations.collection_effective=true`).
- Diferidos / rechazados (de `donors.status` + `deferral_reason` del día).
- Motivos agrupados.
- Tasa de aceptación = aceptados / recibidos.
- Comparación por sucursal.

**Trabajo:** solo frontend + vista SQL de agregación — no requiere tabla nueva. Puede ir sin migración.

### Brecha D2 — Cuadre de buscones y donantes (§6.5)
**Severidad:** Alta (modelo de negocio dominicano, riesgo de cumplimiento Ley 42-01 si no se registra).
**Qué falta:**
- Tabla `donor_referrers` (captador: id, nombre, cédula, estado activo, políticas de compensación autorizadas).
- Tabla `donor_referrals` (`donor_id`, `referrer_id`, `referred_at`, `showed_up_at`, `donation_effective_id`, `compensation_amount`, `authorized_by`).
- Módulo `donor-referrals.js` con vista diaria de conciliación.
- Permiso `DONOR_REFERRALS_WRITE`, `DONOR_REFERRALS_RECONCILE`.

**Riesgo adicional (prompt §6.5):** *"No automatizar pagos vinculados a donaciones o captación sin verificar previamente su legalidad y las políticas institucionales aplicables."* — cualquier implementación debe registrar, no pagar. Compensación como conciliación manual con responsable del cierre.

**Trabajo:** migración + 2 tablas + RLS + módulo. **Requiere autorización** por cambio de schema.

### Brecha D3 — Próxima donación configurable por procedimiento (§6.2)
**Severidad:** Media.
**Evidencia:** `vw_donor_next_donation` hardcodea `last_donation_date + 84` días.
**Impacto:** no sirve para aféresis (48 h entre procedimientos) ni plaquetas (14 días mínimo, 24 veces/año) ni diferimientos clínicos específicos.
**Trabajo:** tabla `donation_interval_rules(donation_type, min_days, max_per_year, source_norm)` y reemplazar el `+84` por un lookup; permitir override por responsable autorizado.

### Riesgo D4 — Estados de elegibilidad posiblemente sin CHECK enumerado
**Severidad:** Media.
**Evidencia:** no vi un `check(status in (...))` que enumere los estados del prompt (ACEPTADO, DIFERIDO_TEMPORAL, DIFERIDO_PERMANENTE, HEMOGLOBINA_BAJA, PENDIENTE). 🔎 verificar en `donors` tabla o en migraciones anteriores a las donor_*.
**Si no existe:** añadir CHECK + script de consolidación del texto libre actual.

---

## 🔎 Verificaciones vivas pendientes para §6

1. ¿`donors.status` tiene enum?
2. ¿RLS entre sucursales funciona para donantes? (test: usuario Santiago intenta SELECT donante de Puerto Plata).
3. ¿Hay algún lugar en el UI actual que ya muestre el reporte diario (dashboard, command center, workflow)?
4. ¿La vista `vw_donor_next_donation` está siendo consumida por el frontend o solo por reportería?
5. ¿Cuántos donantes activos sin cédula hay (es decir, con el UNIQUE PARTIAL permisivo)?

---

## Propuesta de siguientes PRs (en orden)

1. **PR-D1 (bajo)** — Reporte diario de donantes: solo frontend + vista SQL. Sin schema change.
2. **PR-D3 (medio)** — Tabla `donation_interval_rules` + reescritura de `vw_donor_next_donation`. Requiere autorización por schema change pero es aditiva.
3. **PR-D2 (alto)** — Buscones/captadores. Requiere revisión legal + autorización explícita + confirmación de políticas institucionales. **No lo abro sin tu visto bueno escrito.**

---

## Pregunta de bloqueo

1. ¿Autorizas abrir **PR-D1** (reporte diario) ahora? Es bajo riesgo, sin schema change.
2. ¿Autorizas **PR-D3** (intervalos configurables de donación)? Ayuda a aféresis y plaquetas.
3. ¿Cómo quieres manejar **PR-D2** (buscones)? ¿Primero una revisión legal interna del flujo de compensación?
