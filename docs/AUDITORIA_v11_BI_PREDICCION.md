# Auditoría §11 BI y Predicción — estado real

**Fecha:** 2026-11-13
**Base:** `origin/claude/vibrant-babbage-8q8oc8` tras §10 Finanzas (`b35db08`)
**Alcance:** Prompt §11 contra el stack BI/predictivo.
**Método:** lectura de `bi.js`, `predictive.js`, `predictive-data.js`, `ops-dashboard.js`, `command-center.js`, `decision-center.js`, `orchestration.js`, `dashboard.js`, y migraciones `20261012120555_predictive_chain_50_foundation.sql` + `20261012121002_predictive_chain_50_hardening.sql` + `20261012121216_predictive_chain_50_network_effectiveness.sql`.

---

## Mapeo del prompt §11 contra el stack

### Indicadores operativos exigidos por el prompt

| Indicador | Fuente real | Estado |
|---|---|---|
| Inventario disponible | `vw_stock_risk_projection.available_units` + `bi.js` KPI "Unidades disponibles" | ✅ |
| Stock crítico | `vw_stock_risk_projection.risk_level ∈ CRITICO/ALTO` | ✅ |
| Vencimientos | `vw_avoidable_loss_signals` + `vw_reagent_alerts` | ✅ |
| Donaciones | `bi.js` KPI "Donantes" + `vw_branch_productivity_30d` | ✅ |
| Donantes diferidos | `donors.status` + reporte donantes (⚠ ver brecha §6.4 reporte diario) | ⚠ Parcial |
| Temperaturas | `labSignals` + `cold-chain` | ✅ |
| Equipos fuera de servicio | `labSignals` resources tab | ✅ |
| Mantenimientos pendientes | `labSignals` next_due_date | ✅ |
| Cumplimiento de limpieza | ❌ Depende de Brecha §5.8 (módulo limpieza ausente) | ❌ |
| Ventas | `bi.js` KPI "Facturado hoy" + `vw_cash_collection_forecast` | ✅ |
| Costos | `vw_monthly_product_costs` | ✅ |
| Calidad | `vw_predictive_action_candidates` con dominio CALIDAD + `labSignals` | ✅ |
| Logística | `commercial_calendar`, `transport`, `dispatch` — métricas vía `vw_service_level_performance` | ✅ |

### Análisis predictivo (8 bullets del prompt)

| # | Bullet prompt | Vista / tabla | Estado |
|---|---|---|---|
| 1 | Proyección de demanda de hemocomponentes | `vw_predictive_demand_30d` | ✅ |
| 2 | Predicción de consumo de insumos | `vw_blood_supply_plan` (plan) + `vw_supply_alerts` (alertas). **No vi forecast temporal de consumo por insumo** | ⚠ Parcial |
| 3 | Estimación de necesidades de compra | `vw_blood_supply_plan.stock_status` da la señal; no hay cantidad sugerida de compra ni horizonte de reposición explícito | ⚠ Parcial |
| 4 | Alertas de mantenimiento | `labSignals` + `next_maintenance_date` + `next_calibration_date` | ✅ |
| 5 | Proyección de gastos | ❌ Depende de Brecha F2 (cash flow — AP no existe) | ❌ |
| 6 | Predicción de riesgo de vencimiento | `vw_avoidable_loss_signals` + `vw_stock_risk_projection` | ✅ |
| 7 | Tendencias de donación | `vw_branch_productivity_30d` y `donor-outreach` dan lo histórico; **no vi vista de tendencia proyectada ni estacionalidad** | ⚠ Parcial |
| 8 | Análisis de productividad por sucursal | `vw_branch_productivity_30d` + comparativo en `bi.js` + `vw_service_level_performance` | ✅ |

---

## Fortalezas

- **Flujo dato → señal → recomendación → decisión → acción → eficacia** implementado como contrato en `predictive_decision_reviews` + `vw_predictive_action_candidates` + `vw_predictive_action_queue`. Alineado con el espíritu del prompt §11 ("nunca presentar predicciones como hechos confirmados").
- **Decisión humana obligatoria**: el UI de `predictive.js` fuerza ACEPTAR / DIFERIR antes de convertir una señal en `integrated_actions`. No hay automatización ciega.
- **Hardening con tres migraciones** sucesivas (foundation → hardening → network_effectiveness) — muestra madurez incremental revisada.
- **`vw_customer_health_score`** combina SLA + saldo + deuda vieja + seguimientos abiertos en un score comparable entre clientes.
- **`bi.js` muestra comparativo por sucursal + embudo sanguíneo 30 días** (donantes → efectivas → recolectadas → tamizadas → liberadas → disponibles → despachadas). Visibilidad completa del funnel.
- **`vw_cash_collection_forecast`**: hay forecast del lado ingreso (cobranza esperada). Esto es raro y bueno — pero no existe el gemelo del lado egreso (ver §10 F2).

---

## Brechas

### Brecha BI1 — Metadata de predicción NO expuesta al usuario (§11 último párrafo)
**Severidad:** Alta (regulatoria y de confianza).
**Qué dice el prompt literalmente:**
> *"Mostrar: Datos utilizados · Fecha de actualización · Horizonte de predicción · Método · Nivel de incertidumbre · Limitaciones. Nunca presentar predicciones como hechos confirmados."*
**Realidad:** `predictive.js` muestra señales con prioridad y recomendación pero **no muestra**:
- Qué filas/tablas alimentan cada señal (data lineage).
- Timestamp de la última actualización de cada vista.
- Horizonte (30/60/90 días — algunas vistas lo tienen implícito en el nombre pero no explícito).
- Método (regla heurística vs. agregación vs. modelo estadístico).
- Intervalo de confianza o nivel de incertidumbre.
- Limitaciones (datos faltantes, últimas N días con huecos, etc.).
**Impacto:** un auditor o un médico que ve "stock crítico ALTO" no puede juzgar si la señal es sólida o frágil. Legalmente y éticamente, para una herramienta clínica, esto importa.
**Trabajo:** cada vista predictiva debería tener campos `data_as_of`, `horizon_days`, `method`, `confidence_pct`, `limitations[]` + UI que los muestre. Alternativa barata: tabla `predictive_meta(view_name, method, horizon_days, last_refreshed_at, limitations_text)` consultada por el frontend.

### Brecha BI2 — Forecast de consumo de insumos (prompt §11 bullet 2)
**Severidad:** Media.
**Qué falta:** `vw_supply_consumption_forecast(product_id, branch_id, horizon_days, projected_quantity, method)` para pasar de "aquí hay alerta" a "en 21 días necesitamos comprar X".
**Trabajo:** vista con promedio móvil 90d × factor estacional + alerta si `days_until_stockout < lead_time + safety_stock`.

### Brecha BI3 — Forecast de gastos
**Severidad:** Media-alta.
**Depende de Brecha F1 + F2 (ver §10)**. Sin CxP no hay forecast de egresos; sin forecast de egresos no hay cash forecast completo.

### Brecha BI4 — Tendencia de donación proyectada
**Severidad:** Media.
**Realidad:** `vw_branch_productivity_30d` es histórico. El forecast de demanda sí existe (`vw_predictive_demand_30d`), pero no el de **oferta** (donantes esperados en los próximos 30 días por campaña, estacionalidad, histórico).
**Impacto:** decisiones de intensificar captación llegan tarde.
**Trabajo:** `vw_donor_outlook` que proyecte donaciones efectivas combinando campañas activas, histórico por sucursal y conversión por canal.

### Brecha BI5 — Indicador de limpieza (prompt §11 operativo)
Ya reportada: depende de Brecha §5.8.

---

## 🔎 Verificaciones vivas

1. ¿Cuándo se refrescan las vistas predictivas? ¿Son `view` (realtime, lentas) o `materialized view` (rápidas pero rezagadas)? No vi `materialized` en el grep.
2. ¿Qué método usan `vw_predictive_demand_30d` y `vw_stock_risk_projection` — regla simple, regresión, nada?
3. ¿`vw_predictive_action_queue` tiene ya señales reales en producción, o está esperando datos?
4. ¿La gerencia ya usa `predictive.js` para decisiones, o es dashboard parado?
5. ¿Hay export de los KPIs a PDF/CSV para la revisión mensual?

---

## Veredicto global §11

**El andamiaje predictivo es sorprendentemente sólido** para una app sin stack ML. Tiene:
- Flujo dato → señal → decisión humana → acción → eficacia como contrato.
- 8 vistas predictivas + 3 migraciones de hardening.
- UI que obliga al operador a aceptar o diferir.
- BI con embudo sanguíneo completo.

**Donde queda por debajo del prompt:** la **transparencia sobre el propio pronóstico**. El prompt es explícito en pedir método, horizonte, incertidumbre y limitaciones en pantalla. Hoy no se muestran. Esta es la brecha más importante — no por cantidad de código sino por lo que dice sobre confianza clínica.

Las dos otras brechas (forecast de insumos, forecast de donantes) son ampliaciones de lo que ya existe.

---

## Propuesta de siguiente PR

**PR-BI1 (medio)** — Metadata de predicción:
1. Tabla `predictive_meta(view_name, method, horizon_days, last_refreshed_at, limitations)` con seed por vista.
2. Modificar `loadPredictive()` para traer la metadata y mostrar en el UI debajo de cada card: *"Fuente · Fecha · Horizonte · Método · Limitaciones"*.
3. Añadir banner global: *"Las proyecciones son herramientas de decisión, no hechos confirmados. Última actualización: X."*

Trabajo pequeño, alto impacto en confianza y cumplimiento. Sin schema change grande.

---

## Pregunta de bloqueo

1. ¿Autorizas **PR-BI1** (metadata de predicción)? Es el trabajo más barato de este set y toca directamente el requisito explícito del prompt.
2. ¿Priorizas **BI2** (forecast insumos) o **BI4** (forecast donantes) en el siguiente batch?
3. ¿Las vistas son `view` o `materialized view`? Si lo segundo, ¿cada cuánto se refrescan?
