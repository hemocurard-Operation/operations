# C13-G · Grant ↔ RLS Policy Reconciliation · v0.44.14

## Evidencia real verificada en Supabase

Preflight sobre producción antes de aplicar C12/C13-A/C13-F:

- 143 privilegios de escritura redundantes para `authenticated`;
- distribuidos en 52 tablas RLS;
- 42 INSERT;
- 49 UPDATE;
- 52 DELETE.

Se considera redundante un privilegio cuando `authenticated` tiene el GRANT directo pero no existe ninguna policy RLS `ALL` ni una policy específica para esa operación.

Ejemplos actuales incluyen `alerts`, `audit_log`, `blood_units`, `branches`, `incidents`, `inventory_movements`, `profiles`, `roles`, `unit_release_reviews` y varias tablas de diagnóstico/gobierno.

## Por qué esta corrección es compatible

Una operación sin policy RLS equivalente ya falla para `authenticated`, aunque el GRANT exista. C13-G elimina ese GRANT redundante; no elimina una capacidad que hoy funcione mediante acceso directo del navegador.

Sin embargo, C13-A crea policies nuevas para varias tablas que hoy no tienen ninguna. Por esa razón C13-G NO debe ejecutarse antes de C13-A. También debe esperar C12 y C13-F, porque esas iteraciones cambian el conjunto de policies de UAT, release, auditorías y competencias.

## Diseño

C13-G se ejecuta de forma dinámica contra el estado real al momento de la instalación:

1. exige que C12, C13-A y C13-F estén registradas;
2. recorre tablas `public` con RLS activo;
3. revisa INSERT, UPDATE y DELETE;
4. si `authenticated` tiene el GRANT pero no existe policy `ALL` ni policy de esa operación, revoca solo ese privilegio;
5. no modifica SELECT;
6. no modifica policies;
7. no toca `service_role`, funciones/RPC, datos ni clinical flags.

## Archivos

- `sql/C13G_00_PREFLIGHT_GRANT_POLICY_RECONCILIATION.sql`
- `sql/C13G_01_GRANT_POLICY_RECONCILIATION_CANDIDATE.sql`
- `sql/C13G_90_VALIDATE_GRANT_POLICY_RECONCILIATION.sql`

## Gate

Estado: **GENERADO / NO APLICADO**.

Orden requerido:

`C12 PASS → C13-A PASS → C13-F PASS → C13-G PREFLIGHT → C13-G PATCH → C13-G VALIDATE`.

El validator debe dejar `NO_REDUNDANT_AUTH_WRITE_GRANTS = PASS` y devolver 0 filas en el listado final de privilegios redundantes.
