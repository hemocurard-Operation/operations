# Auditoría §10 Finanzas — estado real

**Fecha:** 2026-11-13
**Base:** `origin/claude/vibrant-babbage-8q8oc8` tras §9 Comercial (`c482589`)
**Alcance:** Prompt §10 contra el stack financiero.
**Método:** lectura de `economics.js`, `costs.js` (332 líneas), `collections.js`, `suppliers.js`, `procurement.js`, `quotations.js`, migraciones `sql/37_SUPPLIERS_PROCUREMENT`, `20261016201356_purchase_receiving.sql`, `20261102140000_purchase_receipt_inventory_link.sql`, `20261107000948_supplier_quotations.sql`.

---

## Veredicto por bullet del prompt §10

| Prompt §10 | Realidad | Estado |
|---|---|---|
| Catálogo de suplidores | `public.suppliers` + evaluaciones + incidentes (`sql/37`) | ✅ Operativo |
| **Cuentas por pagar** | ❌ **No encontré tabla** `supplier_payments`, `accounts_payable` ni equivalente. Los `purchase_orders` + `purchase_receipts` no llevan estado de pago | ❌ **Ausente** |
| Cuentas por cobrar | `collections.js` + vista con aging (0/1-30/31-60/61-90/90+ días), monto pendiente por cliente, acción "Registrar cobro" | ✅ Operativo |
| Costos de transporte | `cost-entries` incluye `transport_cost` como componente; vista `vw_monthly_product_costs` lo descompone | ✅ Operativo |
| Gastos operativos | `cost_entries` + `vw_monthly_product_costs` con material/labor/screening/indirect/waste/transport/other | ✅ Operativo |
| Requisiciones | `requisitions` + `requisition_lines` (sql/22) + `integrated-qms-data.js` las enlaza con compras | ✅ Operativo |
| Compras | `purchase_orders` + `purchase_order_lines` (sql/37) + recepciones | ✅ Operativo |
| **Cotizaciones y comparación entre proveedores** | `supplier_quotations` + `quotation_decisions` (migración 2026-11-07, reciente) | ✅ Operativo |
| Presupuestos | ❌ No encontré `budgets` / `budget_lines` / `budget_vs_actual` | ❌ **Ausente** |
| Cuadre diario de donantes | ❌ Relacionado con Brecha D2 (buscones) — no hay `donor_reconciliations` | ❌ **Ausente** (ya reportado en §6) |
| Conciliación de ingresos | `collections` registra cobros; falta reporte unificado "efectivo + transferencia + oficina + crédito" por día | ⚠ Parcial |
| Costos por sucursal | `vw_monthly_product_costs.branch_id` + filtro por sucursal | ✅ Operativo |
| Costos por servicio | `product_id` en costos + join a servicios vía `sales_items` | ✅ Operativo |
| **Proyecciones financieras** | ❌ No vi `cash_flow_projections` ni módulo de forecast financiero. `predictive-data.js` es operativo, no financiero | ❌ **Ausente** |
| Métodos de pago (efectivo / transferencia / oficina / crédito) | `sales` registra `payment_method`; `collections` idem | ✅ Operativo |
| Importes derivados de transacciones reales, no ejemplos | No vi seeds con valores falsos en migraciones | ✅ Alineado con §10 último bullet |

---

## Fortalezas

- **Workflow de cierre de costos mensuales**: `monthly_cost_periods` con estados BORRADOR / VALIDACION / PRECIERRE / APROBADO / CERRADO, RPCs `calculate_monthly_product_costs` y `approve_monthly_cost_period`. Costo no se cierra sin aprobación independiente.
- **Descomposición granular**: material + labor + screening + indirect + waste + transport + other. Permite imputación trazable.
- **Variance vs. período anterior**: `variance_amount` y `variance_pct` listos para alertar cambios bruscos de costo unitario.
- **Aging buckets dominicanos estándar**: 0 / 1-30 / 31-60 / 61-90 / 90+ días. Suma por bucket y por cliente.
- **Recepción vinculada a inventario**: migración 2026-11-02 conecta `purchase_receipts` con movimientos de inventario — evita recepción sin impacto en stock.
- **Quotations con decisiones trazables**: `quotation_decisions` separa la cotización de la decisión de compra, con responsable.
- **`close_operational_day`** + `evaluate_daily_close` + `daily_close_checks`: gates de cierre operativo diario a nivel de base de datos.

---

## Brechas

### Brecha F1 — Cuentas por pagar (§10 bullet 2) **CRÍTICA**
**Severidad:** Alta.
**Qué falta:**
- Tabla `supplier_payables(id, supplier_id, purchase_order_id, invoice_number, invoice_date, due_date, amount_total, amount_paid, outstanding_amount, status, payment_terms)`.
- Tabla `supplier_payments(id, supplier_id, payable_id, paid_at, payment_method, amount, reference, authorized_by, posted_by)`.
- Aging equivalente al de CxC en `collections.js` pero para proveedores.
- Trigger: una OC recepcionada genera `supplier_payable` automáticamente al cruzarse con factura.
**Impacto:** sin AP, HemoCura no sabe cuánto debe. Toda la gestión de tesorería queda fuera del sistema (Excel).
**Trabajo:** migración + módulo `payables.js` + reportes de edad de deuda y proyección de egresos.

### Brecha F2 — Proyecciones financieras (§10 "proyecciones financieras")
**Severidad:** Media-alta.
**Qué falta:**
- Vista/tabla `cash_flow_projection` con egresos esperados (payables) + ingresos esperados (receivables ponderados por probabilidad de cobro o por histórico de días de pago por cliente).
- Horizonte 30/60/90 días.
- Alerta de brecha de caja proyectada.
**Depende de F1**: sin AP no hay egresos proyectados confiables.

### Brecha F3 — Presupuestos (§10 "presupuestos")
**Severidad:** Media.
**Qué falta:**
- `budgets(period_month, branch_id, category, amount_budget)` + comparación `budget_vs_actual` contra `cost_entries` y `sales`.
- UI de variación con alertas por categoría.
**Puede quedar para fase posterior** si la gerencia hoy no planifica por presupuesto.

### Brecha F4 — Conciliación de ingresos diaria (§10 "conciliación de ingresos")
**Severidad:** Media.
**Qué falta:** reporte unificado por día + sucursal: ventas por método de pago (efectivo / transferencia / oficina / crédito), total declarado, diferencia con cobros registrados. Útil para controles anti-fraude y cuadre de caja.
**Trabajo:** vista + UI. Sin schema change nuevo — todo está en `sales`, `collections`, `payment_method`.

### Brecha F5 — Cuadre diario donantes (§10 "cuadre diario de donantes")
**Severidad:** Alta.
Ya reportada en Brecha D2 (buscones). Es la misma brecha vista desde el lado financiero: al no haber `donor_referrers` ni `donor_referrals`, los pagos de captación quedan sin registro ni conciliación.

---

## 🔎 Verificaciones vivas

1. ¿Tesorería usa hoy Excel / contabilidad externa para AP? Si sí, F1 debe incluir import o doble-entry temporal.
2. ¿Hay suplidores con crédito > 30 días que ya esperaría ver en reporte AR equivalente (pero al revés)?
3. ¿El `close_operational_day` ya está siendo invocado diariamente, o es RPC inactivo?
4. ¿`vw_monthly_product_costs` tiene valores reales o está vacía esperando migración de un ERP externo?
5. ¿Existe ya un proceso manual de cash forecast en Excel que podamos modelar en F2?

---

## Veredicto global §10

- **Lado ingreso + cobros + costos + compras:** maduro y trazable. Aging bucket, workflow de aprobación de costos, variance analysis, quotations con decisión, recepción vinculada a inventario.
- **Lado egreso (AP) + planificación financiera (budget, cash flow):** **grandes vacíos**. Falta la mitad financiera de la ecuación.
- **Conciliación diaria unificada** pendiente de reporte consolidador.

Para gerencia financiera: el sistema hoy sirve para **ver qué se vendió, qué se cobró y cuánto costó producirlo**. No sirve para **ver qué se debe, cuándo hay que pagarlo, y si habrá caja para eso**.

---

## Propuesta de siguientes PRs

1. **PR-F1 (alto, prioridad #1)** — Cuentas por pagar. Schema change con dos tablas + módulo + aging. Requiere autorización por impacto.
2. **PR-F4 (bajo, prioridad #2)** — Reporte de conciliación diaria de ingresos por método de pago. Vista SQL + UI, sin schema change.
3. **PR-F2 (medio, prioridad #3, depende de F1)** — Proyección de caja 30/60/90.
4. **PR-F3 (bajo-medio, prioridad #4)** — Presupuestos y budget_vs_actual.

---

## Pregunta de bloqueo

1. ¿Autorizas **PR-F1** (Cuentas por pagar)? Es la brecha financiera más grave.
2. ¿Autorizas **PR-F4** (conciliación diaria)? Bajo riesgo, sin schema change.
3. ¿Hay contabilidad externa (ERP, proveedor contable) con la que haya que conciliar? Si sí, F1 debe exportar a ese sistema.
