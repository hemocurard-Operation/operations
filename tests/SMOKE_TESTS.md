# HemoCura Smoke Tests — documento vivo

**Versión declarada en `VERSION.json`:** 0.66.0 · canal RC · `clinical_core: LIVE-LIMITED / CONTROLLED_RELEASE`.

Este archivo es la **fuente única viva** para la verificación de humo entre releases. Antes de este documento, cada release guardaba su propio `SMOKE_TESTS_<versión>.md` (de v0.20 a v0.44). Los archivos antiguos se conservan como registro histórico, pero a partir de v0.66 **este archivo se actualiza en cada release**, no se crea uno nuevo.

Patrón de uso:

1. En cada PR que cambia comportamiento de usuario, verificar que esta checklist sigue válida.
2. En cada release, revisar la sección «Checklist por release» y añadir las comprobaciones específicas.
3. Las secciones «Verificación automatizada» y «Verificación manual mínima» se actualizan solo cuando cambia el stack de pruebas.

---

## 1. Verificación automatizada — workflows que deben estar verdes

Al momento del release, estos workflows deben estar verdes en el PR y en `main`:

| Workflow | Cubre |
|---|---|
| `release-readiness-doctor.yml` | UAT firmas, migraciones faltantes, objetos faltantes |
| `runtime-contract-gate.yml` | Contratos de runtime (`contracts/*.json`) |
| `frontend-browser-smoke.yml` | Boot y rutas montan sin error |
| `frontend-source-truth.yml` | Contratos frontend consistentes con backend |
| `migration-security-linter.yml` | Migraciones pasan el linter de seguridad |
| `ux-performance-budget.yml` | Presupuesto UX no se excede |
| `web-performance-security.yml` | Presupuesto de rendimiento y seguridad |
| `web-uptime.yml` | Endpoints públicos responden |
| `workflow-business-rules.yml` | Reglas de negocio transversales |
| `blood-traceability.yml` | Escenario crítico §17 #1 — doble dispatch |
| `rls-cross-branch.yml` | Escenario crítico §17 #5 — aislamiento por sucursal |
| `idempotency.yml` | Escenario crítico §17 #7 — donación no duplicable |
| `lab-safety-alerts.yml` | Escenarios críticos §17 #2 #3 #4 — alertas y validaciones |
| `donor-management.yml` | Donantes end-to-end |
| `lab-management.yml` | Laboratorio end-to-end |
| `commercial-crm.yml` | CRM comercial |
| `quality-information.yml` | SGC + historial de NC |
| `compliance-penal-safety.yml` | Compliance penal |
| `purchase-receiving.yml` | Recepción de compras vinculada a inventario |
| `migration-security-linter.yml` | Linter de seguridad de migraciones |

El listado vive en `.github/workflows/`; cualquier workflow nuevo se añade aquí en el mismo PR.

---

## 2. Verificación manual mínima antes de release

Si cambió algo visible al usuario, ejecutar en orden:

### 2.1 Boot limpio
- [ ] `index.html` carga sin error en consola.
- [ ] `VERSION.json` coincide con lo reportado por `deployment-check.html`.
- [ ] `release-gate` muestra estado del release channel.

### 2.2 Autenticación y acceso
- [ ] Login funciona con credenciales de prueba.
- [ ] Logout funciona.
- [ ] Un usuario de la sucursal A **no** ve datos de la sucursal B (ver también `rls-cross-branch.yml`).
- [ ] Un perfil desactivado pierde acceso.

### 2.3 Núcleo clínico (LIVE-LIMITED)
- [ ] Captura rápida de donante carga.
- [ ] Autosave **no** persiste ABO/Rh/motivo de diferimiento en `localStorage` (mitigación §15, ver `AUDITORIA_v11_LABORATORIO.md`).
- [ ] Toast de éxito/error aparece al enviar formulario.
- [ ] Spinner + submit deshabilitado durante guardado.
- [ ] Barra de progreso de campos requeridos refleja completitud.

### 2.4 Laboratorio
- [ ] Ruta `#laboratory` carga con 7 pestañas.
- [ ] Lectura de temperatura dentro de rango se guarda sin excursión.
- [ ] Lectura fuera de rango genera entrada en vista de excursiones.
- [ ] Alertas de mantenimiento y calibración próximas/vencidas visibles.

### 2.5 Trazabilidad
- [ ] Una donación creada aparece en el flujo de tamizaje.
- [ ] Una unidad `DISPONIBLE` puede despacharse una sola vez.
- [ ] El historial de una unidad sanguínea es consultable end-to-end.

### 2.6 SGC
- [ ] No conformidad no se puede cerrar sin responsable + causa + evidencia + revisor independiente + CAPAs resueltas (trigger `qms_guard`).
- [ ] Hallazgo de inspección puede elevarse a NC o a CAPA.
- [ ] `qms_change_history` muestra el diff de la última edición.

### 2.7 Comercial
- [ ] CRM — intento de guardar contacto duplicado (mismo teléfono) muestra conflicto.
- [ ] Planner semanal muestra solo contactos no `ARCHIVADO`/`NO_INTERESADO`/`NO_CONTACTAR`.
- [ ] Mapa Leaflet carga opt-in sin enviar nombres/teléfonos a terceros.

### 2.8 Finanzas
- [ ] CxC muestra aging 0/1-30/31-60/61-90/90+ días.
- [ ] Costos mensuales muestran descomposición por tipo (material/labor/screening/indirect/waste/transport/other).
- [ ] Cierre de costo requiere aprobación independiente (`approve_monthly_cost_period`).

### 2.9 Predictivo
- [ ] Cockpit predictivo carga con KPIs (stock, cobranza, salud clientes, señales).
- [ ] Aceptar/Diferir una señal la mueve a `predictive_decision_reviews`.

### 2.10 Seguridad
- [ ] CSP estricta: sin violaciones en consola.
- [ ] `js/config.js` no está en diff del PR.
- [ ] Workflows de doctor (`C11_91`, `C12_00` si aplican) no reportan policies ALL demasiado anchas.

---

## 3. Checklist por release

**v0.66 (RC actual):** propuestas de encuadre de inventario con selección humana entre formularios; liberación clínica humana pendiente.

- [ ] Encuadre de inventario: OCR local produce propuestas que el humano aprueba.
- [ ] No hay propuesta aplicada sin firma humana.
- [ ] Rechazar propuesta conserva la unidad original sin modificaciones.

**v1.0 (objetivo):** los gates de `release-readiness-doctor.yml` deben pasar, UAT firmado por OPERACIONES/CALIDAD/TI/GERENCIA, y la auditoría de datos/seguridad (ver `docs/AUDITORIA_v11_DATOS_Y_SEGURIDAD.md`) debe estar cerrada contra la DB viva.

---

## 4. Historial de smoke tests

Los archivos `tests/SMOKE_TESTS_<versión>.md` (v0.20 → v0.44) se conservan como registro histórico. **No crear nuevos archivos versionados.** A partir de v0.66 este documento es la fuente única.

---

## 5. Cómo actualizar este documento

- Al cerrar un release, duplicar «Checklist por release» con la nueva versión arriba.
- Si se añade un workflow a CI, añadirlo a la tabla de §1.
- Si se añade un módulo nuevo al UI, añadir la sección correspondiente en §2.
- No cambiar la versión declarada arriba sin verificar que `VERSION.json` ya cambió.
