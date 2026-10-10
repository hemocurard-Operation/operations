# I-009 · Reducción controlada de duplicados legacy · Lote A

**Versión candidata:** 0.45.9 RC  
**Fecha:** 2026-10-10

## Objetivo

Reducir la deuda de módulos sombra en la raíz del repositorio sin cambiar el runtime ni borrar código divergente que todavía requiera análisis.

## Regla de eliminación

Un módulo raíz sólo puede retirarse en este lote si se cumplen simultáneamente:

1. existe una contraparte con el mismo nombre en `hemocura-core/`;
2. ambos archivos tienen el mismo blob SHA de Git;
3. el gate I-008 confirma que `hemocura-core` no importa módulos legacy raíz;
4. la cadena oficial de runtime sigue siendo `index.html → js/app.js → hemocura-core/bootstrap.js → hemocura-core/layout.js`;
5. el PR pasa Browser Smoke y gates existentes.

## Archivos retirados

| Legacy raíz | Canónico | Blob SHA idéntico |
|---|---|---|
| `bi.js` | `hemocura-core/bi.js` | `3ebaffd06306225b9ebe8f3a932dbe6e8c93797b` |
| `blood-flow-data.js` | `hemocura-core/blood-flow-data.js` | `bc487d534df3ec65027e69bc1237de609fa03e45` |
| `blood-flow.js` | `hemocura-core/blood-flow.js` | `aa384d97630af3072f166283e07cf179c7152052` |
| `blood-inventory.js` | `hemocura-core/blood-inventory.js` | `d04268fa07403c828a18f3c03e90e88f26d9797f` |
| `command-center.js` | `hemocura-core/command-center.js` | `a9cb798474b48920b64f9280201bb51e5b919186` |

No se modifica ninguna contraparte canónica.

## Contrato actualizado

Se añade `contracts/frontend-source-of-truth-v0.45.9.json`.

El máximo permitido de sombras raíz ↔ core baja de **27 a 22**. El gate verifica además que los cinco archivos retirados permanezcan ausentes y que sus equivalentes canónicos continúen presentes.

## Impacto

- comportamiento funcional esperado: ninguno;
- Supabase: sin cambios;
- RLS/RPC: sin cambios;
- guardrails clínicos: sin cambios;
- `js/config.js`: sin cambios;
- rollback: restaurar los cinco blobs exactos si apareciera una dependencia externa no detectada.

## Pendiente

Los 22 módulos sombra restantes no se consideran seguros para eliminación automática. Algunos divergen de `hemocura-core` y otros todavía deben compararse individualmente.

## Próxima iteración

**I-010 · Segundo lote de duplicados exactos + clasificación de divergentes.**

Objetivo: comparar los 22 restantes, retirar únicamente equivalentes exactos y generar una matriz `IDENTICAL / DIVERGENT / UNIQUE` para no mezclar limpieza con refactor.