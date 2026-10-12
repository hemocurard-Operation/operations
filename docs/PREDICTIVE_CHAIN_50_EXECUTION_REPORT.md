# HemoCura · Predictive Chain 50 — Execution Report

**Release candidate:** 0.47.0  
**Scope:** dato → proyección → recomendación → decisión humana → acción → eficacia.

## I201–I250

| ID | Iteración | Evidencia implementada |
|---|---|---|
| I201 | Crear dominio predictivo | permisos `PREDICTIVE_VIEW/WRITE` |
| I202 | Gobernar acceso por rol | role_permissions para gerencias, admin, socio, calidad, finanzas y médico gerente |
| I203 | Crear registro de decisiones | `predictive_decision_reviews` |
| I204 | Mantener alcance por sucursal | RLS + `can_access_branch()` |
| I205 | Separar lectura/escritura | políticas SELECT/INSERT/UPDATE/DELETE |
| I206 | Preparar Data API explícita | GRANT authenticated + REVOKE anon |
| I207 | Trazar decisión | decision + rationale + reviewed_by/at |
| I208 | Soportar diferimiento | `review_due_date` |
| I209 | Enlazar decisión con acción | `linked_action_id` |
| I210 | Indexar cartera predictiva | índices candidate/branch/source/due |
| I211 | Forecast de demanda 30 días | `vw_predictive_demand_30d` |
| I212 | Media diaria 30 días | `avg_daily_30d` |
| I213 | Señal de demanda reciente | `avg_daily_7d` |
| I214 | Tendencia | ALZA/BAJA/ESTABLE |
| I215 | Proyección 7 días | `projected_units_7d` |
| I216 | Backlog de demanda | `open_units` |
| I217 | Stock utilizable | `vw_stock_risk_projection.available_units` |
| I218 | Días de cobertura | `days_cover` |
| I219 | Riesgo stock | CRITICO/ALTO/MEDIO/CONTROLADO |
| I220 | Relacionar ABO/Rh | proyección segmentada por grupo/Rh |
| I221 | Forecast de cobranza | `vw_cash_collection_forecast` |
| I222 | Horizonte de caja 60 días | `forecast_week` |
| I223 | Caja esperada | `expected_cash` |
| I224 | Caja vencida | `overdue_cash` |
| I225 | Score de salud de cliente | `vw_customer_health_score` |
| I226 | Penalizar deuda 61+ | `old_debt` |
| I227 | Incorporar SLA | `sla_pct` |
| I228 | Incorporar feedback | rating + follow-ups |
| I229 | Score 0–100 | `health_score` |
| I230 | Productividad por sucursal | `vw_branch_productivity_30d` |
| I231 | Medir ventas 30d | sales_count/revenue |
| I232 | Medir despachos 30d | dispatch_count |
| I233 | Medir donaciones 30d | donations_count |
| I234 | Restar pérdida económica | `net_value_proxy` |
| I235 | Señales de merma evitable | `vw_avoidable_loss_signals` |
| I236 | Identificar tipos evitables | vencimiento/cadena frío/error/rotura/merma |
| I237 | Priorizar pérdida económica | BAJA/MEDIA/ALTA/CRITICA |
| I238 | Integrar CAPA | candidatos desde CAPA próximos/vencidos |
| I239 | Integrar compliance penal | candidatos desde acciones de compliance |
| I240 | Integrar cobertura stock | candidato de abastecimiento |
| I241 | Integrar cobranza | candidato financiero |
| I242 | Integrar merma | candidato económico |
| I243 | Score de referidores | `vw_referrer_effectiveness_score` |
| I244 | Medir conversión médica | conversion_pct + effectiveness_score |
| I245 | Detectar referidores inactivos | `network_signal=INACTIVO` |
| I246 | Detectar baja conversión | `network_signal=BAJA_CONVERSION` |
| I247 | Crear cola sin duplicados | `vw_predictive_action_queue` excluye decisiones vigentes |
| I248 | Integrar Cockpit Predictivo | ruta `#predictive`, mount, permisos y Mi Trabajo |
| I249 | Mantener human-in-the-loop | Aceptar/Diferir/Crear acción; sin decisiones clínicas automáticas |
| I250 | Reconciliar release y QA | VERSION 0.47.0, runtime contract, migraciones y safety gate |

## Guardrails

- Ninguna proyección decide elegibilidad de donantes, interpreta tamizaje, determina compatibilidad o libera componentes.
- Toda recomendación es una señal de gestión; la decisión humana queda registrada.
- Las vistas nuevas usan `security_invoker=true` y la única tabla nueva tiene RLS.
- Las tablas/vistas nuevas usan grants explícitos para anticipar el cambio de exposición de Data API de Supabase del 30-oct-2026.

## Migraciones live
- `20261012120555` — `predictive_chain_50_foundation`
- `20261012121002` — `predictive_chain_50_hardening`
- `20261012121216` — `predictive_chain_50_network_effectiveness`
