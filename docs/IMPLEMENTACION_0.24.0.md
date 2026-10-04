# HemoCura v0.24.0 — Flujo Sanguíneo Controlado

## Objetivo
Automatizar trazabilidad y bloqueos sin automatizar decisiones clínicas.

## Secuencia
Donante → Donación → Tamizaje → Revisión manual → Liberación → Inventario → Salida.

## Instalación
1. Subir SAFE PATCH sobre v0.23.0.
2. Ejecutar `sql/24_CONTROLLED_BLOOD_FLOW_v0_24.sql`.
3. Probar `#bloodflow`.
4. Probar una decisión RETENER.
5. Probar una decisión APTO con usuario autorizado.
6. Confirmar que la unidad pasa CUARENTENA → DISPONIBLE.
7. Asociar una unidad disponible a una salida.
8. Confirmar que pasa DISPONIBLE → DESPACHADA.
9. Ejecutar `#bi` y `#qa`.

## Regla de seguridad
El sistema NO determina APTO automáticamente.
