# HemoCura Operations v0.18.0 RC

Etapa: Runtime Evidence Collector.

## Nueva ruta
`#evidence`

## Objetivo
Compilar en un solo reporte:
- versión runtime;
- frontend self-test;
- QA runtime;
- caché;
- checklist Freeze;
- checklist QA Release;
- checklist Pre-Go-Live;
- Promotion Gate;
- sesión actual;
- estado del Clinical Core.

## Regla
No promover a v1.0.0 si el reporte indica controles pendientes.

El SAFE PATCH no incluye `js/config.js`.
