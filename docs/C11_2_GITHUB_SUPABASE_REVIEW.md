# HemoCura C11.2 — GitHub + Supabase Review

## Confirmado en GitHub

- `js/config.js` contiene una URL real de Supabase, una Publishable Key real y `APP_BASE=/operations/`.
- `deployment-check.html` producía un falso positivo: buscaba `TU-PROYECTO` / `TU_CLAVE` en el texto completo de `config.js`, pero esas cadenas aparecen dentro de los mensajes de validación del propio archivo.
- `ops-dashboard.js` consultaba `incidents.status`, aunque esa columna no existe en Supabase.
- `router.js` declaraba módulos que `views.js` y `layout.js` no terminaban de conectar a un root/mount.
- El menú plano creció demasiado; C11.2 lo organiza por Inicio, Operación, Calidad, Gerencia, Administración y Sistema.

## Confirmado en Supabase

- Proyecto activo y saludable.
- Migraciones v0.22–v0.44 registradas.
- `incidents.requires_quality_followup` existe; `incidents.status` no existe.
- `dispatches.dispatch_date`, `nonconformities.status` y `capa.status` existen.
- Existen `vw_release_1_0_readiness`, `vw_uat_summary`, `vw_continuity_readiness`, `vw_cold_chain_excursions` y `vw_hemovigilance_summary`.
- El validator `C11_90_VALIDATE_FRONTEND_BACKEND.sql` devuelve PASS en 12/12 controles incluyendo resultado general.
- Donantes ya usan `PENDIENTE` por defecto y cuentan con revisión humana controlada.
- `audit_events` ya no permite INSERT/UPDATE/DELETE directo a `authenticated`.

## Hallazgos de seguridad aún abiertos

- Faltan roles `ENCARGADA_LABORATORIO` y `TI`.
- Persisten políticas `FOR ALL` demasiado amplias en `release_signoffs`, UAT y dos catálogos adicionales.
- `release_operational_signoffs` y los RPC de sign-off segregado todavía no existen.
- Supabase Advisor reporta vistas `SECURITY DEFINER`, funciones `SECURITY DEFINER` expuestas y tablas con RLS habilitado sin policy.

## Alcance de C11.2

C11.2 corrige el frontend y el diagnóstico de despliegue. **No modifica RLS, roles ni funciones de producción.** Las correcciones de seguridad deben ir en una migración separada y validarse con un gate independiente para evitar romper producción.
