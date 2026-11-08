# Salidas de inventario · v0.63.0

La ruta existente `#sales` se presenta como Salidas de inventario. El formulario registra la entrega completa de una unidad liberada, con centro, sucursal, turno, médico, solicitud y observaciones. No solicita precio, factura ni cobro. El listado muestra cantidades y trazabilidad, incluidos registros históricos, sin exponer indicadores monetarios.

El cliente conserva la RPC transaccional `wf_create_blood_sale`: envía DESPACHADA, precio cero, cobrado cero y factura nula. El servidor deriva la cantidad y descripción desde la unidad, verifica permisos SALES_WRITE y DISPATCH_WRITE por sucursal, liberación y vencimiento en RD, y bloquea la unidad antes de despacharla. No requiere COLLECTIONS_WRITE si no existe pago. No hay migración ni cambios de permisos. La tabla histórica sigue compartida y conserva payment_status legado; esto no separa aún el modelo financiero ni elimina sus endpoints.

La pantalla consulta proyecciones explícitas sin importes. La selección excluye vencidas, sin vencimiento, sin cantidad válida o de otra sucursal; el servidor sigue siendo la autoridad. La cantidad no es editable. Se refresca inventario antes de abrir, se bloquea doble envío y se conserva el código al fallar. Ante respuesta de red incierta, comprobar el código antes de reintentar; no se introduce una promesa de idempotencia general.

Los permisos internos mantienen sus nombres por compatibilidad. Se exige SALES_WRITE y DISPATCH_WRITE para mostrar creación. La navegación conserva #sales y cambia su título. No se ocultan globalmente otros módulos financieros ni se eliminan datos históricos.

Abastecimiento aplica sucursal y estado tanto a tablas como a KPIs y donantes estimados. Las alertas usan severity, que en esta vista corresponde a ROJO/AMARILLO/VERDE.

Pruebas: reglas de payload y elegibilidad, navegador aislado con permisos, datos históricos, fallo y reintento, doble envío, vencimiento, sucursal, filtros y móvil; prueba PostgreSQL de entrega sin permiso de cobros, sin factura/pagos y con rechazo de segundo despacho. La integración CI incluye las pruebas nuevas. Los fixtures no sustituyen UAT con roles reales.

Pendiente: reservas y cancelaciones/devoluciones completas, conversión de empaques y recepción parcial de suministros, evolución del reporte por turno y separación del modelo legado. Este cambio no debe presentarse como implementación de esos flujos.
