# HemoCura · Decision Chain 50 — Execution Report

**Release candidate:** 0.46.0  
**Scope:** transformar la cadena de valor en cadena de decisión.  
**Regla:** una iteración solo se considera cerrada cuando existe evidencia de código/esquema y pasa los gates de CI.

## Ruta objetivo

Demanda → SLA → Despacho → Venta → Cobranza → Rentabilidad → Merma → Red Médica → Señal → Acción → Eficacia.

## Iteraciones I151–I200

| ID | Iteración | Evidencia |
|---|---|---|
| I151 | Enlazar demanda con despacho | `dispatches.demand_request_id` |
| I152 | Registrar despacho que satisface demanda | `clinical_demand_requests.fulfilled_dispatch_id` |
| I153 | Registrar fecha real de atención | `fulfilled_at` |
| I154 | Crear vista SLA demanda→despacho | `vw_service_level_performance` |
| I155 | Calcular minutos de respuesta | `response_minutes` |
| I156 | Clasificar SLA | A_TIEMPO / FUERA_SLA / PENDIENTE |
| I157 | Crear módulo Desempeño y SLA | `#serviceperformance` |
| I158 | Permitir vinculación operativa | selector demanda↔despacho |
| I159 | Gobernar acceso SLA | SERVICE_PERFORMANCE_VIEW/WRITE |
| I160 | Integrar SLA en Mi trabajo | prioridad operativa |
| I161 | Enlazar venta con cliente | `operational_sales.customer_id` |
| I162 | Enlazar venta con demanda | `operational_sales.demand_request_id` |
| I163 | Añadir fecha de factura | `invoice_date` |
| I164 | Añadir fecha de vencimiento | `payment_due_date` |
| I165 | Crear libro de cobros | `customer_payments` |
| I166 | Crear aging de cuentas | `vw_accounts_receivable` |
| I167 | Calcular saldo por venta | paid/outstanding |
| I168 | Clasificar cartera | VIGENTE, 1-30, 31-60, 61-90, >90 |
| I169 | Crear módulo Cobranza y Aging | `#collections` |
| I170 | Gobernar cobranza | COLLECTIONS_VIEW/WRITE |
| I171 | Crear registro de pérdidas | `inventory_loss_events` |
| I172 | Calcular pérdida económica | quantity × unit_cost |
| I173 | Clasificar causa de pérdida | vencimiento, descarte, cadena frío, etc. |
| I174 | Crear vista económica de merma | `vw_inventory_loss_economics` |
| I175 | Crear rentabilidad por cliente | `vw_customer_profitability` |
| I176 | Crear contribución por sucursal | `vw_branch_contribution` |
| I177 | Añadir costo de campaña | planned/actual cost |
| I178 | Añadir contactos alcanzados | `contacts_reached` |
| I179 | Calcular costo por donación | `vw_campaign_economics` |
| I180 | Crear módulo Economía y Merma | `#economics` |
| I181 | Crear maestro de referidores | `medical_referrers` |
| I182 | Registrar especialidad/organización | campos del maestro |
| I183 | Crear eventos de referencia | `medical_referral_events` |
| I184 | Enlazar referencia con cliente | `customer_id` |
| I185 | Enlazar referencia con demanda | `demand_request_id` |
| I186 | Crear embudo de referencia | REFERIDO→CONTACTADO→CONVERTIDO |
| I187 | Calcular conversión por médico | `vw_medical_network_performance` |
| I188 | Crear módulo Red Médica | `#medicalnetwork` |
| I189 | Gobernar red médica | MEDICAL_NETWORK_VIEW/WRITE |
| I190 | Integrar red médica en Mi trabajo | prioridad comercial-operativa |
| I191 | Crear bandeja de señales | `vw_decision_action_candidates` |
| I192 | Detectar demandas fuera SLA | candidato DEMANDA |
| I193 | Detectar CxC vencida | candidato COBRANZA |
| I194 | Detectar merma sin acción | candidato MERMA |
| I195 | Detectar feedback pendiente | candidato CLIENTE |
| I196 | Evitar duplicados de acciones abiertas | `not exists integrated_actions` |
| I197 | Crear acción desde señal | `createActionFromCandidate()` |
| I198 | Crear módulo Centro de Decisión | `#decisioncenter` |
| I199 | Reconciliar RLS y políticas antiguas | authenticated + permisos explícitos |
| I200 | Reconciliar runtime, versión, migraciones y safety gate | 0.46.0 |

## Límites clínicos

Ningún módulo nuevo determina elegibilidad de donantes, interpreta tamizaje, decide compatibilidad, autoriza liberación clínica ni sustituye al profesional responsable. Las nuevas relaciones son operativas, financieras, comerciales y de mejora.

## Migraciones vivas

- `20261012112438` — `decision_chain_50_foundation`
- `20261012112931` — `decision_chain_50_access_hardening`

## Resultado arquitectónico

La Suite ya puede recorrer: **señal → prioridad → acción → responsable → evidencia → eficacia**, conectando desempeño de servicio, dinero, pérdida económica y generación de demanda médica con el SGC.
