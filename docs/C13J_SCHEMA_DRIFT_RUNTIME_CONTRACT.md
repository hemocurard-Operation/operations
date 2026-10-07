# C13-J · Schema Drift & Runtime Contract Gate · v0.44.17

## Objetivo

Detectar antes del despliegue discrepancias entre el frontend real de GitHub y el schema/runtime real de Supabase.

C13-J es un **gate read-only**. No crea tablas, no cambia RLS, no modifica grants, no ejecuta migraciones y no altera datos clínicos.

## Arquitectura

- `tools/runtime_contract_gate.py`: extrae `.from(...)` y `.rpc(...)` del frontend y valida contratos.
- `tools/test_runtime_contract_gate.py`: suite unitaria del gate.
- `contracts/runtime-contract-v0.44.json`: contrato declarativo del frontend.
- `contracts/supabase-runtime-snapshot-v0.44.json`: snapshot mínimo verificado contra Supabase.
- `sql/C13J_00_RUNTIME_CONTRACT_PREFLIGHT.sql`: doctor read-only reproducible contra Supabase real.
- `.github/workflows/runtime-contract-gate.yml`: CI automático en pull requests.

## Descubrimiento automático del frontend

GitHub Actions escaneó **95 archivos JavaScript** y encontró:

- **150 relaciones** (`table/view/matview`) referenciadas mediante `.from(...)`;
- **16 RPC** referenciados mediante `.rpc(...)`.

No se mantiene una lista manual separada del código: si una futura modificación añade una nueva relación o RPC y no actualiza el contrato, el paso `Enforce frontend declaration contract` falla.

## Contratos críticos adicionales

Además de presencia de objetos, C13-J valida columnas que ya causaron fallas reales:

- `incidents.id`;
- `incidents.requires_quality_followup`;
- `dispatches.id`;
- `dispatches.dispatch_date`;
- `nonconformities.id/status`;
- `capa.id/status`;
- `release_signoffs.id`;
- `uat_test_cases.id`.

Y declara explícitamente como **forbidden**:

- `incidents.status`.

Esto evita reintroducir la suposición que provocó el error `column incidents.status does not exist`.

## Baseline de migración

El contrato exige:

- `version = 0.44.0`;
- `migration_code = 44_RELEASE_1_0_RC_v0_44`.

Durante el desarrollo inicial del gate se detectó que comprobar `0.44` era incorrecto. Supabase usa la versión canónica `0.44.0`; el contrato fue corregido antes de cerrar C13-J.

## Validación real contra Supabase

El preflight read-only fue ejecutado contra el proyecto `tiothqiljipdamgudvcb` y devolvió:

```text
C13-J ......................... PASS
expected_relations ............ 150
missing_relations ............. 0
expected_rpcs ................. 16
missing_rpcs .................. 0
missing_critical_columns ...... 0
forbidden_columns_present ..... 0
baseline_0_44_0 ............... true
```

No se ejecutó DDL ni DML de negocio.

## Validación GitHub Actions

Workflow: `HemoCura Runtime Contract Gate`

- Run ID: `37596141328`;
- estado: `completed`;
- conclusión: `success`.

Pasos validados:

1. unit tests;
2. extracción del frontend;
3. `Enforce frontend declaration contract`;
4. `Validate verified Supabase baseline snapshot`;
5. publicación del artefacto de descubrimiento.

El workflow `HemoCura Migration Security Linter` también terminó `success` en el mismo commit.

## Regla de despliegue desde ahora

Antes de desplegar un frontend que cambie acceso a Supabase:

`CODE → EXTRACT → CONTRACT → CI PASS → SUPABASE READ-ONLY PREFLIGHT → PASS → DEPLOY`.

El snapshot de GitHub es una línea base verificable, pero **no sustituye** la comprobación read-only contra Supabase inmediatamente antes del despliegue. El runtime puede cambiar fuera del repositorio.

## Estado

- DISEÑADO: **PASS**
- GENERADO: **PASS**
- UNIT TESTS: **PASS**
- CI GITHUB: **PASS**
- SUPABASE PREFLIGHT READ-ONLY: **PASS**
- INSTALADO EN SUPABASE: **NO APLICA**
- VALIDADO COMO GATE DE CONTRATO: **PASS**

C13-J no cambia el estado de C12/C13/C14: esos patches siguen **NO APLICADOS** hasta ejecutar sus propios gates y validators.
