# HemoCura · Value Chain 50 — Execution Report

**Release candidate:** 0.45.12  
**Scope:** end-to-end value creation from demand to improvement  
**Rule:** an iteration is marked implemented only when code/schema exists; final merge remains subject to CI.

## End-to-end route

Demand → Planning → Donor Outreach → Donation → Screening → Production → Release/Inventory → Dispatch → Sale/Collection → Customer Experience → Integrated Improvement.

## Iterations I101–I150

| ID | Iteration | Implemented evidence |
|---|---|---|
| I101 | Define end-to-end value chain | `value_chain_stage_catalog` and `#valuechain` |
| I102 | Create governed stage catalog | VC-01…VC-10 seeded in Supabase |
| I103 | Create branch value scorecard | `vw_value_chain_scorecard` |
| I104 | Expose clinical/operational demand backlog | `clinical_demand_requests` workspace |
| I105 | Add governed demand capture | `createDemand()` + UI dialog |
| I106 | Add demand lifecycle | ABIERTA/EN_PROCESO/ATENDIDA/CANCELADA |
| I107 | Link demand to customer | `customer_id` surfaced in demand form/table |
| I108 | Add product + ABO/Rh context | Product, blood group and Rh fields in demand |
| I109 | Add priority and needed-by | Priority + due datetime in demand |
| I110 | Govern value-chain access | VALUE_CHAIN_VIEW / VALUE_CHAIN_WRITE + branch RLS |
| I111 | Create donor campaign register | `donor_campaigns` |
| I112 | Add campaign lifecycle | PLANIFICADA/ACTIVA/PAUSADA/CERRADA/CANCELADA |
| I113 | Add corporate/branch campaign scope | Nullable `branch_id` with branch RLS |
| I114 | Add campaign channel/audience | channel + audience fields |
| I115 | Add target donor metric | `target_donors` |
| I116 | Add campaign performance view | `vw_donor_campaign_performance` |
| I117 | Connect campaign to donation | `donations.campaign_id` + attribution UI |
| I118 | Add target attainment metrics | captured / remaining / attainment % |
| I119 | Add campaign creation workflow | Captación de Donantes dialog |
| I120 | Add campaign status operation | Inline campaign status control |
| I121 | Add customer value module | `#customers` |
| I122 | Govern customer writes | CUSTOMER_VIEW / CUSTOMER_WRITE + RLS |
| I123 | Add customer value summary | `vw_customer_value_summary` |
| I124 | Add service-level agreements | `customer_service_agreements` |
| I125 | Support corporate/branch SLA | Nullable branch scope |
| I126 | Add response target | `target_response_minutes` |
| I127 | Add SLA priority | NORMAL/PREFERENTE/CRITICA |
| I128 | Add customer feedback register | `customer_feedback` |
| I129 | Add rating and follow-up flag | rating + requires_followup |
| I130 | Connect customer to revenue/collection | billed + collected + sales count summary |
| I131 | Create integrated master actions | `integrated_actions` |
| I132 | Support multi-source actions | `source_domain`, `source_table`, `source_id` |
| I133 | Support corporate/branch actions | Nullable branch scope |
| I134 | Add priority and due date | action priority + due_date |
| I135 | Add action ownership | Claim action to current user |
| I136 | Require evidence on completion workflow | Evidence reference captured at completion |
| I137 | Add effectiveness verification | PENDIENTE/EFICAZ/NO_EFICAZ/NO_APLICA |
| I138 | Close effective / reopen ineffective | Verification workflow controls state |
| I139 | Add overdue portfolio | `vw_integrated_actions_open.overdue` |
| I140 | Add action KPIs | Open, overdue, critical, efficacy pending |
| I141 | Add `CADENA DE VALOR` navigation group | Router group |
| I142 | Register routes/mounts/views | layout/router/views updated |
| I143 | Assign role-based permissions | 8 permission codes mapped by role |
| I144 | Integrate value work into `Mi trabajo` | valuechain/actions/outreach/customers prioritized |
| I145 | Harden RLS to authenticated-only | New domain policies use `TO authenticated` |
| I146 | Use security-invoker views | Four new views use `security_invoker=true` |
| I147 | Reconcile runtime contract | Optional runtime declarations in 0.45.12 |
| I148 | Record live migrations in repository | 3 migration files under `supabase/migrations` |
| I149 | Add automated safety gate | `value-chain-safety.yml` |
| I150 | Harden policy/index performance and release metadata | split write policies, focused indexes, VERSION 0.45.12 |

## Security and clinical boundaries

- No `service_role` key is used in the browser.
- New exposed tables use RLS.
- New analytical views are `security_invoker=true`.
- Donor campaign attribution changes only `donations.campaign_id`; it does not determine donor eligibility, screening interpretation, component compatibility, or release.
- Administrative and technology roles remain separate from clinical authority.

## Live Supabase migrations

- `20261012105042` — `value_chain_50_permissions_v2`
- `20261012105117` — `value_chain_50_foundation_v2`
- `20261012110036` — `value_chain_50_hardening`

## Validation state

Supabase objects, RLS, role assignments, security-invoker views, and migration history were verified against the live HemoCura project. GitHub CI/PR validation is the final gate before merge to `main`.

## Remaining high-value roadmap

The next value-chain wave should focus on: demand-to-dispatch service level measurement, explicit customer IDs in sales rather than name matching, collections/aging, wastage and expiry economics, campaign cost/conversion, referral/medical-network demand generation, supplier-to-cost traceability, branch contribution margin, and automatic creation of integrated actions from quality/audit/compliance events.
