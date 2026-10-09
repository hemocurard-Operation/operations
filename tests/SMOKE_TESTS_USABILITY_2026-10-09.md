# Smoke Tests — Usabilidad y captura operativa

Fecha: 2026-10-09
Rama: improve/usability-20261008

## Objetivo
Validar que la simplificación de captura no elimine trazabilidad ni controles clínicos y que ningún dato se recapture cuando ya existe en un módulo fuente.

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
   - Registrar un valor fuera del rango configurado del dispositivo.
   - Confirmar mensaje de advertencia sin liberar/bloquear automáticamente producto clínico.

7. **Cadena de frío: búsqueda de dispositivo**
   - Filtrar por código, tipo o ubicación.
   - Confirmar lista de dispositivos y excursiones filtradas.

8. **Recursos: búsqueda de equipo**
   - Buscar por código, tipo, modelo, serie y ubicación.
   - Confirmar acción rápida de intervención.

9. **Recursos: alta simple de equipo**
   - Registrar código, tipo, ubicación y sucursal.
   - Confirmar estado inicial ACTIVO y campos avanzados opcionales.

10. **Recursos: intervención rápida**
    - Registrar mantenimiento correctivo/preventivo o calibración.
    - Confirmar evento en `equipment_service_events`.

11. **Ambiente: lectura rápida**
    - Seleccionar punto ambiental y registrar valor.
    - Confirmar advertencia si está fuera del rango configurado.

12. **Despachos: excepciones primero**
    - Abrir `#dispatches`.
    - Confirmar que la conciliación y diferencias aparecen antes del listado completo.

13. **Despachos: filtro solo diferencias**
    - Activar/desactivar `Solo diferencias`.
    - Confirmar recálculo del resumen sin nueva consulta.

14. **Móvil**
    - Probar ancho <=700px.
    - Confirmar una columna, botones >=44px y formularios sin desbordes horizontales críticos.

15. **Guardrails clínicos**
    - Confirmar que ninguna pantalla nueva libera unidades, descarta unidades, aprueba CAPA ni toma decisiones clínicas automáticamente.

16. **Cierre diario: sin recaptura**
    - Abrir `#dailyinventory`.
    - Confirmar que donantes, donaciones efectivas, tamizajes, inventario, despachos y facturación aparecen desde los registros existentes.
    - Confirmar que no existen campos para volver a escribir esas cantidades.

17. **Cierre diario: inventario como fuente única**
    - Modificar un registro válido en `#bloodinventory`.
    - Volver a `#dailyinventory` y actualizar.
    - Confirmar que el resumen refleja el inventario fuente sin una segunda captura.

18. **Cierre diario: equipos por excepción**
    - Dejar equipos ACTIVO sin alertas y uno en estado distinto de ACTIVO o con alerta.
    - Confirmar que solo el equipo que requiere atención aparece en el cierre.

19. **Centro de Mando sin cierre duplicado**
    - Abrir `#command`.
    - Confirmar que la pantalla es de supervisión y no contiene un segundo formulario de cierre.
    - Confirmar que el enlace “Abrir cierre diario” dirige a `#dailyinventory`.

20. **Cierre diario único**
    - Agregar una observación y pulsar “Cerrar día”.
    - Confirmar que se ejecuta `capture_daily_operational_close` y queda un único registro por fecha + sucursal en `daily_operational_closes`.
    - Confirmar que el cierre no libera unidades ni toma decisiones clínicas.

## Criterio de salida
El bloque puede pasar a UAT cuando los 20 smoke tests sean satisfactorios con al menos un usuario operativo y un usuario de Calidad autenticados.
