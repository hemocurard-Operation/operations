# HemoCura Cowork v1 · Task Queue

La cola se deriva del Remediation Sequencer. No adelantar etapas dependientes.

## Cola activa

| Orden | Etapa | Estado | Gate requerido |
|---:|---|---|---|
| 1 | S01 · C11.2 Frontend Smoke + Merge | PASS | Browser smoke PASS + PR #1 merged + Pages deploy PASS |
| 2 | S02 · C12 Security Hardening | PASS | Preflight PASS + migration aplicada + validator PASS |
| 3 | S03 · C13-A RLS No-Policy | PASS | C12 PASS + C13-A validator PASS |
| 4 | S04 · C13-C1 Function Execute Hardening | PASS | C13-A PASS + validator PASS |
| 5 | S05 · C13-C2A Controlled RPC Wrappers | PASS | C13-C1 PASS + validator PASS |
| 6 | S06 · Frontend RPC Cutover / PR #4 | PASS | C13-C2A PASS + cutover CI PASS + Runtime Contract PASS + PR browser smoke PASS + merge + main smoke + Pages deploy PASS |
| 7 | S07 · C13-C2B Legacy RPC Cutover | READY TO EXECUTE | S06 PASS |
| 8 | S08 · C14 Clinical Guardrails | BLOCKED | S07 PASS |
| 9 | S09 · C13-B1 View anon exposure | BLOCKED | C14 PASS |
| 10 | S10 · C13-B2 Critical security_invoker views | BLOCKED | C13-B1 PASS |
| 11 | S11 · C13-D Function search_path | BLOCKED | C13-B2 PASS |
| 12 | S12 · C13-F Broad Policy Hardening | BLOCKED | C13-D PASS |
| 13 | S13 · C13-G Grant ↔ Policy Reconciliation | BLOCKED | C13-F PASS |
| 14 | S14 · C13-E Anonymous Surface Hardening | BLOCKED | C13-G PASS |
| 15 | S15 · C13-H Default Privilege Governance | BLOCKED | C13-E PASS |
| 16 | UAT 1.0.0 | BLOCKED | Hardening PASS |
| 17 | 4 Sign-offs | BLOCKED | UAT PASS |
| 18 | Final Release Doctor | BLOCKED | Sign-offs completos |

## Evidencia de S01

- PR #1 merged: `1d442aca8b3eca7d6b6d8a5a75f1e9ccd2f03d92`
- Browser smoke run: `37607415945` → SUCCESS
- GitHub Pages run: `37607415753` → build + deploy SUCCESS

## Evidencia de S02

- C12 preflight: FAVORABLE
- Migration: `C12_SECURITY_HARDENING_v0_44_3`
- Validator: `RESULTADO_GENERAL = PASS`
- Roles `ENCARGADA_LABORATORIO` y `TI`: PASS
- UAT/Release direct write hardening: PASS

## Evidencia de S03

- C13-A preflight: 19 tablas RLS sin policy antes del patch
- Dependency contract: C12 registrado, 19/19 targets presentes, 0 permisos requeridos faltantes
- Migration: `C13A_RLS_NO_POLICY_v0_44_4`
- Ajuste `recipient_issues`: aplicado y alineado a `DISPATCH_VIEW`
- Validator: `RESULTADO_GENERAL = PASS`
- `public` con RLS habilitado y sin policy después del patch: `0`
- `temperature_readings`: SELECT + INSERT únicamente
- Sin DELETE browser directo en tablas clínicas/cadena de frío validadas

## Evidencia de S04

- C13-C1 preflight: `19` SECURITY DEFINER ejecutables por `anon` antes del patch
- C12 RPC controlados expuestos a `anon`: `0`
- 21/21 firmas requeridas presentes
- Migration: `C13C1_FUNCTION_EXECUTE_HARDENING_v0_44_5`
- Validator: `RESULTADO_GENERAL = PASS`
- SECURITY DEFINER ejecutables por `anon` después del patch: `0`
- Trigger/internal helpers sin EXECUTE directo para `authenticated`: PASS
- `reserve_blood_units_fefo(uuid)` queda fail-closed hasta C14
- Helpers RLS (`current_branch_id`, `can_access_branch`, `has_role`, `has_permission`) conservan EXECUTE autenticado

## Evidencia de S05

- C13-C2A preflight: C13-C1 registrado y C13-C2A aún no aplicado
- Permisos requeridos faltantes: `0`
- Roles requeridos faltantes: `0`
- Funciones legacy requeridas presentes: `true`
- Wrappers previos presentes: `false`
- Migration aplicada: `C13C2A_CONTROLLED_RPC_WRAPPERS_v0_44_6`
- Validator: `RESULTADO_GENERAL = PASS`
- Wrappers `hc_*` disponibles para authenticated
- Wrappers no accesibles por `anon`
- RPC legacy permanecen temporalmente activos para compatibilidad durante el cutover frontend

## Evidencia de S06

- Branch: `fix/s06-frontend-rpc-cutover`
- RPC frontend migrados: `adjust_sale_line` → `hc_adjust_sale_line`; `calculate_monthly_product_costs` → `hc_calculate_monthly_product_costs`; `production_healthcheck` → `hc_production_healthcheck`
- Gate `HemoCura Frontend RPC Cutover`: run `37697399298` → SUCCESS
- Runtime Contract: run `37697399210` → SUCCESS
- Browser Smoke PR: run `37697399387` → SUCCESS
- PR real: `#4` → MERGED
- Merge SHA: `72b0e10d6f72ff3d97eaa56764f3ef56292fc744`
- Browser Smoke en `main`: run `37697601966` → SUCCESS
- GitHub Pages: run `37697601665` → SUCCESS
- Backend post-deploy: wrappers `authenticated=true`, `anon=false`; legacy siguen `authenticated=true` hasta C13-C2B
- Cambio de Supabase en S06: ninguno

## Regla

Solo la primera etapa con dependencias satisfechas puede cambiar a `READY TO EXECUTE`.
