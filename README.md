# HemoCura Operations v0.16.0 RC

Etapa: Static Audit + Safe Deployment Gate.

## Hallazgo de auditoría
El código JS de v0.15.0 pasó:
- sintaxis;
- imports relativos;
- archivos críticos.

Pero el ZIP completo contiene `js/config.js` de plantilla.

## Recomendación
Si ya tienes Supabase configurado:
**usa SAFE PATCH, no el ZIP completo**.

## Diagnóstico
`/operations/status.html`

Ahora también valida que `js/config.js` no contenga placeholders.
