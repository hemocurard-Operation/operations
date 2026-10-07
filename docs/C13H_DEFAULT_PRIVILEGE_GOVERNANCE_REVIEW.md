# C13-H · Default Privilege Governance · v0.44.15

## Evidencia real verificada en Supabase

En `owner=postgres`, `schema=public`, los privilegios por defecto actuales conceden automáticamente:

### anon
- tablas: 8 privilegios (`DELETE`, `INSERT`, `MAINTAIN`, `REFERENCES`, `SELECT`, `TRIGGER`, `TRUNCATE`, `UPDATE`);
- secuencias: 3 privilegios (`SELECT`, `UPDATE`, `USAGE`);
- funciones: `EXECUTE`.

### authenticated
- tablas: los mismos 8 privilegios;
- secuencias: los mismos 3 privilegios;
- funciones: `EXECUTE`.

Esto significa que una migración futura puede crear un objeto nuevo en `public` y volver a abrir superficie aunque los objetos actuales ya hayan sido endurecidos.

## Relación con C13-E y C13-G

- C13-E ya retira privilegios de `anon` sobre objetos existentes y también revoca defaults de `anon` para tablas y secuencias.
- C13-G reconcilia privilegios de escritura actuales de `authenticated` contra RLS.
- C13-H completa la gobernanza futura: cierra defaults de `anon`, `authenticated` y `PUBLIC` para tablas/secuencias y `EXECUTE` de funciones creadas por `postgres` en `public`.

C13-H no reemplaza C13-E ni C13-G porque `ALTER DEFAULT PRIVILEGES` no es retroactivo.

## Scope deliberado

C13-H solo modifica DEFAULT PRIVILEGES de:

- owner: `postgres`;
- schema: `public`.

No modifica:

- `service_role`;
- schemas `auth`, `storage`, `graphql`, `graphql_public`, `realtime` o `extensions`;
- objetos existentes;
- RLS;
- datos;
- funciones existentes;
- flags clínicos.

## Regla nueva para futuras migraciones

Toda nueva tabla, secuencia o función consumida por el frontend debe declarar sus `GRANT` explícitamente en la misma migración que crea el objeto. No se debe depender de privilegios heredados por defecto.

Ejemplos:

```sql
grant select on public.mi_tabla to authenticated;
```

```sql
revoke all on function public.mi_rpc(...) from public,anon;
grant execute on function public.mi_rpc(...) to authenticated;
```

La política RLS o el control interno del RPC sigue siendo obligatorio; el GRANT por sí solo no sustituye autorización.

## Archivos

- `sql/C13H_00_PREFLIGHT_DEFAULT_PRIVILEGES.sql`
- `sql/C13H_01_DEFAULT_PRIVILEGE_GOVERNANCE_CANDIDATE.sql`
- `sql/C13H_90_VALIDATE_DEFAULT_PRIVILEGES.sql`

## Gate

Estado: **GENERADO / NO APLICADO**.

Orden requerido mínimo:

`C13-E PASS → C13-G PASS → C13-H PREFLIGHT → C13-H PATCH → C13-H VALIDATE`.

El validator debe devolver:

- `C13H_REGISTERED = PASS`;
- `DEFAULT_PRIVILEGES_GOVERNED = PASS`;
- 0 filas en el listado de defaults riesgosos.
