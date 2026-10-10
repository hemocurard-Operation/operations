# I-006 · Ergonomía del Reporte Operativo Diario

**Versión candidata:** 0.45.6 RC  
**Fecha:** 2026-10-10

## Objetivo

Reducir fricción y densidad visual del Reporte Operativo Diario sin agregar automatización clínica ni modificar el backend productivo.

## Mejoras

1. **Actividad opcional progresiva**
   - Al marcar `Sin actividad` en Tamizaje, la tabla se oculta y el botón de agregar lote queda deshabilitado.
   - Al marcar `Sin despachos`, la tabla de despachos se oculta y el botón de agregar despacho queda deshabilitado.
   - Los valores existentes no se eliminan silenciosamente; simplemente no se envían mientras la opción `Sin actividad` esté marcada.

2. **Inventario anterior asistido**
   - Se añade `Usar inventario anterior`.
   - La copia sólo ocurre por acción explícita del usuario.
   - Antes de copiar se muestra confirmación indicando que las cantidades deben verificarse físicamente.
   - La función sólo copia `manual_inventory`; no copia tamizaje, despachos, decisiones, estados ni liberaciones.
   - El botón queda deshabilitado para reportes no editables o perfiles de sólo lectura.

3. **Sincronización de estado**
   - Al cargar otra fecha/sucursal, la interfaz vuelve a reflejar automáticamente si el reporte tiene o no actividad y si está editable.
   - Se observa el cambio de estado del reporte para evitar que controles auxiliares queden habilitados después de un cierre.

4. **Móvil / tablet**
   - tablas de captura con anchos controlados y scroll horizontal;
   - botones de acción con mayor superficie táctil;
   - acciones principales fijas al pie del formulario durante captura;
   - layout de una columna en pantallas pequeñas;
   - herramienta de inventario adaptada a móvil.

5. **Seguridad de presentación**
   - mensajes dinámicos del asistente se escapan antes de insertarse en HTML.

## Nuevo gate

Se incorpora `HemoCura Daily Report Safety` con controles estáticos que verifican:

- copia de inventario sólo por click explícito;
- confirmación y verificación física obligatoria en el texto;
- copia deshabilitada en modo no editable;
- ausencia de `localStorage` en el asistente;
- ausencia de RPC directos desde el asistente;
- ausencia de `service_role`;
- preservación del texto que prohíbe interpretación/liberación clínica;
- guardado del reporte como `BORRADOR`;
- ocultar actividad sin borrar datos silenciosamente;
- escape de errores dinámicos.

## Fuera de alcance

- No hay cambios DDL/RLS.
- No hay cambios en `js/config.js`.
- No se autocompletan resultados de tamizaje.
- No se copia un reporte anterior completo.
- No se determina elegibilidad, compatibilidad o liberación de componentes.

## Gate de salida

- Daily Report Safety = PASS.
- Quick Capture Safety = PASS.
- Frontend Browser Smoke = PASS.
- Runtime Contract = PASS cuando corresponda.
- Pages deployment posterior al merge = PASS.

## Próxima iteración

**I-007 · Medición de tiempos y pasos de captura.** Instrumentar métricas operativas no clínicas para comparar número de acciones, tiempo de llenado y abandono por sección sin registrar datos sensibles del formulario.