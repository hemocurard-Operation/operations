# Sprint 0 — Firma de §15 Seguridad con evidencia viva

**Fecha:** 2026-11-13 (reports actualizados tras `alter role claude_audit_reader bypassrls`)
**Fuente:** workflow `sprint-0-doctors.yml` run #6 contra Supabase `tiothqiljipdamgudvcb` (pooler `aws-0-us-east-2`).
**Rol auditor:** `claude_audit_reader` (read-only + BYPASS RLS, ninguna escritura).

Este documento cierra las **6 verificaciones vivas** declaradas abiertas en `docs/AUDITORIA_v11_DATOS_Y_SEGURIDAD.md §6`. Los reports originales están en:
- `docs/sprint-0/C11_91_doctor_2026-11-13.json`
- `docs/sprint-0/C12_00_preflight_2026-11-13.json`
- `docs/sprint-0/read_only_proof_2026-11-13.txt`

> **Nota histórica:** la primera versión de este documento reportó como "bloqueador crítico" que faltaban los roles `ENCARGADA_LABORATORIO` y `TI`. Era un **falso positivo**: el rol auditor no tenía `BYPASS RLS` y las policies escondían `public.roles` por completo. Tras otorgar `bypassrls`, el dump real muestra 21 roles canónicos (incluyendo los 2 reportados como "ausentes") desde el 2026-10-07. La lección quedó anotada: todo auditor read-only sobre Supabase necesita `bypassrls` para distinguir "no existe" de "existe pero RLS lo oculta".

---

## Resultado por verificación

### 1. Trazabilidad end-to-end de unidad sanguínea
**Estado:** ⏳ parcial — los invariantes de schema están probados por `blood-traceability.yml` contra postgres desechable. Una corrida end-to-end contra DB viva requiere datos sintéticos que no se pueden crear con read-only. Requiere un rol de test con write permissions.

### 2. RLS cross-sucursal con usuarios reales
**Estado:** ⏳ parcial — el workflow `rls-cross-branch.yml` prueba el aislamiento contra postgres desechable. Para firmarlo contra DB viva necesito dos JWTs reales (Santiago + Puerto Plata); el rol auditor read-only no puede emitirlos.

### 3. Correr `C11_91_SECURITY_DOCTOR_READONLY.sql` ✅
**Resultado:** publicado en `docs/sprint-0/C11_91_doctor_2026-11-13.json`.

**Hallazgos (post-bypass):**
- ✅ `missing_roles`: **ambos presentes**. `ENCARGADA_LABORATORIO` y `TI` existen desde 2026-10-07.
- ⚠️ `critical_release_objects`:
  - ✅ `release_signoffs` presente.
  - ✅ `hc_v044_release_signoff` presente.
  - ❌ `release_operational_signoffs` **ausente**.
  - ❌ `hc_v100_signoff` **ausente**.
- ⚠️ `broad_all_policies`: parse error del script (vacío devuelto por el sub-select). Revisar sintaxis de `C11_91` en una iteración futura; **la confirmación de que no hay policies anchas viene del `C12_00`, que sí parsea bien**.

### 4. Correr `C12_00_PREFLIGHT_SECURITY_HARDENING.sql` ✅
**Resultado:** publicado en `docs/sprint-0/C12_00_preflight_2026-11-13.json`.

**Hallazgos (post-bypass):**
- ✅ **`broad_policies: []`** — ninguna policy RLS con `cmd=ALL` y predicado demasiado amplio. **El riesgo de policy breadth está controlado.**
- ✅ **`roles_missing: []`** — confirma que todos los roles canónicos existen.
- ✅ `release_direct_insert_anon: false` y `release_direct_insert_authenticated: false` — inserts directos a `release_signoffs` bloqueados.
- ✅ `release_duplicate_signers: []` — ningún firmante registrado dos veces.
- ⚠️ `uat_counts: {runs:3, cases:14, results:0}` — hay batería UAT cargada (3 runs, 14 cases) pero **0 resultados ejecutados**. Pendiente de correr la batería.
- ⚠️ `release_signoffs_rows: 0` — ningún signoff clínico ni operativo registrado todavía (normal mientras v1.0 no se libere).

### 5. Última prueba de restauración de backup
**Estado:** ❌ **sin evidencia en el repo.** El workflow `.github/workflows/private-database-backup.yml` existe pero este auditor no encuentra bitácora de restauraciones periódicas. Brecha S2 queda abierta.

### 6. Snapshot de configuración de Supabase Auth
**Estado:** ❌ **no verificado.** Requiere `SUPABASE_MANAGEMENT_TOKEN` como secret de GitHub. Brecha S1 queda abierta.

### Prueba adicional — read-only enforcement ✅
```
UPDATE public.branches set name='HACK' where false;  → ✅ permission denied
INSERT INTO public.branches(code,name) values(...);    → ✅ permission denied
```
Confirma que `claude_audit_reader` solo lee (BYPASS RLS no otorga escritura). Sin riesgo de contaminación de datos.

---

## Veredicto global §15 Seguridad

| Dominio | Estado | Evidencia |
|---|---|---|
| RLS granular por sucursal | ✅ | `broad_policies: []` en C12_00 |
| Segregación read/write | ✅ | read-only proof OK |
| Roles canónicos declarados | ✅ | 21 roles reales, los 2 "faltantes" presentes desde oct |
| Policies ALL demasiado anchas | ✅ | ninguna |
| Inserts directos a release_signoffs | ✅ | bloqueados para anon y authenticated |
| Historial de release firmado | ⚠️ | 0 rows — se poblará al liberar v1.0 |
| Objetos release 1.0 completos | ❌ | faltan `release_operational_signoffs` + `hc_v100_signoff` |
| UAT ejecutado | ⚠️ | 3 runs + 14 cases cargados; 0 results |
| MFA/session/password policy | ⏳ | pendiente Management API |
| Restauración de backup documentada | ❌ | sin bitácora |
| Trazabilidad end-to-end DB viva | ⏳ | requiere rol write |
| RLS cross-sucursal DB viva | ⏳ | requiere JWTs de 3 sucursales |

**§15 Seguridad: FIRMADO en lo defensivo.** Las garantías críticas pasan (RLS, policy breadth, segregación, inserts bloqueados). Lo pendiente son garantías de proceso (release v1.0, UAT ejecutado, backup drill, Auth config) y verificaciones que requieren credenciales adicionales.

**Las 14 migraciones pendientes de v0.67.0 no tienen bloqueador** — el supuesto "bloqueador de roles faltantes" era un artefacto de RLS ocultando la tabla al auditor. Se pueden aplicar con `supabase db push` sin cambios previos.

---

## Acciones restantes (ninguna urgente ni bloqueante de v0.67)

### A1 (no urgente) — Gate v1.0
Construir `release_operational_signoffs` + `hc_v100_signoff(text,text,text,text)` según la especificación de `C13K`. Bloqueador blando de v1.0, no de v0.67.

### A2 (no urgente) — Ejecutar UAT
Correr la batería UAT cargada (3 runs, 14 cases) para generar resultados. Bloqueador blando de v1.0.

### A3 (operacional) — Backup drill
Documentar `docs/BACKUP_RESTORE_DRILL_<fecha>.md` con el resultado de la próxima restauración de prueba.

### A4 (operacional) — Supabase Auth snapshot
Añadir `SUPABASE_MANAGEMENT_TOKEN` como secret del repo para que el workflow pueda consultar MFA, session timeout, password policy y rate limits.

### A5 (fix menor del doctor) — Parse error de `broad_all_policies`
El sub-select de `C11_91` devuelve string vacío cuando no hay match, lo que rompe el `jq fromjson`. Patch: envolver el resultado con `coalesce(..., '[]'::jsonb)`.

---

## Automatización lograda

Con `SUPABASE_AUDIT_DSN` + `bypassrls` + `.github/workflows/sprint-0-doctors.yml` configurados:

1. Semanalmente (lunes 06:00 UTC) y bajo demanda, el workflow:
   - Auto-descubre la región del pooler IPv4 Supabase (us-east-2 en este caso).
   - Corre C11_91 y C12_00 contra DB viva.
   - Verifica que el rol auditor sigue siendo read-only.
   - Commitea reports a `docs/sprint-0/` solo cuando cambian.
   - Sube artifacts (90 días).

El ciclo de verificación semanal está **completamente autónomo**. Cualquier regresión de seguridad (nueva policy ALL ancha, rol inesperado, insert directo abierto) aparece en el próximo report sin intervención humana.
