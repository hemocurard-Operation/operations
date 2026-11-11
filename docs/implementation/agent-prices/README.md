# Revisión de precios desde el agente de proveedores · 0.59.0

En Orquestación y Resiliencia → Agentes de mejora → Proveedores se añade una revisión bajo demanda del historial de cotizaciones. Se requiere PURCHASE_VIEW y al menos uno de los módulos Inventario o Proveedores habilitado. Las sucursales y cotizaciones se consultan con el JWT y las RLS existentes. No requiere migración ni permisos nuevos.

El usuario selecciona una sucursal y pulsa Revisar cambios de precio. La consulta reutiliza la paginación existente de cotizaciones y su selección explícita de campos, que excluye pdf_base64. La revisión usa exactamente compareQuotations, la misma función de la pantalla de Cotizaciones: compara el precio por unidad sin impuestos contra el registro anterior del mismo proveedor/referencia/unidad/moneda. Los resultados muestran cotización, fecha, moneda, precio anterior, nuevo y variación; distinguen cotizaciones vencidas y referencias anteriores de precio cero.

Se informa que son cambios históricos y no necesariamente precios vigentes. Impuestos y transporte deben considerarse en la decisión de compra. No se generan automáticamente órdenes ni decisiones y no se descargan PDF. La primera cotización establece la referencia; sin cambios no equivale a haber evaluado condiciones comerciales o calidad.

Cambiar la sucursal borra el informe anterior y descarta respuestas tardías. Fallos de acceso o lectura retiran resultados previos. Las comprobaciones de acceso se repiten al solicitar la revisión. La consulta no empieza al abrir Orquestación ni al seleccionar el agente: requiere el botón explícito.

Validación con datos ficticios: catorce comprobaciones de navegador para demanda explícita, segregación de monedas/sucursales, cambio porcentual, ausencia de PDF, base inicial, respuestas tardías, fallos, escape HTML, móvil, permisos y ausencia de escrituras. CI Chromium/Firefox/WebKit y regresión compartida de cotizaciones.
