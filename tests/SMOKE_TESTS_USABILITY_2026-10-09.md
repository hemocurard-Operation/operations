# Smoke Tests — Usabilidad y captura operativa

Fecha: 2026-10-09
Rama: improve/usability-20261008

## Objetivo
Validar la captura operativa simplificada, manteniendo trazabilidad y guardrails clínicos. Durante esta fase de digitalización, tamizaje, inventario y despachos se capturan de forma consolidada en el Reporte Operativo Diario y no por registro individual.

1. **Mi trabajo por permisos**
   - Confirmar que solo aparecen acciones permitidas por el perfil.
2. **Reporte rápido de incidencia**
   - Registrar descripción, sucursal, proceso y acción inmediata.
3. **Incidencia conserva datos ante error**
   - Simular fallo de red/RLS y confirmar conservación del formulario.
4. **Separación operativo / Calidad**
   - Confirmar que reporte rápido no exige causa raíz/NC/CAPA.
5. **Cadena de frío: captura mínima**
   - Registrar dispositivo + temperatura.
6. **Cadena de frío: alerta fuera de rango**
   - Confirmar advertencia sin decisión clínica automática.
7. **Recursos: intervención rápida**
   - Registrar mantenimiento/calibración.
8. **Ambiente: lectura rápida**
   - Registrar lectura y advertencia de fuera de rango.
9. **Móvil**
   - Probar ancho <=700px y controles táctiles.
10. **Guardrails clínicos**
   - Confirmar ausencia de liberación/descarte/aprobación automática.
11. **Migración reporte consolidado**
   - Ejecutar `sql/40_DAILY_OPERATIONAL_REPORT_v0_40.sql`.
12. **Tamizaje sin captura individual**
   - Confirmar que `#screening` no permite alta individual.
13. **Lote diario de tamizaje**
   - Guardar y recargar una tanda consolidada.
14. **Inventario sin captura individual**
   - Confirmar ausencia de alta por bolsa/unidad.
15. **Inventario manual consolidado**
   - Registrar matriz ABO/Rh × componente.
16. **Despachos sin captura individual**
   - Confirmar ausencia de alta unitaria.
17. **Despacho consolidado**
   - Registrar destino, grupo, componente y cantidad.
18. **Históricos técnicos solo consulta**
   - Confirmar histórico individual como referencia.
19. **Centro de Mando sin captura duplicada**
   - Confirmar supervisión sin segundo formulario.
20. **Cierre del reporte**
   - Guardar BORRADOR y luego CERRADO.

## Iteraciones I54–I68

21. **Responsable autocompletado**
22. **Totales automáticos de tamizaje**
23. **Balance de lote**
24. **Lote duplicado**
25. **Cierre bloqueado por inconsistencia**
26. **Totales por grupo de inventario**
27. **Totales generales de inventario**
28. **Total de despachos**
29. **Novedades de equipos**
30. **Indicador de avance**
31. **Protección de cambios sin guardar**
32. **Modo solo lectura después del cierre**
33. **Confirmación explícita de cierre**
34. **Impresión operativa**
35. **Filtros de consulta consolidados**

## Iteraciones I69–I83

36. **Copiar inventario anterior**
   - En un reporte nuevo pulsar `Copiar inventario anterior`.
   - Confirmar que toma únicamente el último inventario de la misma sucursal y fecha previa.
   - Confirmar advertencia de verificación física antes del cierre.

37. **Sin actividad de tamizaje**
   - Marcar `Sin actividad`.
   - Confirmar que no se exige crear una fila artificial de lote y que el reporte puede continuar.

38. **Sin despachos**
   - Marcar `Sin despachos`.
   - Confirmar que no se exige una fila vacía y que el cierre puede continuar.

39. **Catálogo de componentes en despacho**
   - Confirmar que el componente se selecciona entre Sangre total, Paquete globular, Plasma y Plaquetas.
   - Confirmar que no depende de texto libre para esos cuatro componentes.

40. **Destinos recientes como sugerencia**
   - Confirmar que los destinos utilizados recientemente aparecen como sugerencias sin impedir escribir un destino nuevo.

41. **Duplicar fila de despacho**
   - Crear un despacho y usar el botón `+` de la fila.
   - Confirmar copia rápida para modificar grupo/cantidad sin reescribir el destino.

42. **Despacho duplicado**
   - Crear dos filas con mismo destino + grupo + componente.
   - Confirmar advertencia y bloqueo del cierre hasta consolidar/corregir.

43. **Resumen de despachos por componente**
   - Capturar varios componentes.
   - Confirmar resumen automático de cantidades por componente.

44. **Estado visual por sección**
   - Confirmar indicadores Completo/Revisar/Pendiente para identificación, tamizaje, inventario y despachos.

45. **Borrador local automático**
   - Modificar el reporte sin guardarlo en Supabase.
   - Confirmar existencia de borrador local para la combinación fecha + sucursal.

46. **Restauración de borrador local**
   - Salir y volver al reporte sin un registro servidor existente.
   - Confirmar que el sistema ofrece restaurar el borrador local.

47. **Limpieza de borrador local después de guardar**
   - Guardar exitosamente en Supabase.
   - Confirmar que el borrador local correspondiente se elimina.

48. **Acciones principales accesibles en móvil**
   - En ancho <=700px confirmar que Guardar borrador y Cerrar reporte permanecen visibles y tienen altura táctil suficiente.

49. **Confirmación resumida antes del cierre**
   - Pulsar Cerrar reporte.
   - Confirmar que el diálogo resume número de lotes, inventario total y unidades despachadas.

50. **Reporte previo aislado por sucursal**
   - Tener reportes previos en dos sucursales.
   - Confirmar que `Copiar inventario anterior` nunca toma información de otra sucursal.

## Criterio de salida
El bloque puede pasar a UAT cuando los 50 smoke tests sean satisfactorios con al menos un usuario operativo y un usuario de Calidad autenticados, incluyendo móvil/tablet, impresión y validación de RLS por sucursal.
