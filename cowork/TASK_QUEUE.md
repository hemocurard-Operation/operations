# HemoCura Cowork v1 · Task Queue

La cola se deriva del Remediation Sequencer. No adelantar etapas dependientes.

## Cola activa

| Orden | Etapa | Estado | Gate requerido |
|---:|---|---|---|
| 1 | S01 · C11.2 Frontend Smoke + Merge | PASS | Browser smoke PASS + PR #1 merged + Pages deploy PASS |
| 2 | S02 · C12 Security Hardening | PASS | Preflight PASS + migration aplicada + validator PASS |
| 3 | S03 · C13-A RLS No-Policy | PASS | C12 PASS + C13-A validator PASS |
| 4 | S04 · C13-C1 Function Execute Hardening | READY TO EXECUTE | C13-A PASS |
| 5 | S05 · C13-C2A Controlled RPC Wrappers | BLOCKED | C13-C1 PASS |
| 6 | S06 · Frontend RPC Cutover / PR #2 | BLOCKED | C13-C2A PASS + smoke |
| 7 | S07 · C13-C2B Legacy RPC Cutover | BLOCKED | S06 PASS |
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

## Regla

Solo la primera etapa con dependencias satisfechas puede cambiar a `READY TO EXECUTE`.
