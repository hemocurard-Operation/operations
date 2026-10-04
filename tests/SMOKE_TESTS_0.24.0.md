# Smoke Tests v0.24.0

1. SQL 24 instala.
2. #bloodflow carga.
3. Cola muestra unidades origen.
4. Unidad sin tamizaje = SIN_TAMIZAJE.
5. Tamizaje validado sin decisión = LISTA_PARA_REVISION.
6. RETENER no libera.
7. APTO requiere rol autorizado.
8. APTO mueve componentes en CUARENTENA a DISPONIBLE.
9. NO_APTO mueve componentes a DESCARTADA.
10. Venta con unidad no APTO debe fallar.
11. Venta con unidad no DISPONIBLE debe fallar.
12. Venta con unidad APTO+DISPONIBLE se guarda y marca DESPACHADA.
13. BI muestra embudo 30 días.
14. js/config.js no se modifica.
