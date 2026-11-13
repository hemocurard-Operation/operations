# Auditoría Fase 0 — HemoCura 11.0

**Fecha:** 2026-11-12
**Rama de trabajo:** `claude/vibrant-babbage-8q8oc8`
**Último commit:** `cfd7cb8` — feat: form capture phase 2
**Versión declarada:** VERSION.json → 0.66.0 (RC, "Propuestas de encuadre de inventario…")
**Repo auditado:** `hemocurard-Operation/operations` (⚠ el prompt maestro refiere `hemocura/hemocura-app` — ver §0)

---

## 0. Discrepancia de repositorio

El prompt indica como repo oficial `https://github.com/hemocura/hemocura-app`. El entorno de esta sesión está atado a `hemocurard-Operation/operations`. **Requiere decisión del usuario** antes de tocar nada estructural:

- Opción A — este repo (`hemocurard-Operation/operations`) **es** el proyecto actual, solo cambió el nombre. Historial coherente con HemoCura (v0.22 → v0.66 incremental, mismos autores).
- Opción B — existe un repo paralelo en `hemocura/hemocura-app` y hay que migrar o reenfocar. **No es accesible** desde esta sesión (fuera del scope de permisos GitHub).

**Recomendación:** confirmar que es Opción A antes de continuar. Mientras tanto, la auditoría se hace sobre este repositorio.

---

## 1. Tecnologías detectadas

| Capa | Stack |
|---|---|
| Frontend | HTML + JS modules (ESM nativo, sin bundler), CSS plano (`css/app.css`, `css/ui-v0442.css`) |
| Entry point | `index.html` → `js/app.js` → `hemocura-core/bootstrap.js` |
| Router | `hemocura-core/router.js` (hash-based, `#route`), grupos definidos en `GROUP_ORDER` |
| Backend | **Supabase** (proyecto `tiothqiljipdamgudvcb.supabase.co`, visible en CSP de `index.html`) |
| Persistencia | PostgreSQL vía Supabase, 52 migraciones en `supabase/migrations/` + 30 scripts versionados en `sql/` |
| Edge functions | 2 activas: `admin-users`, `training-tutor` (`supabase/functions/`) |
| Auth | Supabase Auth (ver `hemocura-core/auth.js`, `js/auth-finish.js`) |
| CI | 40 workflows en `.github/workflows/` (gate de release, smoke frontend, linters de migraciones, contratos) |
| Config | `js/config.js` **protegido** (fuera de VCS en algunos flujos; existe plantilla `config.example.js`) |
| PWA | `manifest.json` + CSP estricta con `script-src 'self'` (no CDN externo) |

**No es una SPA React/Next**. Es una app vanilla modular madura: 211 módulos en `hemocura-core/`.

---

## 2. Módulos existentes (desde `router.js`)

Están organizados en 7 familias, exactamente como pide el prompt (§4). Resumen:

### INICIO
dashboard, command, mywork, workflow, decisioncenter, predictive, orchestration

### TRABAJO DIARIO
areaagenda, quickcapture, dailyinventory, transport, teamdeliveries, extratrips, dispatches, transfers, sales, shiftreport, hyperbaric, requisitions, supplycatalog, inventory, supplytransfers, supply, planning

### CADENA DE VALOR
valuechain, serviceperformance, donoroutreach, medicalnetwork, customers, commercial, commercialcalendar, congresses, collections, economics

### LABORATORIO Y SANGRE
laboratory, donors, screening, production, bloodinventory, bloodflow, analyticalqc, coldchain, hemovigilance, resources, maintenance, environmental

### CALIDAD Y SEGURIDAD
actions, bloodquality, quality, isocompliance, approvals, qmsgov, internalaudits, inspections, training, competencies, documents, compliance (penal)

### GESTIÓN
bi, twelveweek, management, projects, continuity, suppliers

### ADMINISTRACIÓN
settings, users, security, diagnostics, audit, uat, integration, sgcimplementation

**Total: ~55 rutas montadas.** Prácticamente toda la arquitectura funcional del prompt §4–§11 ya está presente como módulo.

---

## 3. Mapeo prompt → estado actual

| Sección prompt | Módulo(s) existentes | Estado observable (sin ejecutar app) |
|---|---|---|
| A.1 Inventario (unidades sanguíneas, lotes, ABO/Rh, movimientos) | `blood-inventory`, `blood-flow`, `inventory`, `inventory-data`, `blood-operations-data` | **Presente** — modelo SQL en migraciones `24_CONTROLLED_BLOOD_FLOW_v0_24.sql` |
| A.2 Logística (transporte, pagos, tipos) | `transport`, `transport-data`, `team-deliveries`, `extra-trips`, `dispatch` | **Presente** — workflow `logistics-trips.yml` |
| A.3 Captura diaria unificada | `quick-capture`, `daily-inventory`, `daily-photo`, `workflow-daily` | **Presente** — contratos `i003-daily-report-production-truth.json` |
| §5 Laboratorio (sucursales, equipos, mantenimiento, temps, limpieza, tareas, insumos) | `laboratory`, `lab-data`, `lab-domain`, `maintenance`, `environmental-log`, `resources`, `supply-catalog`, `supply-planning`, `procurement`, `quotations`, `supplier-data` | **Presente** — migración `20261017084848_lab_management_workspace.sql` |
| §6 Donantes (expediente, donación, citas, reporte diario, buscones) | `donors`, `donor-management-data`, `donor-outreach`, `donor-agenda`, `donor-coordination`, `donor-twelve-week-agenda` | **Presente** — 4 migraciones donor_* |
| §7 SGC (formularios, novedades, NC, CAPA, indicadores) | `quality`, `qms-governance`, `qms-action-board`, `actions`, `integrated-actions`, `integrated-qms-data`, `blood-quality` | **Presente** — 32_QMS_APPROVAL_INTEGRATION |
| §8 Compliance RD (matriz regulatoria, capacitaciones) | `compliance`, `compliance-penal-data`, `iso-compliance`, `training`, `competencies`, `internal-audits` | **Presente** — migración `202610120345_compliance_penal_program.sql` |
| §9 Comercial/CRM (médicos, centros, visitas, promoción) | `crm`, `crm-planner`, `crm-import`, `commercial`, `commercial-calendar`, `customers`, `medical-network`, `congresses` | **Presente** — workflow `commercial-crm.yml` |
| §10 Finanzas (CxP, CxC, costos, cotizaciones) | `economics`, `costs`, `collections`, `suppliers`, `procurement`, `quotations`, `quotation-domain` | **Presente** |
| §11 BI / Predicción | `bi`, `predictive`, `predictive-data`, `orchestration`, `decision-center`, `ops-dashboard`, `command-center` | **Presente** — migración `20261012120555_predictive_chain_50_foundation.sql` |
| §12 Auditoría | `audit`, `audit-data` | **Presente** — migración `27_AUDIT_TRACE_EXCEPTIONS` |
| §15 Seguridad (RLS, roles, sucursal) | `security`, `access-control`, `access-data`, `role-labels`, `users` | **Presente** — migraciones de hardening y `super_user_total_access`, `assigned_role_branch_access` |

**No hay módulo faltante estructural.** Lo que exige el prompt §4–§11 está construido a nivel de andamiaje y persistencia. La pregunta real es: **¿funciona cada uno end-to-end con datos reales?** Eso no se puede responder sin ejecutar la app contra Supabase.

---

## 4. Indicadores de madurez

| Señal | Valor |
|---|---|
| Migraciones aplicadas | 52 archivos en `supabase/migrations/` (fechas ordenadas 2026-10-12 → 2026-11-09) |
| Scripts SQL versionados (histórico) | 30 archivos en `sql/` (v7.2 → v0.44 RC) |
| Módulos JS en core | 211 |
| Rutas registradas | ~55 |
| Workflows CI | 40, incluyendo `release-readiness-doctor`, `runtime-contract-gate`, `migration-security-linter`, `ux-performance-budget`, `web-performance-security`, `web-uptime`, `frontend-browser-smoke` |
| Contratos en `contracts/` | 14 (runtime, UX budget, role-module defaults, workflow routes, readiness snapshots) |
| Documentación en `docs/` | 121 archivos (`AUDIT_PLAN_v0.45.md`, `AUDITORIA_COMPETENCIAS_SEGURIDAD_20261104.md`, `MODELO_AUDITORIA_v0_27.md`, `STATIC_AUDIT_0.16.0.md` entre otros) |
| CSP | Estricta, sin CDN externo, solo self + Supabase + OSM tiles |
| Edge functions | admin-users (incluye `change_password`), training-tutor |
| Release channel | RC, `clinical_core: LIVE-LIMITED / CONTROLLED_RELEASE` |

**Este proyecto no está en Fase 0. Está en RC con release clínico controlado y gates de liberación.**

---

## 5. Lo que el prompt pide y **no he validado todavía**

La auditoría estática no puede responder, sin ejecutar:

1. **Persistencia real por módulo** — qué tablas están pobladas vs. vacías.
2. **RLS por rol+sucursal** — existe `C11_90_VALIDATE_FRONTEND_BACKEND.sql` y `C11_91_SECURITY_DOCTOR_READONLY.sql`; hay que correrlos contra la DB viva.
3. **Trazabilidad end-to-end de una unidad sanguínea** (donación → tamizaje → liberación → inventario → despacho).
4. **UAT validación** — módulo `uat` existe pero no sé si está firmado.
5. **Despliegue** — no hay evidencia aquí de la URL de producción.
6. **Matriz legal RD (§8)** — tablas `regulatory_requirements` / equivalente: hay módulo `compliance` y migración `compliance_penal_program.sql`, pero no verifiqué cobertura normativa (Ley 42-01, MSP, cámara hiperbárica).

---

## 6. Rama actual: `claude/vibrant-babbage-8q8oc8`

2 commits no mergeados, **sin PR abierto**:

1. `f8b0c79` — UX de formularios fase 1 (focus, aria, spinner, autocomplete, inputmode, requeridos)
2. `cfd7cb8` — UX fase 2 (toast, auto-save a localStorage, validación on-blur, barra de progreso)

⚠ **Riesgo con §15 del prompt**: el commit 2 guarda borradores de **donantes** e **incidentes** en `localStorage`. El prompt §15 prohíbe explícitamente *"almacenar datos clínicos sensibles en almacenamiento local del navegador como fuente principal"*. Borrador temporal es un caso límite — hay que revisar si captura cédula / grupo / datos de salud, y añadir expiración o cifrado o excluir esos campos.

---

## 7. Riesgos de implementación identificados

| Riesgo | Gravedad | Mitigación |
|---|---|---|
| Discrepancia de repo con prompt | Alta | Confirmar con usuario antes de tocar más |
| `localStorage` con posibles datos de donante (commit cfd7cb8) | Media-alta | Revisar y restringir campos o cifrar |
| 211 módulos sin ejecutar = no hay prueba viva de que cada ruta carga | Media | Correr `frontend-browser-smoke.yml` contra PR / deploy |
| Supabase RLS sin verificar en sesión | Media | Correr `C11_91_SECURITY_DOCTOR_READONLY.sql` |
| Co-authors previos del branch dicen "Claude Opus 4.6"; convención actual pide 4.7 | Baja | Enmendar a partir del próximo commit |

---

## 8. Plan propuesto (Fase 1 ejecutable)

Dado que la arquitectura ya existe, la Fase 1 no es "construir fundamentos" sino **verificar y cerrar brechas**:

**Paso 1 — Verificación en vivo** (bloqueado hasta tener acceso al deploy o a Supabase):
- Confirmar que cada ruta de `router.js` monta sin error.
- Listar tablas sin datos reales.
- Correr `C11_90` y `C11_91`.

**Paso 2 — Cerrar el PR de UX pendiente de esta rama**:
- Revisar el riesgo de localStorage con datos clínicos.
- Abrir PR draft contra main.
- Correr smoke frontend.

**Paso 3 — Elegir el próximo módulo prioritario según prompt §5** (Laboratorio) y auditarlo internamente:
- Verificar cobertura de equipos, mantenimiento preventivo/correctivo, temperaturas, limpieza, tareas, insumos.
- Reportar brechas concretas (no estructurales) con tests que las demuestren.

**Paso 4 — Matriz regulatoria RD** (§8) — requiere fuentes oficiales que necesitan acceso web; hay que confirmar si está dentro del alcance de esta sesión.

---

## 9. Qué **no** voy a hacer sin autorización explícita

- Crear tablas o migraciones nuevas.
- Tocar `js/config.js`.
- Modificar RLS en Supabase.
- Crear proyecto Supabase nuevo.
- Habilitar servicios de pago.
- Borrar datos.
- Mergear a `main`.
- Desplegar.

---

## 10. Pregunta de bloqueo para el usuario

1. ¿Confirma que el repo correcto es `hemocurard-Operation/operations` (lo que estoy viendo)?
2. ¿Prefiere que (a) **primero cierre la rama UX actual** con PR y revisión del riesgo de localStorage, o (b) **pause esa rama y empiece la auditoría viva del módulo Laboratorio** como pide el prompt §5?
3. ¿Hay URL de despliegue a la que pueda apuntar `frontend-browser-smoke` para validar carga de rutas?
