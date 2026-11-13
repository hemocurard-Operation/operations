# Activar `apply-pending-migrations.yml` — guía copy/paste

El workflow `.github/workflows/apply-pending-migrations.yml` aplica las 14 migraciones pendientes de v0.67.0 contra Supabase producción. Requiere **un rol con permisos de escritura** (el rol `claude_audit_reader` del Sprint 0 no sirve — es read-only por diseño).

---

## Paso 1 — Crear el rol de migraciones en Supabase

En el **SQL Editor** de Supabase (proyecto `tiothqiljipdamgudvcb`), copiar y pegar:

```sql
-- Rol dedicado a aplicar migraciones (no es el service_role; es menos amplio)
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'claude_migrations') then
    create role claude_migrations login password 'HC-mig-REEMPLAZAR-CON-PASS-ALEATORIA'
      noinherit nobypassrls;
  else
    alter role claude_migrations with login password 'HC-mig-REEMPLAZAR-CON-PASS-ALEATORIA' noinherit nobypassrls;
  end if;
end $$;

-- Permisos amplios en public (crear tablas, funciones, triggers, etc.)
grant usage, create on schema public to claude_migrations;
grant all privileges on all tables    in schema public to claude_migrations;
grant all privileges on all sequences in schema public to claude_migrations;
grant all privileges on all functions in schema public to claude_migrations;
alter default privileges in schema public grant all on tables    to claude_migrations;
alter default privileges in schema public grant all on sequences to claude_migrations;
alter default privileges in schema public grant all on functions to claude_migrations;

-- Puede leer configuración auth pero no modificarla
grant usage on schema auth to claude_migrations;
grant select on all tables in schema auth to claude_migrations;
```

**Importante:** reemplace `HC-mig-REEMPLAZAR-CON-PASS-ALEATORIA` por una contraseña aleatoria fuerte (mínimo 24 caracteres). Guárdela temporalmente — la va a necesitar en el paso siguiente.

---

## Paso 2 — Configurar el secret en GitHub

En **GitHub → Settings → Secrets and variables → Actions** del repo `hemocurard-Operation/operations`, crear un nuevo secret:

- **Name:** `SUPABASE_MIGRATIONS_DSN`
- **Secret:**

```
postgresql://claude_migrations:HC-mig-REEMPLAZAR-CON-PASS-ALEATORIA@db.tiothqiljipdamgudvcb.supabase.co:5432/postgres?sslmode=require
```

(El workflow detecta que es un DSN directo IPv6 y auto-descubre el pooler IPv4 regional.)

Después de guardar, puede borrar la contraseña de cualquier sitio donde la haya pegado. El secret queda cifrado.

---

## Paso 3 — Lanzar el workflow

Opción A — desde el teléfono / web:
`Actions → Apply pending Supabase migrations (v0.67.0) → Run workflow`

Marcar `dry_run: true` la primera vez para ver qué va a hacer sin ejecutar. Después `Run workflow` con `dry_run: false`.

Opción B — CLI:

```bash
gh workflow run apply-pending-migrations.yml \
  --repo hemocurard-Operation/operations \
  -f dry_run=false
```

---

## Qué hace el workflow

1. Auto-descubre el pooler regional IPv4 (lo mismo que `sprint-0-doctors.yml`).
2. Crea la tabla de bookkeeping `public.schema_migrations` si no existe.
3. Lee la lista `VERSION.json → pending_supabase_migrations`.
4. Para cada versión:
   - Si ya está en `schema_migrations`: **skip** (idempotente).
   - Si falta el archivo: warning, continúa con las demás.
   - Si existe y es nueva: la ejecuta en **una transacción** (`--single-transaction`), registra el SHA256 en `schema_migrations`, log completo.
5. Actualiza `VERSION.json` removiendo las aplicadas.
6. Commitea logs a `docs/sprint-0/migration-logs/apply_<timestamp>.log` y la actualización de `VERSION.json`.
7. Sube artifacts (90 días).

Si una migración falla:
- El workflow **sigue con las demás** (las dependientes fallarán limpio).
- El log quedará commiteado para que las diagnostiquemos sin perder tiempo.
- La versión fallida queda en `pending_supabase_migrations` para reintento.

---

## Rollback

Las 14 migraciones son aditivas (nuevas tablas, nuevas policies, nuevos RPCs). El rollback práctico es `drop table if exists ... cascade;` por módulo; no hay cambios destructivos a objetos existentes.

Si una migración deja la base en estado inconsistente, correr:

```sql
-- Marcar como rollback explícito (no afecta la tabla de bookkeeping)
delete from public.schema_migrations where version = '<version_que_falló>';
```

Luego aplicar el drop del módulo afectado y relanzar el workflow.

---

## Después de aplicar

Correr `sprint-0-doctors.yml` otra vez para confirmar:
- `critical_release_objects` queda en ✅ para `release_signoffs`, pero `release_operational_signoffs` y `hc_v100_signoff` siguen faltando (brecha v1.0, no v0.67).
- Ningún `broad_policy` nuevo aparece.
- `missing_roles` sigue en `[]`.

El workflow `sprint-0-doctors.yml` corre automáticamente los lunes 06:00 UTC, así que la próxima verificación cae sola.
