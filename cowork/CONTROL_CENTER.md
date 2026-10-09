# HemoCura Cowork v1 · Control Center

Línea base activa: frontend runtime `0.44.2`, database baseline `0.44.6`.

| Dominio | Estado | Evidencia / gate | Próxima acción |
|---|---|---|---|
| GitHub CI | PASS | Security Linter + Runtime Contract + RPC Cutover Gate + Browser Smoke | Mantener verde |
| Frontend | PASS | PR #4 merged + browser smoke PR/main SUCCESS + Pages deploy SUCCESS | Mantener wrappers `hc_*` |
| Database | PASS BASELINE | v0.44.6 | Ejecutar C13-C2B |
| Schema Drift | PASS | Runtime Contract | Vigilar cambios |
| RLS No-Policy | PASS | C13-A validator PASS; 0 tablas public con RLS sin policy | Mantener cerrado |
| RLS Global | ATTENTION | C13-A cerrado; broad policies/grant reconciliation pendientes | C13-F/G más adelante |
| RPC Security | ATTENTION | Frontend activo ya usa wrappers `hc_*`; legacy backend sigue temporalmente expuesto a authenticated | C13-C2B, luego C13-D |
| Anonymous SECURITY DEFINER Execute | PASS | 19 → 0 funciones ejecutables por anon | Mantener en 0 |
| Anonymous Surface | ATTENTION | RPC secdef anon cerrado; views/tablas globales pendientes | C13-B1/B2/E/H |
| Role Model | PASS BASELINE | ENCARGADA_LABORATORIO + TI instalados | Mantener segregación |
| Clinical Guardrails | SAFE_LIMITED | FEFO directo cerrado hasta C14; no automatismos clínicos | C14 después de C13-C2B |
| UAT | STOP | Sin runs 1.0.0 | Después de hardening |
| Sign-offs | STOP | Sin firmas 1.0.0 | Después de UAT |
| Final Release Gate | NOT_READY | C13-K | Recalcular al cerrar la cola |

## S01 cerrado

- PR #1: MERGED
- Merge SHA: `1d442aca8b3eca7d6b6d8a5a75f1e9ccd2f03d92`
- C11.2 browser smoke: SUCCESS (`37607415945`)
- GitHub Pages build/deploy: SUCCESS (`37607415753`)

## S02 cerrado

- C12 preflight: FAVORABLE
- Migration aplicada: `C12_SECURITY_HARDENING_v0_44_3`
- Validator: `RESULTADO_GENERAL = PASS`
- Roles `ENCARGADA_LABORATORIO` y `TI`: PASS
- Release/UAT direct browser writes: cerrados según validator

## S03 cerrado

- C13-A preflight: `19` tablas RLS sin policy
- Contrato de dependencia: C12 presente, 19/19 targets presentes y permisos requeridos completos
- Migration aplicada: `C13A_RLS_NO_POLICY_v0_44_4`
- Recipient policy fix aplicado
- Validator: `RESULTADO_GENERAL = PASS`
- `public_rls_enabled_without_policy = 0`
- `anon` sin acceso directo a los 19 targets
- `temperature_readings` queda append-only desde browser
- Sin DELETE directo en trazabilidad clínica/cadena de frío verificada

## S04 cerrado

- Antes: `19` funciones SECURITY DEFINER ejecutables por `anon`
- C12 RPC controlados ya estaban cerrados a `anon`
- Migration aplicada: `C13C1_FUNCTION_EXECUTE_HARDENING_v0_44_5`
- Validator: `RESULTADO_GENERAL = PASS`
- Después: `0` SECURITY DEFINER ejecutables por `anon`
- Trigger/internal helpers cerrados a RPC directo autenticado
- Helpers RLS conservan compatibilidad autenticada
- `reserve_blood_units_fefo(uuid)` queda fail-closed hasta C14

## S05 cerrado

- Preflight: C13-C1 presente, C13-C2A ausente, permisos/roles requeridos completos
- Funciones legacy requeridas presentes
- Wrappers previos inexistentes antes del patch
- Migration aplicada: `C13C2A_CONTROLLED_RPC_WRAPPERS_v0_44_6`
- Validator: `RESULTADO_GENERAL = PASS`
- Wrappers controlados disponibles a `authenticated`
- Wrappers no disponibles a `anon`
- Legacy permanece temporalmente activo para evitar downtime durante S06

## S06 cerrado

- Se migraron los tres RPC legacy realmente usados por el frontend activo a wrappers controlados `hc_*`.
- PR real: `#4`, no #2; la numeración cambió porque ya existían otros PR en GitHub.
- RPC Cutover Gate: SUCCESS (`37697399298`)
- Runtime Contract: SUCCESS (`37697399210`)
- Browser Smoke PR: SUCCESS (`37697399387`)
- PR #4: MERGED
- Merge SHA: `72b0e10d6f72ff3d97eaa56764f3ef56292fc744`
- Browser Smoke `main`: SUCCESS (`37697601966`)
- GitHub Pages build/deploy: SUCCESS (`37697601665`)
- Verificación read-only post-deploy Supabase: wrappers permiten `authenticated`, bloquean `anon`; legacy todavía permite `authenticated` solo durante transición.
- S06 no aplicó ninguna migración nueva a Supabase.

## Próxima acción segura

`S07_C13C2B_LEGACY_RPC_CUTOVER`

## Semáforo

- `PASS`: evidencia suficiente para continuar.
- `ATTENTION`: no bloquea, pero requiere seguimiento.
- `STOP`: no avanzar.
- `SAFE_LIMITED`: permitido bajo guardrails explícitos.
- `NOT_READY`: release no autorizado.

## Regla de actualización

Cada iteración debe actualizar este tablero solamente después de obtener evidencia del sistema correspondiente. Un archivo generado no cambia el estado runtime.
