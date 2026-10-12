# HemoCura · Orchestration Chain 50 — Execution Report

**Release candidate:** 0.48.0  
**Scope:** señal → resiliencia → escenario → decisión humana → acción → eficacia.

## I251–I300

| ID | Iteración | Evidencia implementada |
|---|---|---|
| I251 | Crear dominio de orquestación | permisos `ORCHESTRATION_VIEW/WRITE` |
| I252 | Heredar lectura desde predictivo/dirección | role_permissions por mínimo privilegio |
| I253 | Limitar escritura a decisores existentes | escritura heredada de `PREDICTIVE_WRITE` |
| I254 | Crear registro de escenarios | `orchestration_scenarios` |
| I255 | Mantener alcance corporativo/sucursal | `branch_id` nullable + RLS |
| I256 | Crear horizontes de escenario | 7/14/30/60/90 días |
| I257 | Simular demanda | `demand_multiplier` |
| I258 | Simular captación | `donor_multiplier` |
| I259 | Simular cobranza | `collection_multiplier` |
| I260 | Simular capacidad | `capacity_multiplier` |
| I261 | Simular reducción de pérdida | `loss_reduction_pct` |
| I262 | Registrar supuestos | `assumptions` |
| I263 | Gobernar ciclo de escenario | BORRADOR/REVISADO/APROBADO/ARCHIVADO |
| I264 | Registrar creador | `created_by` |
| I265 | Registrar revisión humana | `reviewed_by/reviewed_at` |
| I266 | Aplicar RLS | políticas SELECT/INSERT/UPDATE/DELETE |
| I267 | Preparar Data API explícita | GRANT authenticated + REVOKE anon |
| I268 | Indexar cartera de escenarios | branch/status + created_by |
| I269 | Crear score de resiliencia | `vw_branch_resilience_score` |
| I270 | Integrar riesgo de stock | critical/high stock |
| I271 | Integrar acciones predictivas | critical/overdue actions |
| I272 | Integrar pérdidas evitables | loss value 30d |
| I273 | Integrar clientes en riesgo | health score <60 |
| I274 | Clasificar resiliencia | CRITICA/ALTA/MEDIA/CONTROLADA |
| I275 | Crear score de proveedor | `vw_supplier_risk_score` |
| I276 | Penalizar revisión vencida | `review_overdue` |
| I277 | Penalizar proveedor crítico | supplier criticality |
| I278 | Crear eficiencia de captación | `vw_donor_campaign_efficiency` |
| I279 | Medir conversión contacto→donación | `contact_to_donation_pct` |
| I280 | Medir costo por donación | `cost_per_donation` |
| I281 | Medir productividad del gasto | donations per 1000 cost |
| I282 | Crear calidad de datos | `vw_data_quality_readiness` |
| I283 | Detectar ventas sin cliente | sales_without_customer |
| I284 | Detectar ventas sin demanda | sales_without_demand |
| I285 | Detectar despachos sin demanda | dispatches_without_demand |
| I286 | Detectar donaciones sin campaña | recent_donations_without_campaign |
| I287 | Crear data readiness score | 0–100 por sucursal |
| I288 | Crear impacto de escenarios | `vw_scenario_impact` |
| I289 | Proyectar ingreso | demand × capacity |
| I290 | Proyectar donaciones | donor multiplier |
| I291 | Proyectar caja | collection multiplier |
| I292 | Proyectar pérdida | loss reduction |
| I293 | Crear proxy de valor proyectado | `projected_value_proxy` |
| I294 | Crear cola ejecutiva | `vw_orchestration_priority_queue` |
| I295 | Conservar señales predictivas | predictive queue como fuente |
| I296 | Incorporar resiliencia | señal por sucursal |
| I297 | Incorporar proveedor | riesgo de proveedor |
| I298 | Crear paquete de revisión dirección | `vw_management_review_pack_v2` |
| I299 | Integrar cockpit y Mi Trabajo | ruta `#orchestration`, permisos, mount y prioridad |
| I300 | Reconciliar release y QA | VERSION 0.48.0, runtime contract, migración y safety gate |

## Guardrails

- Human-in-the-loop obligatorio: un escenario no ejecuta operaciones, no modifica inventario y no libera componentes.
- Ningún score decide elegibilidad de donantes, interpreta tamizaje o compatibilidad.
- Las vistas nuevas usan `security_invoker=true`.
- `orchestration_scenarios` usa RLS y exposición Data API explícita para anticipar el cambio de Supabase del 30-oct-2026.
- La cola ejecutiva puede crear una acción integrada, pero la acción conserva responsable, evidencia y verificación de eficacia.

## Migración live

- `20261012123236` — `orchestration_chain_50_foundation`
