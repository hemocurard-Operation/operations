# I-005 · Integración selectiva del Reporte Operativo Diario

**Versión candidata:** 0.45.5 RC  
**Fecha:** 2026-10-10

## Objetivo

Hacer accesible desde `main` el backend del Reporte Operativo Diario que ya existe en Supabase, sin fusionar por arrastre el PR #5 ni revertir las mejoras de usabilidad 0.45.x.

## Cambios portados selectivamente

1. `router.js`: nueva ruta `dailyinventory` en **TRABAJO DIARIO**.
2. `views.js`: root `dailyinventory-root`.
3. `access-control.js`: acceso condicionado a `DAILY_REPORT_VIEW`.
4. `command-data.js`: lectura del reporte, versiones y RPC save/submit/close/reopen.
5. `daily-inventory.js`: módulo reconciliado construido sobre el contrato productivo actual.
6. `layout.js`: import y mount del módulo.
7. `VERSION.json`: 0.45.5 RC.

## Qué se preserva de 0.45.4

- `quick-capture` permanece como flujo independiente.
- La navegación por roles no se sustituye.
- No se reemplazan Donantes, Tamizaje, Inventario de Sangre ni Despachos.
- No se porta el router/layout completo del branch antiguo.
- No se modifica `js/config.js`.

## Guardrails

El Reporte Operativo Diario:

- registra datos agregados por lote y conteos operativos;
- no interpreta resultados de tamizaje;
- no determina elegibilidad de donantes;
- no determina compatibilidad transfusional;
- no libera componentes sanguíneos;
- el botón **Cerrar y firmar** cierra exclusivamente el reporte operativo;
- todas las escrituras usan los RPC productivos controlados y RLS/permissions existentes.

## Simplificación aplicada

La versión reconciliada del módulo evita incorporar cambios históricos que competían con la UX actual. El usuario puede:

`Fecha/Sucursal → Responsable → Lotes → Inventario → Despachos → Novedades de equipos → Observaciones → Guardar → Enviar → Cerrar`

Las inconsistencias visibles se limitan a controles administrativos:

- lote duplicado;
- balance aritmético del lote;
- despacho incompleto/duplicado;
- campos esenciales faltantes.

Ninguno de estos controles toma una decisión clínica.

## Dependencias verificadas

Supabase productivo ya contiene:

- tablas del reporte;
- permisos DAILY_REPORT_*;
- RLS;
- RPC save/submit/close/reopen como SECURITY INVOKER;
- revocación de acceso anon.

## Gates del PR

- Frontend Browser Smoke = PASS.
- Quick Capture Safety = PASS si es disparado.
- VERSION coherente.
- rutas = vistas = mounts.
- ninguna regresión de `quick-capture`.
- GitHub Pages build/deployment posterior al merge.

## Pendiente deliberado

No se incorporan todavía estilos específicos `dor-*` del branch histórico. La pantalla utiliza principalmente componentes existentes de 0.45.x. La optimización visual/móvil se reserva para I-006 después de validar primero la integración funcional.

## Próxima iteración

**I-006 · Ergonomía móvil y reducción de captura del Reporte Operativo Diario**, guiada por smoke, revisión visual y flujo real por rol.