# C13-K · Composite Release Readiness Doctor · v0.44.18

## Objetivo

Unificar en un único gate los resultados técnicos y operativos necesarios antes de declarar HemoCura listo para release.

C13-K no reemplaza los gates previos. Los consume y consolida:

- C13-I · Migration Security Linter
- C13-J · Runtime Contract Gate
- C12/C13-A/C13-F/C13-G/C13-H · hardening de seguridad
- C14 · Clinical Guardrails
- UAT v0.43
- Sign-offs v0.44

## Estado real capturado

El snapshot read-only ejecutado contra Supabase el 2026-10-07T10:01:16.989858Z devuelve:

- database: PASS
- schema_drift: PASS
- rls: STOP
- rpc_security: STOP
- anon_surface: STOP
- role_model: STOP
- clinical_guardrails: SAFE_LIMITED
- uat: STOP
- signoffs: STOP
- FINAL RELEASE GATE: NOT_READY

## Bloqueos actuales

1. 19 tablas con RLS habilitado pero sin policy.
2. 6 policies `FOR ALL` demasiado amplias para authenticated.
3. 568 grants DML para `anon`, distribuidos en 142 tablas.
4. 17 funciones SECURITY DEFINER ejecutables por `anon`.
5. 16 funciones callable sin `search_path` fijo.
6. Faltan los roles `ENCARGADA_LABORATORIO` y `TI`.
7. No existe ninguna ejecución UAT para release 1.0.0.
8. No existe ningún sign-off aprobado para release 1.0.0.
9. El sistema está en `LIVE_LIMITED`: las automatizaciones clínicas críticas permanecen deshabilitadas, lo cual es seguro, pero C14 aún no está promovido.

## Archivos

- `contracts/release-readiness-snapshot-v0.44.18.json`
- `tools/release_readiness_doctor.py`
- `tools/test_release_readiness_doctor.py`
- `sql/C13K_00_COMPOSITE_RELEASE_DOCTOR.sql`
- `.github/workflows/release-readiness-doctor.yml`

## Semántica del gate

`READY` solo es posible cuando todos los componentes son `PASS`.

`SAFE_LIMITED` en Clinical Guardrails significa que el sistema no debe promocionarse a release completo, aunque las funciones clínicas críticas permanezcan deshabilitadas.

El Doctor nunca interpreta ausencia de UAT como PASS. También exige 4 sign-offs aprobados y segregados para Operaciones, Calidad, TI y Gerencia.

## Regla de implementación

C13-K es read-only. No modifica Supabase. Se debe volver a ejecutar después de cada bloque de hardening y nuevamente después de UAT/sign-offs.
