# I-007 · Presupuesto de UX y rendimiento sin telemetría clínica

**Versión candidata:** 0.45.7 RC  
**Fecha:** 2026-10-10

## Objetivo

Crear una línea base objetiva para que futuras mejoras de usabilidad no hagan crecer silenciosamente el frontend ni aumenten la complejidad de captura del Reporte Operativo Diario.

La medición se realiza exclusivamente en CI sobre archivos fuente. **No se instrumentan usuarios ni se envían datos operativos, clínicos o personales a un sistema de analítica.**

## Línea base v0.45.6

Archivos críticos observados antes de I-007:

- `hemocura-core/daily-inventory.js`: 20,579 bytes.
- `hemocura-core/daily-inventory-flow.js`: 5,380 bytes.
- `hemocura-core/command-data.js`: 3,758 bytes.
- `hemocura-core/layout.js`: 9,597 bytes.
- `css/ui-v0442.css`: 6,911 bytes.
- Total del conjunto vigilado: **46,225 bytes**.

El contrato I-007 permite un margen limitado hasta 52,000 bytes agregados. Superar ese valor requiere una decisión explícita y documentada, no una ampliación silenciosa del límite.

## Qué controla el gate

### 1. Tamaño de archivos

Cada archivo crítico tiene un máximo individual además del presupuesto agregado. Esto permite detectar tanto crecimiento general como concentración de complejidad en un único módulo.

### 2. Complejidad visible de captura

Se cuenta en el fuente del Reporte Operativo Diario el número de etiquetas:

- `input`;
- `select`;
- `textarea`;
- `button`.

No pretende medir perfectamente la experiencia humana, pero sí funciona como indicador temprano cuando una iteración agrega demasiados controles visibles en vez de simplificar el flujo.

### 3. Marcadores funcionales obligatorios

El gate exige conservar señales que representan el flujo seguro actual:

- `Sin actividad`;
- `Guardar borrador`;
- `Enviar a revisión`;
- `Cerrar y firmar`;
- aclaración de que el reporte no libera componentes sanguíneos.

### 4. Privacidad

El scope del Reporte Operativo Diario no puede incorporar:

- Google Analytics / gtag;
- Mixpanel;
- Segment;
- PostHog;
- Sentry Capture;
- `navigator.sendBeacon`;
- `localStorage` o `sessionStorage` para telemetría;
- endpoints HTTP externos desde el asistente;
- `service_role`;
- RPC de Supabase directamente desde `daily-inventory-flow.js`.

Las escrituras funcionales continúan pasando por la capa controlada existente.

## Artefactos

- `contracts/ux-budget-v0.45.7.json`
- `tools/ux_budget_gate.py`
- `.github/workflows/ux-performance-budget.yml`

Cada ejecución CI genera `ux-budget-report.json` como artefacto del workflow.

## Qué NO mide I-007

I-007 no afirma todavía que un usuario real completa el reporte en un tiempo determinado. El tiempo de tarea debe medirse posteriormente en UAT supervisado, registrando únicamente métricas agregadas como duración y número de pasos, sin capturar contenido clínico ni identificadores de pacientes/donantes.

## Gate de salida

- UX Performance Budget = PASS.
- Daily Report Safety = PASS.
- Quick Capture Safety = PASS.
- Frontend Browser Smoke = PASS cuando corresponda.
- Runtime Contract = PASS cuando corresponda.
- GitHub Pages posterior al merge = PASS.

## Próxima iteración

**I-008 · Source of Truth del frontend y eliminación segura de duplicados.**

Objetivo: inventariar archivos duplicados raíz ↔ `hemocura-core`, demostrar cuáles no son importados por el runtime actual y retirar sólo los que tengan evidencia suficiente, reduciendo el riesgo de modificar código legacy por error.