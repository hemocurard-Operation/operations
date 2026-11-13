# Plan ejecutivo HemoCura v11 — consolidación de auditorías

**Fecha:** 2026-11-13
**Base:** rama `claude/vibrant-babbage-8q8oc8`, 9 auditorías temáticas en `docs/AUDITORIA_v11_*.md`.
**Propósito:** priorizar las 30 brechas detectadas, asignarles fase y criterio de aceptación, y proponer un orden de ejecución realista.

---

## 1. Punto de partida

- **Versión actual:** v0.66.0, canal RC, `clinical_core: LIVE-LIMITED / CONTROLLED_RELEASE`.
- **Arquitectura ya construida:** 211 módulos JS, 55 rutas, 52 migraciones, 40 workflows CI, 7 familias.
- **El proyecto no está en Fase 0.** La Fase 1 propuesta por el prompt no es "construir fundamentos" sino **cerrar brechas puntuales sobre un sistema maduro**.
- **Riesgo heredado del PR anterior** (localStorage con datos clínicos) ya mitigado en commit `abaa666`.

---

## 2. Inventario de brechas por fase del prompt

### Fase 1 — Fundamentos (prompt §16 Fase 1)

Prompt pide: estructura modular, autenticación, roles, sucursales, catálogos, auditoría, base de datos.
**Estado real:** ya construido. **Trabajo real:** evidencia.

| ID | Brecha | Severidad | Auditoría |
|---|---|---|---|
| S1 | MFA / session / password policy (config Auth) | Media-alta | §15 |
| S2 | Prueba de restauración de backup documentada | Media-alta | §15 |
| S3 | audit_events cobertura financiera | Media | §15 |
| S4 | security_invoker=true en vistas predictivas | Media | §15 |
| S5 | Auditar edge function change_password | Media | §15 |
| Verif-vivas-§15 | Correr `C11_91` + `C12_00` + trazabilidad end-to-end + RLS cross-sucursal | Alta | §15 |

### Fase 2 — Laboratorio (prompt §16 Fase 2)

| ID | Brecha | Severidad | Auditoría |
|---|---|---|---|
| L1 | Módulo y tablas de limpieza de equipos (§5.8) | Alta | §5 |
| L2 | Captura `equipment_usage` para preventivo por consumo (§5.6) | Media | §5 |
| L3 | Verificar expediente completo de equipo (fabricante, serie, garantía) | Media | §5 |

### Fase 3 — Operaciones

Sin brechas específicas detectadas. Inventario, captura diaria, logística, transporte ya operativos. **Trabajo aquí = verificaciones vivas.**

### Fase 4 — Donantes (prompt §16 Fase 4)

| ID | Brecha | Severidad | Auditoría |
|---|---|---|---|
| D1 | Reporte diario de donantes (§6.4) | Alta | §6 |
| D2 | Cuadre de buscones/captadores (§6.5) | Alta + legal | §6 |
| D3 | Intervalos de donación configurables por tipo (§6.2) | Media | §6 |
| D4 | CHECK enumerado en `donors.status` | Media (verif viva) | §6 |

### Fase 5 — Calidad y Compliance

| ID | Brecha | Severidad | Auditoría |
|---|---|---|---|
| Q1 | Motor genérico de formularios | Media-alta (decisión) | §7 |
| Q2 | Exportación PDF firmada | Media | §7 |
| Q3 | Indicador de limpieza (depende L1) | Baja | §7 |
| C1 | Matriz regulatoria general (42-01, 349-04, 172-13, 87-01, 64-00, MSP) | Alta | §8 |
| C2 | Habilitaciones sanitarias por sucursal con alertas | Alta | §8 |
| C3 | Compliance cámara hiperbárica (requiere investigación legal) | Media | §8 |
| C4 | Matriz operacional Ley 172-13 (subset de C1) | Media | §8 |

### Fase 6 — Comercial y Finanzas

| ID | Brecha | Severidad | Auditoría |
|---|---|---|---|
| CM1 | Metas comerciales + pipeline de oportunidades | Alta | §9 |
| CM2 | Visitas tipificadas (purpose enum) | Baja | §9 |
| CM3 | Verificar `commercial_agenda_union` | Baja (verif viva) | §9 |
| **F1** | **Cuentas por pagar completas** | **Alta/crítica** | §10 |
| F2 | Proyección de caja 30/60/90 (depende F1) | Media-alta | §10 |
| F3 | Presupuestos y budget_vs_actual | Media | §10 |
| F4 | Conciliación diaria de ingresos por método de pago | Media | §10 |
| F5 | Cuadre de donantes (= D2 vista desde finanzas) | Alta | §10 |

### Fase 7 — Inteligencia predictiva

| ID | Brecha | Severidad | Auditoría |
|---|---|---|---|
| BI1 | Metadata de predicción (datos, horizonte, método, incertidumbre, limitaciones) visible | **Alta (confianza clínica)** | §11 |
| BI2 | Forecast temporal de consumo de insumos | Media | §11 |
| BI3 | Forecast de gastos (depende F1+F2) | Media-alta | §11 |
| BI4 | Forecast de donantes/oferta proyectada | Media | §11 |
| BI5 | Indicador de cumplimiento de limpieza (=L1→Q3) | Baja | §11 |

---

## 3. Orden de ejecución propuesto

Priorizado por **(severidad × desbloqueos × riesgo bajo)**, no por orden de fase del prompt.

### Sprint 0 — Evidencia viva (bloqueador de todo lo demás)
**Requisito:** acceso SQL read-only a Supabase + snapshot de config Auth.
1. Correr `C11_91_SECURITY_DOCTOR_READONLY.sql` → `docs/C11_91_doctor_2026-XX.md`.
2. Correr `C12_00_PREFLIGHT_SECURITY_HARDENING.sql` → `docs/C12_00_preflight_2026-XX.md`.
3. Test trazabilidad end-to-end unidad sanguínea (workflow CI).
4. Documentar Supabase Auth config (MFA, session, password).
5. Documentar última prueba de restauración de backup.
6. Resolver las verificaciones 🔎 abiertas en cada auditoría temática.

**Criterio de aceptación:** 6 documentos de evidencia en `docs/` + workflow `.github/workflows/traceability-smoke.yml` verde.

### Sprint 1 — Mitigaciones baratas de alto impacto
Todas con PRs cortos, bajo riesgo, sin schema change grande.
1. **PR-BI1** — tabla `predictive_meta` + UI bajo cada card (fuente, horizonte, método, limitaciones). Alta visibilidad regulatoria.
2. **PR-D1** — reporte diario de donantes: vista SQL + módulo frontend.
3. **PR-F4** — conciliación diaria consolidada por método de pago. Vista + UI.
4. **PR-CM2** — `commercial_visits.purpose` enum + 1 reporte sectorial.
5. **PR-L3** — ampliación de `equipment` si faltan campos (fabricante, serie, garantía, suplidor, documentación).
6. **PR-D4** — CHECK enumerado en `donors.status` + migración de consolidación.
7. **PR-S4** — añadir `security_invoker=true` en vistas predictivas que lo necesiten.

**Criterio de aceptación:** cada PR con smoke test + workflow verde + evidencia manual en navegador.

### Sprint 2 — Ampliaciones del modelo (schema aditivo, autorización previa)
1. **PR-L1** — módulo y tablas de **Limpieza de equipos** (§5.8). Migración + `cleaning.js` + alertas + indicadores. **Desbloquea Q3 y BI5.**
2. **PR-L2** — captura `equipment_usage` + horizonte de preventivo por consumo.
3. **PR-D3** — tabla `donation_interval_rules` + reemplazo del `+84d` hardcoded.
4. **PR-C2** — `facility_licenses` por sucursal con alertas 90/60/30 días.

**Criterio de aceptación:** cada tabla con RLS por sucursal, CHECKs, revisión concurrente, entradas de `audit_events`, test de permisos.

### Sprint 3 — Finanzas lado egreso
1. **PR-F1** — Cuentas por pagar completas: `supplier_payables` + `supplier_payments` + aging + módulo. Desbloquea F2, F3 y BI3.
2. **PR-F2** — `vw_cash_flow_projection` 30/60/90 con ingresos y egresos reales.
3. **PR-F3** — `budgets` + `budget_vs_actual`.

**Criterio de aceptación:** tesorería puede consultar "cuánto debo esta semana" desde el sistema.

### Sprint 4 — Matriz regulatoria general
1. **PR-C1** — `regulatory_requirements` + `regulatory_assessments` + `regulatory_evidence` + módulo `regulatory-matrix.js`. Carga inicial parseada desde `docs/recursos/HC-SGC-Arquitectura-Documental-v1.html` **con revisión legal interna previa al merge**.
2. **PR-C4** — matriz operacional Ley 172-13 como subset de C1.

**Criterio de aceptación:** un inspector MSP recibe del sistema una tabla "norma / artículo / aplicabilidad / responsable / evidencia / última revisión".

### Sprint 5 — Comercial maduro
1. **PR-CM1** — `commercial_goals` + `crm_opportunities` + scoring extendido en el planner. Alta porque toca lógica central del planner.
2. **PR-BI4** — `vw_donor_outlook` (oferta de donantes proyectada).

### Sprint 6 — Predicción avanzada e insumos
1. **PR-BI2** — `vw_supply_consumption_forecast`.
2. **PR-Q2** — Exportación PDF firmada (evaluar peso en `ux-performance-budget`).

### Sprint 7 — Decisiones pendientes
- **Q1 (motor de formularios):** decisión de modelo. No implementar sin que el usuario elija entre "codificado seguro" vs. "configurable con riesgo clínico".
- **D2 (buscones):** requiere revisión legal institucional previa. No se abre PR sin autorización escrita.
- **C3 (cámara hiperbárica):** requiere investigación legal RD sobre normativa aplicable.

### Sprint 8 — Pruebas finales y despliegue (prompt §16 Fase 8)
1. Correr suite completa de workflows.
2. Reporte UAT firmado.
3. Documentación de instalación actualizada.
4. Manual de usuario diferencial (solo módulos nuevos).
5. Registro de cambios v0.66 → v1.0 (si se decide saltar a v1.0 o seguir con v0.6x).
6. Autorización de despliegue clínico.

---

## 4. Criterios de aceptación transversales (prompt §19)

Todo PR debe cumplir:

- Código implementado + ejecutable + con persistencia real.
- Pruebas de permisos y validaciones (unit + workflow).
- Registros auditables en `audit_events` o historial dedicado.
- Workflows CI relevantes verdes (`release-readiness-doctor`, `migration-security-linter`, `runtime-contract-gate`, `ux-performance-budget`, `web-performance-security`).
- Documentación en `docs/` del cambio.
- Sin regresiones conocidas (smoke frontend verde).
- Diferenciación explícita en PR description entre: Implementado · Probado · Desplegado · Pendiente · Bloqueado.

**No declarar terminado un módulo solo porque su UI exista.**

---

## 5. Decisiones que requieren autorización explícita

Agrupo por tipo:

### Schema change (14 PRs)
L1, L2, D3, C1, C2, CM1, F1, F2, F3, BI1 (meta), BI2, BI4, Q1 (si se decide), D2 (si legal lo aprueba).

### Revisión legal previa
D2 (buscones), C3 (cámara hiperbárica), C1 seed inicial.

### Decisión de modelo
Q1 (motor formularios genérico vs. codificado).

### Operativo externo
Config Auth, restauración de backup, acceso SQL read-only.

---

## 6. Qué NO voy a hacer sin autorización explícita (prompt §2 y §13)

- Crear tablas o migraciones nuevas.
- Tocar `js/config.js`.
- Modificar RLS en producción.
- Crear proyecto Supabase nuevo.
- Habilitar servicios de pago.
- Borrar datos.
- Mergear a `main`.
- Desplegar.
- Automatizar pagos a buscones.
- Publicar matriz regulatoria sin revisión legal.

---

## 7. Entregables del prompt §20 — estado

| # | Entregable | Estado | Ubicación |
|---|---|---|---|
| 1 | Auditoría técnica del repositorio | ✅ Completo | `docs/AUDITORIA_v11_FASE0.md` |
| 2 | Inventario de funcionalidades existentes | ✅ Completo | 9 docs `AUDITORIA_v11_*.md` |
| 3 | Arquitectura definitiva | ⚠ No se rediseña (se conserva y amplía) | — |
| 4 | Estructura de navegación | ✅ Documentada en `AUDITORIA_v11_FASE0.md §2` | — |
| 5 | Modelo de datos | ✅ Mapeado en `AUDITORIA_v11_DATOS_Y_SEGURIDAD.md §12` | — |
| 6 | Migraciones | ⚠ Pendientes de brechas (L1, L2, D3, C1, C2, F1, F2, F3, BI1, BI2, BI4, CM1) | Sprint 2–6 |
| 7 | Código fuente | ✅ Base intacta, parches aditivos pendientes | — |
| 8 | Formularios funcionales | ✅ Codificados; motor genérico pendiente de decisión (Q1) | — |
| 9 | Reportes e indicadores | ⚠ Pendientes brechas (D1, F4, BI1, BI2, BI4) | Sprint 1, 2 |
| 10 | Pruebas automatizadas | ⚠ Pendientes (trazabilidad end-to-end en Sprint 0) | Sprint 0 |
| 11 | Documentación de instalación | ✅ `README.md`, `LEER_PRIMERO.md` | — |
| 12 | Guía de despliegue | 🔎 Verificar `.github/workflows/release-readiness-doctor.yml` | — |
| 13 | Manual de usuario | 🔎 No encontré doc unificado — puede estar en `docs/recursos/` | — |
| 14 | Registro de cambios | ⚠ `RELEASE_MANIFEST.json` existe; actualizar al cerrar brechas | — |
| 15 | Informe de funcionalidades pendientes | ✅ **Este documento** | `docs/PLAN_EJECUTIVO_v11.md` |

---

## 8. Resumen ejecutivo para gerencia

**Qué tiene HemoCura hoy (v0.66 RC):**
Plataforma vanilla JS + Supabase madura, con 55 rutas por 7 familias, 52 migraciones, 40 workflows CI, RLS granular, segregación de funciones a nivel DB, auditoría multi-tabla, predictivo con decisión humana obligatoria, 2 edge functions. Lado ingreso + compras + costos + cobros ya trazable. Compliance Penal, ISO 9001/15189 y QMS funcionales.

**Qué le falta para v11 (30 brechas):**
- **Crítico de negocio:** Cuentas por Pagar (F1), cuadre de buscones (D2/F5).
- **Operativo diario:** reporte diario de donantes (D1), conciliación de ingresos (F4), limpieza de equipos (L1).
- **Compliance:** matriz regulatoria general no-penal (C1), habilitaciones MSP (C2).
- **Confianza clínica:** metadata de predicción visible (BI1).
- **Evidencia viva:** correr doctor scripts, probar RLS cross-sucursal, confirmar MFA + backups.

**Camino más corto a cerrar v11:**
~8 sprints. El bloqueador real es acceso SQL read-only a Supabase para pasar de auditoría a verificación viva.

**Bloqueos que no son técnicos:**
Revisión legal (D2, C3), decisión de modelo (Q1), política institucional de buscones.

---

## 9. Pregunta de bloqueo final

Para empezar el Sprint 0 necesito:

1. **Acceso SQL read-only** a Supabase o alguien que corra los scripts y me pase el JSON.
2. **Snapshot de Auth config** (sin secretos).
3. **Confirmar** cuál de los Sprints 1–7 quieres arrancar primero una vez cerrado el Sprint 0.
4. **Autorización escrita** para Q1 (motor formularios), D2 (buscones), C3 (hiperbárica) o confirmación de que **pausamos** esas 3 hasta tener política institucional.

Sin SQL read-only puedo seguir auditando estáticamente pero no puedo firmar nada.
