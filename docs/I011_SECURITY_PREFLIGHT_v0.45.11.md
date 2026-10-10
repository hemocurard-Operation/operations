# I-011 · Security Preflight · HemoCura v0.45.11

Fecha de corte: 2026-10-10
Repositorio: `hemocurard-Operation/operations`
Base: `main` @ `fb40db16d784ce20f4a51a899959e95a74f22f83`
Proyecto Supabase: `tiothqiljipdamgudvcb`

## Objetivo

Cerrar una línea base verificable de seguridad antes de aplicar cambios DDL o ampliar funciones clínicas. Esta iteración es de observación y clasificación: no modifica RLS, funciones, vistas, Auth ni datos productivos.

## Estado de C12 preflight

Consulta ejecutada contra Supabase usando `sql/C12_00_PREFLIGHT_SECURITY_HARDENING.sql`.

Resultado:

- Roles faltantes entre `ENCARGADA_LABORATORIO` y `TI`: ninguno.
- `release_signoffs`: 0 filas.
- Firmantes duplicados: ninguno.
- UAT: 0 runs, 8 casos, 0 resultados.
- Políticas amplias `ALL` en `release_signoffs` y tablas UAT revisadas: ninguna.
- INSERT directo de `authenticated` sobre `release_signoffs`: false.
- INSERT directo de `anon` sobre `release_signoffs`: false.
- RPC `hc_v044_release_signoff(text,text,text,text)`: existe.

## Supabase Security Advisor

Hallazgos observados el 2026-10-10:

1. `security_definer_view`: 67 hallazgos ERROR.
2. `function_search_path_mutable`: 19 hallazgos WARN.
3. `authenticated_security_definer_function_executable`: 28 hallazgos WARN.
4. Protección contra contraseñas filtradas: deshabilitada.

## Clasificación para las siguientes iteraciones

### Prioridad P0

- Revisar las 67 vistas y determinar cuáles deben convertirse a `security_invoker`, cuáles deben perder acceso de `anon/authenticated`, y cuáles deben moverse fuera de superficie expuesta.
- Revisar las 28 funciones `SECURITY DEFINER` ejecutables por `authenticated`; mantener sólo las justificadas y con autorización interna explícita.
- Revisar los 19 `search_path` mutables y fijar `search_path` seguro en funciones privilegiadas.

### Prioridad P1

- Validar RLS y grants por tabla expuesta.
- Verificar wrappers controlados `hc_*` frente a RPC legacy.
- Verificar que funciones clínicas o de aprobación nunca otorguen una decisión automática fuera de los guardrails humanos existentes.

### Prioridad P2

- Activar protección de contraseñas filtradas en Auth desde configuración administrada, previa validación de impacto.

## Dependencias

Esta iteración no declara C12/C13 instalados. Sólo genera evidencia preflight.

La siguiente iteración debe preparar el hardening de C12/C13A con validadores y rollback explícito antes de cualquier aplicación en producción.

## Gate de cierre I-011

I-011 se considera PASS cuando:

- [x] Repositorio y commit base identificados.
- [x] Proyecto Supabase identificado y saludable.
- [x] C12 preflight ejecutado en modo read-only.
- [x] Security Advisor capturado.
- [x] Hallazgos clasificados por prioridad.
- [x] Ningún cambio DDL ni mutación productiva realizado.

Estado: **PASS / PRE-FLIGHT ONLY**

Próximo paso: **I-012 · C12/C13A hardening candidate + validation plan**.
