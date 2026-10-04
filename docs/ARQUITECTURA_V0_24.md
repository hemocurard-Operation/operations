# Arquitectura v0.24

DONANTE
→ DONACIÓN
→ UNIDAD ORIGEN
→ TAMIZAJE
→ COLA DE REVISIÓN
→ DECISIÓN HUMANA AUTORIZADA
  → APTO      → DISPONIBLE
  → RETENER   → CUARENTENA
  → NO_APTO   → DESCARTADA
→ SALIDA / DESPACHO
→ BI

Bloqueos:
- unidad no APTO: no sale;
- unidad no DISPONIBLE: no sale;
- salida asociada a unidad válida: marca DESPACHADA.
