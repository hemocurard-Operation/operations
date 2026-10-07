# C13-I · Migration Security Linter · v0.44.16

## Objetivo

Evitar que futuras migraciones vuelvan a introducir las mismas clases de exposición detectadas durante C12/C13/C14.

C13-I no modifica Supabase. Es un gate de repositorio/CI que revisa migraciones nuevas antes del merge.

## Evidencia real

El preflight de Supabase mostró que, para `owner=postgres` y `schema=public`, existen defaults amplios para `anon` y `authenticated` sobre tablas, secuencias y funciones. C13-H corrige el comportamiento futuro en base de datos; C13-I evita además que una migración de GitHub reintroduzca privilegios o patrones inseguros de forma explícita.

Antes de C13-I no existía `.github/workflows/` en el branch de trabajo, por lo que no había un gate automático de seguridad para SQL.

## Arquitectura

- `tools/migration_security_linter.py`: linter sin dependencias externas.
- `tools/test_migration_security_linter.py`: 12 pruebas unitarias.
- `.github/workflows/migration-security-linter.yml`: gate automático en pull requests.
- `sql/migrations/README.md`: estándar obligatorio para migraciones nuevas.

Para evitar que deuda legacy bloquee la adopción, el gate automático gobierna nuevas migraciones bajo `sql/migrations/`. Los scripts históricos en `sql/` siguen sujetos al programa de saneamiento C12/C13/C14 ya preparado.

## Reglas

| Regla | Bloqueo |
|---|---|
| HC001 | CREATE TABLE sin ENABLE RLS en la misma migración |
| HC002 | GRANT ALL a PUBLIC/anon/authenticated |
| HC003 | SECURITY DEFINER sin SET search_path |
| HC004 | GRANT EXECUTE a PUBLIC o anon |
| HC005 | DEFAULT PRIVILEGES que vuelven a abrir PUBLIC/anon/authenticated |
| HC006 | DISABLE ROW LEVEL SECURITY |
| HC007 | Policy FOR ALL basada solo en authenticated |
| HC008 | View nueva sin security_invoker=true |
| HC009 | TRUNCATE sin waiver documentado |
| HC010 | Activación ordinaria de flags clínicos protegidos |

## Guardrails clínicos

HC010 vigila:

- `clinical_fefo`;
- `cold_chain_auto_block`;
- `donor_to_recipient_traceability`.

El linter no autoriza activaciones. Solo obliga a que una activación potencial se trate como cambio extraordinario, con waiver visible y revisión humana.

## Waivers

Formato:

```sql
-- hc-lint: allow=HC009 reason="Controlled cleanup of ephemeral staging rows"
```

Los waivers desconocidos o con razones menores de 12 caracteres fallan el gate.

## Validación estática realizada antes de subir

El linter y su suite fueron ejecutados localmente contra 12 casos de prueba. Resultado: `12/12 OK`.

La suite cubre, entre otros, missing RLS, GRANT ALL, SECURITY DEFINER sin search_path, EXECUTE anónimo, broad policy, view sin security_invoker y waiver inválido.

## Estado

- DISEÑADO: PASS
- GENERADO: PASS
- TEST LOCAL: PASS (12/12)
- CI EN GITHUB: PENDIENTE DE EJECUCIÓN
- INSTALADO EN SUPABASE: NO APLICA
- VALIDADO COMO GATE DE MERGE: NO, hasta que GitHub Actions ejecute PASS

## Siguiente gate

1. GitHub Actions ejecuta `Migration Security Linter`.
2. Unit tests = PASS.
3. Migraciones gobernadas = PASS.
4. Después del merge de C11/C13-I, toda migración nueva debe entrar por `sql/migrations/`.
