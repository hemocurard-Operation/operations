# C13-J · Orden de uso

C13-J es un gate read-only y debe ejecutarse antes de promover cambios de frontend que dependan de Supabase.

## Flujo

1. `HemoCura Migration Security Linter` = PASS.
2. `HemoCura Runtime Contract Gate` = PASS.
3. Ejecutar `sql/C13J_00_RUNTIME_CONTRACT_PREFLIGHT.sql` contra el Supabase objetivo.
4. Exigir `result = PASS`.
5. Solo entonces continuar con smoke/deploy de frontend o con el patch backend que corresponda.

## STOP

Detener el despliegue si existe cualquiera de estos resultados:

- relación faltante;
- RPC faltante;
- columna crítica faltante;
- columna prohibida presente;
- baseline de migración incorrecto;
- CI runtime-contract fallido.

No resolver un STOP debilitando RLS, usando `service_role` en frontend o reinstalando el esquema base.
