# Runtime Evidence Collector

## Ruta
`/operations/#evidence`

## Requisito
Ejecutar previamente:
1. `/operations/status.html`
2. `#freeze`
3. `#qa`
4. `#release`
5. `/operations/promotion.html`

## Resultado
Genera un JSON consolidado con:
- runtime version;
- frontend health;
- QA;
- RLS checks;
- cache state;
- checklists;
- promotion assessment.

## Criterio
`candidate_for_v1 = true`

solo cuando todos los controles de la matriz están aprobados.

Esto es evidencia técnica. La autorización operativa sigue siendo independiente.
