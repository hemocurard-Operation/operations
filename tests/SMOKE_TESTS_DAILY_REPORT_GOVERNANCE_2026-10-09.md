# Smoke Tests — Gobierno del Reporte Operativo Diario

Fecha: 2026-10-09
Rama: improve/usability-20261008

## I84–I98

1. **Permiso DAILY_REPORT_VIEW**
   - Usuario sin permiso no puede abrir `#dailyinventory`.
   - Usuario con permiso puede consultar reportes de sucursales autorizadas.

2. **Permiso DAILY_REPORT_WRITE**
   - Usuario con VIEW pero sin WRITE ve el reporte en solo lectura.
   - Usuario con WRITE puede crear/editar BORRADOR.

3. **RLS por sucursal**
   - Usuario de una sucursal no puede consultar ni editar otra sucursal salvo rol global autorizado.

4. **Guardado solo en BORRADOR/REABIERTO**
   - Intentar editar EN_REVISION o CERRADO debe fallar.

5. **Enviar a revisión**
   - BORRADOR válido pasa a EN_REVISION con `submitted_by` y `submitted_at`.

6. **Bloqueo durante revisión**
   - EN_REVISION queda en solo lectura para captura operativa.

7. **Cerrar y firmar**
   - Solo usuario con DAILY_REPORT_CLOSE puede pasar EN_REVISION → CERRADO.
   - Se registran `closed_by` y `closed_at`.

8. **Cierre directo prohibido**
   - BORRADOR → CERRADO directo debe ser rechazado por trigger.

9. **Reapertura controlada**
   - Solo usuario con DAILY_REPORT_REOPEN puede reabrir.
   - Motivo vacío debe ser rechazado.

10. **Motivo de reapertura**
    - Confirmar `reopened_by`, `reopened_at` y `reopen_reason`.

11. **Versionado**
    - Cada guardado/transición incrementa `report_version`.
    - Cada versión genera snapshot en `daily_operational_report_versions`.

12. **Historial visible**
    - Interfaz muestra versión, estado, fecha/hora y usuario del cambio.

13. **Funciones SECURITY INVOKER**
    - Confirmar que save/submit/close/reopen tienen `prosecdef=false`.

14. **Borrador local**
    - Solo se usa mientras el reporte es editable.
    - Se elimina al guardar exitosamente en Supabase.

15. **Advisors de seguridad**
    - Confirmar que las funciones nuevas del reporte no aparecen como SECURITY DEFINER ejecutables por authenticated.
    - Registrar por separado los hallazgos heredados de vistas SECURITY DEFINER para remediación progresiva.

## Gate de salida
No promover el PR hasta completar estos 15 escenarios con un usuario de LABORATORIO/ENCARGADA y un usuario de supervisión/calidad, además de los smoke tests operativos existentes.
