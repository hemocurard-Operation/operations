# C13-L · Dependency-Aware Remediation Sequencer · v0.44.19

## Objetivo

Evitar aplicar hardenings fuera de orden. C13-L convierte el plan de corrección en un grafo de dependencias verificable y devuelve exactamente una siguiente acción segura.

## Estado real capturado

Supabase read-only confirma:

- hardenings objetivo aplicados: 0
- hardenings objetivo pendientes: 13
- UAT 1.0.0 runs: 0
- release sign-offs 1.0.0: 0
- PR #1: abierto
- PR #2: abierto y draft

Por tanto, la primera acción segura es:

`S01_C11_2_FRONTEND_SMOKE_MERGE`

No se debe ejecutar C12 todavía si S01 no está cerrado con evidencia de smoke y merge.

## Secuencia controlada

1. C11.2 frontend smoke + merge PR #1
2. C12 security hardening
3. C13-A RLS policies
4. C13-C1 function execute hardening
5. C13-C2A controlled RPC wrappers
6. PR #2 frontend cutover + smoke Sales/Costs
7. C13-C2B legacy RPC cutover
8. C14 clinical guardrails
9. C13-B1 anon view exposure
10. C13-B2 security_invoker critical views
11. C13-D function search_path
12. C13-F broad policy hardening
13. C13-G grant/policy reconciliation
14. C13-E anonymous surface hardening
15. C13-H default privilege governance
16. rerun C13-K post-hardening doctor
17. UAT 1.0.0
18. four segregated release sign-offs
19. rerun C13-K final doctor → READY

## Controles automáticos

`tools/remediation_sequencer.py` valida:

- IDs únicos;
- dependencias existentes;
- ausencia de ciclos;
- presencia física de candidate/validator/evidence files;
- no ejecución de una etapa antes de sus dependencias;
- cálculo determinístico de una única siguiente acción.

El workflow `.github/workflows/remediation-sequencer.yml` ejecuta las pruebas y publica el plan calculado como artefacto.

## Regla operativa

C13-L es diagnóstico y gobierno de secuencia. No aplica migraciones ni modifica Supabase.
