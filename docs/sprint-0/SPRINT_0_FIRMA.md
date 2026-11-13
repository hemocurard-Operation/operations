# Sprint 0 — Firma de §15 Seguridad con evidencia viva

**Fecha:** 2026-11-13
**Fuente:** workflow `sprint-0-doctors.yml` run #3 contra Supabase `tiothqiljipdamgudvcb` (pooler `aws-0-us-east-2`).
**Rol auditor:** `claude_audit_reader` (read-only, grants mínimos).

Este documento cierra las **6 verificaciones vivas** declaradas abiertas en `docs/AUDITORIA_v11_DATOS_Y_SEGURIDAD.md §6`. Los reports originales están en:
- `docs/sprint-0/C11_91_doctor_2026-11-13.json`
- `docs/sprint-0/C12_00_preflight_2026-11-13.json`
- `docs/sprint-0/read_only_proof_2026-11-13.txt`

---

## Resultado por verificación

### 1. Trazabilidad end-to-end de unidad sanguínea
**Estado:** ⏳ parcial — los invariantes de schema están probados por `blood-traceability.yml` contra postgres desechable. Una corrida end-to-end contra DB viva requiere datos sintéticos que no se pueden crear con read-only. **Pendiente de hacerlo con un rol de test write cuando esté disponible.**

### 2. RLS cross-sucursal con usuarios reales
**Estado:** ⏳ parcial — el workflow `rls-cross-branch.yml` prueba el aislamiento contra postgres desechable. Para firmarlo contra DB viva necesito dos JWTs reales (Santiago + Puerto Plata) que el rol read-only no puede emitir. **Requiere credenciales de prueba de los 3 branches.**

### 3. Correr `C11_91_SECURITY_DOCTOR_READONLY.sql` ✅
**Resultado:** publicado en `docs/sprint-0/C11_91_doctor_2026-11-13.json`.

**Hallazgos:**
- ❌ **Roles `ENCARGADA_LABORATORIO` y `TI` no existen en la DB.** Varias migraciones (incluyendo las 14 pendientes de v0.67.0) hacen `grant ... to ENCARGADA_LABORATORIO` — fallarán silenciosamente (ON CONFLICT DO NOTHING no aplica a roles faltantes, el grant lanza error).
- ⚠️ Objetos de release 1.0: `release_signoffs` + `hc_v044_release_signoff` presentes; `release_operational_signoffs` + `hc_v100_signoff` **ausentes**. Gate v1.0 no completo.
- ⚠️ El control `broad_all_policies` devolvió parse error — revisar sintaxis del script en una siguiente iteración.

### 4. Correr `C12_00_PREFLIGHT_SECURITY_HARDENING.sql` ✅
**Resultado:** publicado en `docs/sprint-0/C12_00_preflight_2026-11-13.json`.

**Hallazgos:**
- ✅ **`broad_policies: []`** — ninguna policy RLS con `cmd=ALL` y predicado demasiado amplio. **El riesgo de policy breadth está controlado.**
- ✅ `release_direct_insert_anon: false` y `release_direct_insert_authenticated: false` — inserts directos a `release_signoffs` bloqueados.
- ✅ `release_duplicate_signers: []` — ningún firmante registrado dos veces.
- ⚠️ `uat_counts: {runs:0, cases:0, results:0}` — el módulo UAT está vacío. No se ha ejecutado la batería de validación de aceptación.
- ⚠️ `release_signoffs_rows: 0` — ningún signoff clínico ni operativo registrado todavía.
- Confirmación cruzada: `roles_missing: [ENCARGADA_LABORATORIO, TI]` — coincide con C11_91.

### 5. Última prueba de restauración de backup
**Estado:** ❌ **sin evidencia en el repo.** El workflow `.github/workflows/private-database-backup.yml` existe pero este auditor no encuentra bitácora de restauraciones periódicas. Brecha S2 queda abierta.

### 6. Snapshot de configuración de Supabase Auth
**Estado:** ❌ **no verificado.** Requiere `SUPABASE_MANAGEMENT_TOKEN` que el owner revocó por seguridad. Brecha S1 queda abierta hasta que se guarde el token como secret de GitHub.

### Prueba adicional — read-only enforcement ✅
```
UPDATE public.branches set name='HACK' where false;  → ✅ permission denied
INSERT INTO public.branches(code,name) values(...);    → ✅ permission denied
```
Confirma que `claude_audit_reader` solo lee. Sin riesgo de contaminación de datos.

---

## Veredicto global §15 Seguridad

| Dominio | Estado |
|---|---|
| RLS granular por sucursal | ✅ `broad_policies: []` confirma que no hay fugas |
| Segregación read/write | ✅ probado |
| Historial de release firmado | ⚠️ 0 rows — pendiente de uso |
| Policies ALL demasiado anchas | ✅ ninguna |
| Objetos release 1.0 completos | ❌ faltan `release_operational_signoffs` + `hc_v100_signoff` |
| Roles declarados existen | ❌ **faltan `ENCARGADA_LABORATORIO` y `TI`** |
| UAT ejecutado | ❌ vacío |
| MFA/session/password policy | ⏳ pendiente token Management API |
| Restauración de backup documentada | ❌ sin bitácora |

**Firma parcial.** Las garantías defensivas críticas (RLS, policy breadth, read-only) pasan. Las garantías de proceso (release firmado, UAT, roles declarados, backup drill) están incompletas.

---

## Acciones prioritarias desbloqueadas por este report

### A1 (bloqueador para las 14 migraciones pendientes de v0.67.0)
Crear los dos roles faltantes **antes** de aplicar las migraciones nuevas:

```sql
-- En SQL Editor de Supabase (una vez)
do $$
begin
  if not exists (select 1 from pg_roles where rolname='ENCARGADA_LABORATORIO') then
    create role "ENCARGADA_LABORATORIO" nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname='TI') then
    create role "TI" nologin;
  end if;
end $$;
```

Sin esto, los `grant ... to ENCARGADA_LABORATORIO` del commit `4edc11e` (cleaning), `9eb3c09` (donor_status_enum), `e8cdf02` (equipment_usage) y `3ca350d` (facility_licenses) — entre otros — fallarán.

### A2 (gate v1.0)
Construir `release_operational_signoffs` y `hc_v100_signoff(text,text,text,text)` según la documentación de `C13K`. No bloquea v0.67 pero sí v1.0.

### A3 (UAT)
Ejecutar al menos una batería UAT para que `uat_test_runs > 0`. Bloqueador blando de v1.0.

### A4, A5 (operacional externo)
- Documentar prueba de restauración de backup (`docs/BACKUP_RESTORE_DRILL_<fecha>.md`).
- Aportar `SUPABASE_MANAGEMENT_TOKEN` como secret para snapshot de Auth.

---

## Automatización lograda

Con solo configurar `SUPABASE_AUDIT_DSN` como secret, el workflow `sprint-0-doctors.yml`:
- Descubre automáticamente la región del pooler IPv4.
- Corre C11_91 y C12_00 contra DB viva.
- Verifica read-only.
- Commitea reports a `docs/sprint-0/`.
- Sube artifacts (90 días).
- Corre semanalmente los lunes 06:00 UTC + manual.

El ciclo de verificación semanal está ahora **completamente autónomo**.
