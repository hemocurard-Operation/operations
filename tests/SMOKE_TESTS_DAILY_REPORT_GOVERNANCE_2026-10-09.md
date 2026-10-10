# Smoke tests — Gobierno y seguridad del Reporte Operativo Diario

Fecha de actualización: 2026-10-10
Rama: `improve/usability-20261008`

## Gobierno del reporte

1. Usuario sin `DAILY_REPORT_VIEW` no puede consultar reportes.
2. Usuario con `DAILY_REPORT_VIEW` puede consultar únicamente sucursales accesibles.
3. Usuario sin `DAILY_REPORT_WRITE` no puede guardar borradores.
4. Usuario con `DAILY_REPORT_WRITE` puede crear/editar BORRADOR en sucursal permitida.
5. Usuario no puede crear reporte para sucursal no accesible.
6. BORRADOR puede pasar a EN_REVISION únicamente con `DAILY_REPORT_SUBMIT`.
7. BORRADOR no puede pasar directamente a CERRADO.
8. EN_REVISION queda bloqueado para edición normal.
9. EN_REVISION puede pasar a CERRADO únicamente con `DAILY_REPORT_CLOSE`.
10. CERRADO registra `closed_by` y `closed_at`.
11. CERRADO no puede volver a BORRADOR directamente.
12. CERRADO solo puede pasar a REABIERTO con `DAILY_REPORT_REOPEN`.
13. Reapertura exige motivo no vacío.
14. Reapertura registra usuario, fecha y motivo.
15. Cada transición incrementa la versión según el flujo definido.

## Seguridad y RLS añadidos en I174–I223

16. `anon` no tiene SELECT sobre `daily_operational_closes`.
17. `anon` no tiene INSERT sobre `daily_operational_closes`.
18. `anon` no tiene UPDATE sobre `daily_operational_closes`.
19. `anon` no tiene SELECT sobre `daily_operational_report_versions`.
20. `authenticated` conserva SELECT/INSERT/UPDATE de tabla necesarios para aplicar RLS.
21. `authenticated` conserva SELECT sobre historial de versiones.
22. Las RPC save/submit/close/reopen son `SECURITY INVOKER`.
23. Las RPC save/submit/close/reopen tienen `search_path=public`.
24. Las RPC no son ejecutables por `anon`.
25. RLS está habilitado en `daily_operational_closes`.
26. Las políticas del reporte están dirigidas al rol `authenticated`.
27. La política SELECT exige acceso a sucursal + `DAILY_REPORT_VIEW`.
28. La política INSERT exige acceso a sucursal + `DAILY_REPORT_WRITE`.
29. La política UPDATE exige acceso a sucursal y al menos uno de los permisos de transición/escritura.
30. Historial de versiones exige sucursal accesible + `DAILY_REPORT_VIEW`.

## Rendimiento

31. `daily_operational_closes.branch_id` tiene índice de cobertura.
32. `closed_by` tiene índice de cobertura.
33. `last_modified_by` tiene índice de cobertura.
34. `submitted_by` tiene índice de cobertura.
35. `reopened_by` tiene índice de cobertura.
36. `daily_operational_report_versions.changed_by` tiene índice de cobertura.
37. `report_id` mantiene índice para historial por reporte/versión.
38. `branch_id + close_date` mantiene índice para histórico por sucursal.

## Integración / release

39. `#dailyinventory` sigue siendo la captura consolidada principal.
40. No reaparece captura individual de tamizaje como flujo operativo principal.
41. No reaparece captura individual de inventario como flujo operativo principal.
42. No reaparece captura individual de despachos como flujo operativo principal.
43. `quick-capture` de main se conserva sin duplicar el reporte diario.
44. Router conserva ambas rutas sin colisión.
45. Mi trabajo expone el reporte solo a quien corresponde.
46. Cierre no libera unidades clínicamente.
47. Copiar inventario anterior sigue exigiendo verificación física.
48. UAT valida operador LABORATORIO/ENCARGADA.
49. UAT valida supervisor/calidad.
50. UAT valida usuario de segunda sucursal sin acceso cruzado.
51. Vista móvil permite guardar y enviar sin scroll lateral crítico.
52. Vista tablet permite completar matriz de inventario.
53. Impresión no muestra controles interactivos innecesarios.
54. Borrador local no sobrescribe reporte remoto más reciente sin confirmación.
55. Reporte cerrado abre en solo lectura.
56. Reapertura deja evidencia visible en historial.
57. Lotes de tamizaje duplicados bloquean cierre.
58. Lotes desbalanceados bloquean cierre.
59. Despachos duplicados bloquean cierre.
60. Fila de despacho incompleta bloquea cierre.
61. Estado “sin actividad” evita filas ficticias de tamizaje.
62. Estado “sin despachos” evita filas ficticias de despacho.
63. Inventario copiado del día anterior queda marcado como pendiente de verificación.
64. CI del head ejecuta frontend/browser smoke.
65. PR permanece draft hasta completar gates críticos.

> Nota: esta lista define escenarios. No implica que los 65 hayan sido ejecutados automáticamente. Los puntos de CI, UAT, móvil/tablet y sesiones autenticadas requieren evidencia de ejecución antes de marcarse como PASS.
