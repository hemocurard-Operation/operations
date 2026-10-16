# Órdenes de compra y recepciones

En Proveedores se incorpora la gestión de pedidos a proveedores; los pedidos asistenciales de Ruta operativa siguen su propio flujo.

1. Seleccionar sucursal y registrar un proveedor (razón social, identificación fiscal, contacto, tipo y criticidad).
2. Crear un borrador con fecha requerida, moneda, condiciones de pago, dirección y artículos. Cada artículo conserva referencia, descripción, cantidad, unidad y precio. Lote y vencimiento se solicitan por defecto; pueden desactivarse expresamente para artículos a los que no aplican.
3. El responsable autorizado aprueba la orden. Desde entonces se conservan sus términos y la identificación del proveedor. El documento se imprime o se guarda como PDF con el diálogo del navegador. Marcar enviada registra la gestión y no envía correo automáticamente.
4. Registrar una entrega parcial o total. Una misma recepción admite múltiples artículos y lotes, factura/conduce, fecha de entrega, fecha real de registro, usuario receptor, precio recibido, cantidad recibida/aceptada/rechazada, lote, vencimiento, empaque, documentación, temperatura opcional y observaciones.
5. Las cantidades aceptadas reducen el saldo pendiente; las rechazadas conservan su historial y quedan pendientes de reposición. Solo el cumplimiento de todas las cantidades cierra la orden como RECIBIDA.

El historial no se edita ni se elimina desde el cliente. La API aplica cada recepción en una transacción, bloquea la orden, verifica su revisión y evita duplicados con un identificador de solicitud. Reutilizar ese identificador con contenido diferente se rechaza. Una recepción fallida no deja cabeceras ni cantidades parciales. Una orden con recepciones no puede cancelarse.

Los precios acordados y recibidos se guardan separadamente. El total de la orden suma importes por artículo redondeados a dos decimales; no añade impuestos ni cargos que no estén modelados. El valor de recepción mostrado corresponde a lo aceptado.

Este registro documenta compras y recepción física; **no contabiliza automáticamente existencias ni libera material para uso clínico**. La recepción no sustituye los controles de calidad ni los movimientos del inventario existente.

## Accesos

| Permiso | Roles predeterminados |
| --- | --- |
| Consultar compras | Super Usuario, Administrador, Gerencia Operativa, Gerencia General, Asistente de Operaciones, Inventario, Encargada de Laboratorio, Calidad, Finanzas |
| Preparar órdenes y proveedores | Super Usuario, Administrador, Gerencia Operativa, Asistente de Operaciones, Inventario |
| Aprobar, marcar enviada y cancelar | Super Usuario, Administrador, Gerencia Operativa, Gerencia General |
| Registrar recepción | Super Usuario, Administrador, Gerencia Operativa, Asistente de Operaciones, Inventario, Encargada de Laboratorio |

Se verifica además usuario activo y acceso a la sucursal. Se conserva la administración exclusiva de identidades del Super Usuario. No se añaden usuarios ni se cambian claves.

## Verificación

- `node tests/procurement/domain.test.mjs`
- `python tools/procurement_postgres_runner.py` (PostgreSQL desechable sin red)
- `node tools/procurement_browser_runner.cjs` (Chromium con datos sintéticos y tráfico remoto bloqueado)
- `python tools/workflow_postgres_runner.py --allow-external-prerequisite-fixture`

Las pruebas incluyen aislamiento entre sucursales, usuarios inactivos, permisos de lectura, bloqueo de escrituras directas, historial inmutable, precios separados, recepciones parciales, rechazos, productos vencidos, reintentos y dos entregas concurrentes que intentan aceptar la última unidad. Los informes no contienen datos reales de donantes o proveedores.
