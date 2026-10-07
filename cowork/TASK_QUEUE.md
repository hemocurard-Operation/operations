# HemoCura Cowork v1 · Task Queue

La cola se deriva del Remediation Sequencer. No adelantar etapas dependientes.

## Cola activa

| Orden | Etapa | Estado | Gate requerido |
|---:|---|---|---|
| 1 | S01 · C11.2 Frontend Smoke + Merge | READY TO EXECUTE | Smoke PASS + merge |
| 2 | S02 · C12 Security Hardening | BLOCKED BY S01 | Preflight + patch + validate |
| 3 | S03 · C13-A RLS No-Policy | BLOCKED | C12 PASS |
| 4 | S04 · C13-C1 Function Execute Hardening | BLOCKED | C13-A PASS |
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

## Regla

Solo la primera etapa con dependencias satisfechas puede cambiar a `READY TO EXECUTE`.
