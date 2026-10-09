# Smoke Tests — Usabilidad y captura operativa

Fecha: 2026-10-09
Rama: improve/usability-20261008

## Objetivo
Validar la captura operativa simplificada, manteniendo trazabilidad y guardrails clínicos. Durante esta fase de digitalización, tamizaje, inventario y despachos se capturan de forma consolidada en el Reporte Operativo Diario y no por registro individual.

1. **Mi trabajo por permisos**
   - Iniciar sesión con un usuario con permisos limitados.
   - Confirmar que solo aparecen acciones permitidas.

2. **Reporte rápido de incidencia**
   - Abrir `#incidents`.
   - Registrar descripción, sucursal, proceso y acción inmediata.
   - Confirmar persistencia y `requires_quality_followup=true`.

3. **Incidencia conserva datos ante error**
   - Simular fallo de red o RLS.
   - Confirmar que el diálogo permanece abierto y conserva campos.

4. **Separación usuario operativo / Calidad**
   - Confirmar que el reporte rápido no exige causa raíz, NC ni CAPA.
   - Confirmar que `#quality` mantiene la gestión SGC completa.

5. **Cadena de frío: captura mínima**
   - Seleccionar dispositivo y registrar temperatura.
   - Confirmar fecha/hora automática desde Supabase.

6. **Cadena de frío: alerta fuera de rango**
   - Registrar un valor fuera del rango configurado.
   - Confirmar advertencia sin decisión clínica automática.

7. **Recursos: intervención rápida**
   - Buscar equipo y registrar mantenimiento/calibración.
   - Confirmar persistencia del evento.

8. **Ambiente: lectura rápida**
   - Seleccionar punto ambiental y registrar valor.
   - Confirmar advertencia si está fuera del rango.

9. **Móvil**
   - Probar ancho <=700px.
   - Confirmar controles táctiles y tablas utilizables.

10. **Guardrails clínicos**
    - Confirmar que ninguna pantalla nueva libera unidades, descarta unidades, aprueba CAPA ni toma decisiones clínicas automáticamente.

11. **Migración de reporte consolidado**
    - Ejecutar `sql/40_DAILY_OPERATIONAL_REPORT_v0_40.sql`.
    - Confirmar columnas `screening_lots`, `manual_inventory`, `manual_dispatches`, `equipment_snapshot` en `daily_operational_closes`.

12. **Tamizaje sin captura individual**
    - Abrir `#screening`.
    - Confirmar que no existe botón/formulario de “Nuevo tamizaje”.
    - Confirmar que se muestran lotes/tandas diarios desde el reporte.

13. **Lote diario de tamizaje**
    - Abrir `#dailyinventory`.
    - Crear una fila de lote con recibidos, no reactivos, reactivos, pendientes y descartados.
    - Guardar y recargar; confirmar persistencia exacta.

14. **Inventario sin captura individual**
    - Abrir `#bloodinventory`.
    - Confirmar que no existe formulario para registrar una unidad/bolsa individual.
    - Confirmar que el último conteo manual consolidado es visible.

15. **Inventario manual consolidado**
    - En `#dailyinventory`, registrar cantidades para A+, A-, B+, B-, O+, O-, AB+, AB- en sangre total, paquete globular, plasma y plaquetas.
    - Guardar y recargar; confirmar valores.

16. **Despachos sin captura individual**
    - Abrir `#dispatches`.
    - Confirmar que no existe creación de despacho unitario.
    - Confirmar que la captura operativa remite al reporte diario.

17. **Despacho consolidado**
    - En `#dailyinventory`, agregar destino, grupo, componente, cantidad y observación.
    - Guardar y recargar; confirmar persistencia.

18. **Históricos técnicos solo consulta**
    - Confirmar que los antiguos resultados individuales de tamizaje, inventario calculado y conciliación técnica siguen visibles únicamente como consulta/trazabilidad.

19. **Centro de Mando sin captura duplicada**
    - Abrir `#command`.
    - Confirmar que funciona como supervisión/score y enlaza al Reporte Operativo Diario sin un segundo formulario de captura.

20. **Cierre del reporte**
    - Guardar primero como BORRADOR y luego como CERRADO.
    - Confirmar un único registro por fecha + sucursal en `daily_operational_closes`.
    - Confirmar que cerrar el reporte no ejecuta liberaciones ni decisiones clínicas.

## Iteraciones adicionales I54–I68

21. **Responsable autocompletado**
    - Abrir `#dailyinventory` con un usuario cuyo nombre exista en el contexto de seguridad.
    - Confirmar que Responsable/Bioanalista aparece prellenado y puede corregirse antes de guardar.

22. **Totales automáticos de tamizaje**
    - Agregar dos lotes.
    - Confirmar actualización automática de recibidos, no reactivos, reactivos, pendientes y descartados en el pie de tabla.

23. **Balance de lote**
    - Crear un lote donde recibidos sea igual a la suma de las salidas.
    - Confirmar estado `OK`.
    - Cambiar una cantidad y confirmar advertencia de diferencia.

24. **Lote duplicado**
    - Registrar dos filas con el mismo lote/tanda.
    - Confirmar advertencia y bloqueo del cierre hasta corregirlo.

25. **Cierre bloqueado por inconsistencia**
    - Dejar un lote desbalanceado.
    - Confirmar que “Cerrar reporte” permanece deshabilitado.
    - Corregir el lote y confirmar que se habilita.

26. **Totales por grupo de inventario**
    - Registrar cantidades en varias columnas de un grupo ABO/Rh.
    - Confirmar cálculo automático del total de la fila.

27. **Totales generales de inventario**
    - Registrar cantidades en varios grupos.
    - Confirmar totales de Sangre total, Paquete globular, Plasma, Plaquetas y Total general.

28. **Total de despachos**
    - Crear varios despachos consolidados.
    - Confirmar que el contador superior suma correctamente las unidades.

29. **Novedades de equipos**
    - Tener un equipo ACTIVO sin alerta y uno con alerta/estado no ACTIVO.
    - Confirmar que el contador muestra solo las novedades y que solo esas aparecen en el reporte.

30. **Indicador de avance**
    - Abrir un reporte nuevo e ir completando identificación y lotes.
    - Confirmar que el porcentaje “listo” cambia y llega a 100% cuando los requisitos mínimos están conformes.

31. **Protección de cambios sin guardar**
    - Modificar una cantidad y pulsar “Cargar”.
    - Confirmar advertencia antes de descartar cambios.
    - Confirmar también advertencia al intentar abandonar/recargar la página.

32. **Modo solo lectura después del cierre**
    - Cerrar un reporte y recargarlo.
    - Confirmar que lotes, inventario, despachos, responsable y observaciones quedan deshabilitados.

33. **Confirmación explícita de cierre**
    - Pulsar “Cerrar reporte” con un reporte válido.
    - Confirmar diálogo de confirmación y que cancelar no cambia el estado.

34. **Impresión operativa**
    - Pulsar “Imprimir”.
    - Confirmar que navegación, botones y controles de edición no aparecen en la salida impresa y que tablas/valores sí son legibles.

35. **Filtros de consulta consolidados**
    - En `#screening`, filtrar por sucursal y fechas y validar totales.
    - En `#bloodinventory`, seleccionar sucursal y validar el último conteo manual y KPI.
    - En `#dispatches`, filtrar por sucursal/fechas y validar registros, unidades y destinos.

## Criterio de salida
El bloque puede pasar a UAT cuando los 35 smoke tests sean satisfactorios con al menos un usuario operativo y un usuario de Calidad autenticados, incluyendo prueba en móvil/tablet y verificación de impresión.
