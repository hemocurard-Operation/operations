# Propuestas de encuadre de inventario · v0.66.0

Añade Buscar cuadros de inventario a la carga fotográfica del Reporte Operativo Diario. Permite elegir una propuesta para evitar introducir siempre las cuatro esquinas a mano. La búsqueda no lee celdas de cantidades, no las aplica al borrador y no guarda fotografías. El OCR de encabezados puede reconocer texto de toda la página localmente; ese texto no se envía ni se guarda.

## Uso

Seleccione y oriente la foto, pulse Buscar cuadros de inventario y elija una de las propuestas. Compruebe la cuadrícula superpuesta: A+ debe iniciar la primera fila y AB- terminar la octava; solo las dos columnas numéricas deben quedar dentro. Ajuste esquinas/separación de columnas si hace falta y pulse Detectar contenido. Revise las cantidades y la fecha antes de aplicar al borrador y guardar.

Si se detectan varios formularios, se muestran hasta seis opciones con vista previa. Ninguna queda seleccionada por defecto. La búsqueda no sustituye el encuadre existente hasta elegir una opción. Si no encuentra una estructura clara, conserva la selección previa y permite marcar esquinas manualmente. Rotar o cambiar la foto descarta las propuestas anteriores. Cancelar no debe modificar un diálogo abierto después.

## Detección

Se reutiliza el OCR español local para localizar el encabezado impreso UNIDADES DISPONIBLES y referencias de grupo. Se analiza una copia de trabajo de hasta 1200 píxeles por lado; el archivo original no cambia.

El detector busca nueve límites aproximadamente equidistantes para ocho filas y cuatro separadores verticales para Grupo/Sangre total/Paquete globular. Excluye la columna Grupo y estima la separación numérica. Comprueba A+ en la primera fila y AB+ o AB- en su fila esperada para evitar incluir encabezados como datos. Se requieren al menos siete de nueve bordes horizontales amplios; esto permite un borde parcialmente tapado sin inventar filas ausentes. Sigue comprobando geometría, separadores y referencias impresas.

Las propuestas son encuadres probables y pueden estar equivocadas. Las referencias OCR poco legibles, ausencia del borde final, recortes, pliegues, sombras o inclinación pronunciada pueden causar abstención. La selección manual y la revisión humana se conservan. La búsqueda no identifica automáticamente la sucursal ni la fecha y no demuestra exactitud clínica ni de cantidades.

No hay proveedores externos, modelos nuevos, migraciones, permisos nuevos ni cambios al respaldo privado. Los objetos devueltos contienen coordenadas y división de columnas, sin cantidades. El OCR por celdas y su consenso de dos lecturas mantienen las reglas de v0.65.0. No se registra inventario, despacho, liberación ni operación financiera desde el detector.

## Validación

Pruebas puras cubren encabezados incompletos, exclusión de títulos/Grupo, abstención ante una fila final cortada o referencias ausentes, cancelación y borde parcialmente oculto.

El OCR real se ejecuta sobre una hoja sintética con dos formularios impresos, uno inclinado. Comprueba ambas propuestas, primera fila, exclusión de Grupo, separación de columnas, ausencia de cantidades en el resultado y ausencia de llamadas externas. La precisión sobre las fotografías manuscritas del usuario no se ha medido.

Las pruebas de interfaz cubren elección explícita entre dos propuestas, ausencia de escritura o lectura de cantidades durante la búsqueda, conservación de selección cuando no hay resultado, invalidación al rotar y cancelación sin interferir con la imagen archivada. Se conserva la regresión del lector por celdas, móvil y guardado de evidencia. CI ejecuta el detector real local.

Reversión: revertir la interfaz a v0.65.0. No hay cambios de esquema ni fotografías que eliminar.
