# CRM comercial de Hemocura

Se añade una sección CRM a Gestión comercial, conservando la agenda, oportunidades y planificación existentes. El asistente comercial y los demás roles comerciales operan únicamente en sus sucursales autorizadas, con cuenta activa.

## Ficha
Prospecto, referidor o centro: nombre, teléfono, correo, WhatsApp, centro, especialidad, ciudad, dirección, etapa, servicios de interés, objetivo asociado al catálogo, preferencias y próximo seguimiento. Correo y teléfono compartidos no fusionan personas automáticamente. NO_CONTACTAR desactiva accesos de llamada/correo/WhatsApp; no se envían mensajes automáticamente.

Cada visita, llamada, comunicación o nota conserva fecha, resultado, servicio, seguimiento y responsable. Las actividades y la bitácora no se sobrescriben desde el navegador. Los registros se archivan mediante la etapa, sin borrar su historia.

Una ficha de referidor enlaza una identidad de medical_referrers. Para referidores de la misma sucursal, el RPC controlado sincroniza nombre y contacto; para un referidor corporativo conserva el directorio corporativo y complementa su ficha local. Los clientes existentes pueden vincularse explícitamente solo si tienen ubicación, visita comercial o ficha CRM en la sucursal autorizada; tanto el catálogo como el guardado validan ese vínculo. importar prospectos no crea facturas, demandas clínicas ni clientes automáticamente.

## Importación
Excel .xlsx y CSV UTF-8/Windows-1252, hasta cinco archivos, cinco MB por archivo, 500 registros y 50 columnas por carga. Excel se lee en un worker con ExcelJS 4.4.0 local, archivo fijado y huella/integridad npm en vendor/exceljs/SOURCE.json. Se limita el contenido ZIP descomprimido a 25 MB y el tiempo de lectura; no se ejecutan macros o fórmulas. No se envía el archivo original a terceros ni se almacena públicamente.

Descargar plantilla → cargar → corregir comparando original/edición → revisar errores y posibles duplicados → decidir crear, actualizar, vincular referidor o excluir → aprobar → confirmar. Las filas con errores pueden excluirse. Las celdas vacías no borran campos al actualizar. Una coincidencia puede mantenerse como persona distinta con justificación. La validación se repite bajo bloqueo de sucursal al confirmar: cualquier error revierte el lote completo, incluidos los referidores creados. Claves de solicitud impiden dobles guardados por reintentos.

Los borradores de carga y ficha se guardan en IndexedDB de este navegador, separados por usuario y sucursal y recuperados solo tras validar acceso. Se eliminan tras confirmación o descarte explícito. No están disponibles en otros dispositivos ni respaldados en el servidor; se informa si el navegador no permite persistir. Una edición obsoleta no sobrescribe la ficha.

## Seguridad y activación
Migración aditiva commercial_crm_contacts: tablas CRM, RLS, sin lectura anónima ni mutaciones directas del navegador. Funciones expuestas SECURITY INVOKER y aplicación privilegiada privada con comprobación de actor/permisos/sucursal. Contactos y actividades no contienen pacientes. Solo el Super Usuario amplía el catálogo de servicios comerciales, que no altera tarifas ni habilitación clínica. Las auditorías generales conservan identificadores; el detalle de contacto queda en la bitácora CRM de la sucursal.

commercial_crm se instala apagado. Desplegar migración, luego frontend/dependencia y habilitar LIVE_LIMITED. Apagar la bandera detiene escrituras y oculta la sección, conservando registros e historia. Los módulos comerciales previos permanecen disponibles. No se importan datos reales como parte del despliegue.

## Validación
525 comprobaciones PostgreSQL sobre 95 archivos, 17 comprobaciones de navegador CRM (Excel y CSV juntos, corrección, originales, exclusiones, duplicados, borradores, reintentos y móvil), pruebas de parseo CSV y regresión de las pantallas previas. Son pruebas aisladas con datos ficticios, sin aprobación clínica.
