# Migraciones gobernadas por HC-LINT

A partir de C13-I, toda migración nueva que vaya a producción debe crearse en este directorio para entrar al gate automático de seguridad.

## Reglas mínimas

- Toda tabla nueva debe habilitar RLS en la misma migración.
- No usar `GRANT ALL` / `GRANT ALL PRIVILEGES` para `PUBLIC`, `anon` o `authenticated`.
- Toda función `SECURITY DEFINER` debe declarar `SET search_path`.
- No conceder `EXECUTE` a `PUBLIC` o `anon`.
- No conceder privilegios por defecto a `PUBLIC`, `anon` o `authenticated`.
- No usar `DISABLE ROW LEVEL SECURITY`.
- No crear policies `FOR ALL` basadas solo en `auth.role()='authenticated'`.
- Toda view nueva debe usar `security_invoker=true`.
- `TRUNCATE` requiere waiver explícito y justificado.
- La activación de `clinical_fefo`, `cold_chain_auto_block` o `donor_to_recipient_traceability` requiere migración clínica dedicada y waiver explícito.

## Waiver excepcional

Formato:

```sql
-- hc-lint: allow=HC009 reason="Controlled cleanup of ephemeral staging rows"
```

El motivo debe tener al menos 12 caracteres. Un waiver no sustituye revisión humana.

## Ejemplo mínimo

```sql
begin;

create table public.mi_tabla (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
);

alter table public.mi_tabla enable row level security;

create policy mi_tabla_select
on public.mi_tabla
for select
to authenticated
using (public.has_permission('MI_MODULO_VIEW'));

grant select on public.mi_tabla to authenticated;

commit;
```

Los scripts históricos ubicados directamente en `sql/` permanecen como baseline legado. El linter de C13-I se aplica automáticamente a archivos nuevos bajo `sql/migrations/`.
