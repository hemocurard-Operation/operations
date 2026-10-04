# HemoCura v0.25.0

## Instalación
1. Subir SAFE PATCH sobre v0.24.0.
2. Ejecutar `sql/25_PRODUCTION_DEMAND_SUPPLY_v0_25.sql`.
3. Abrir #production.
4. Configurar reglas de rendimiento solo cuando hayan sido validadas.
5. Abrir #supply y configurar mínimo/objetivo/máximo.
6. Revisar cobertura y donantes requeridos.
7. Abrir #bi.
8. Ejecutar #qa.

## Método
La demanda usa medias móviles 30/60/90 días.
No implementa modelos complejos ni opacos.
