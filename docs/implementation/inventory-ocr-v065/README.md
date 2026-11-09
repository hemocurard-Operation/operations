# Lector de inventario por celdas · v0.65.0

La lectura de página completa pierde la posición de los números en tablas, especialmente cuando una foto incluye varios formularios. Esta versión añade Leer cuadro de inventario al selector de fotografías del Reporte Operativo Diario. No cambia el esquema, permisos, guardado de evidencia ni movimientos de inventario.

## Uso

1. Oriente la foto y pulse Leer cuadro de inventario.
2. Seleccione las cuatro esquinas del bloque **numérico**: desde la fila A+ hasta AB-, sin títulos ni columna Grupo. Orden: superior izquierda, superior derecha, inferior derecha e inferior izquierda. También puede introducir coordenadas porcentuales mediante teclado.
3. Compruebe las ocho filas y ajuste Separación de columnas hasta que la línea coincida con la división entre Sangre total y Paquete globular. Puede ampliar la imagen al 200%/300%.
4. Elija detección automática de tinta, tinta azul o contraste oscuro y pulse Detectar contenido.
5. Compare cada propuesta con la foto y con su recorte procesado. Complete las celdas dudosas manualmente. En este modo la fecha queda pendiente de comprobación porque no forma parte del recorte. Aplique solo después de revisar.

## Motor

La selección se rectifica mediante una homografía, se normaliza a dos columnas y ocho filas y se procesa por celda. Así se conserva la columna incluso si solo hay una cantidad en una fila. Se reduce la resolución de trabajo a un máximo de 2000 píxeles por lado; el archivo original y su hash no se cambian.

En modo automático se usa tinta azul cuando hay suficiente señal azul dentro del cuadro. La alternativa de contraste oscuro permite texto negro o impreso. Se eliminan márgenes, líneas largas y pequeños componentes de ruido; se centra y amplía el trazo restante. Una celda sin tinta legible queda sin propuesta, nunca cero. Un cuadro vacío evita inicializar el motor OCR.

El mismo motor Tesseract local lee dos veces cada celda no vacía, con segmentaciones 8 y 13 y alfabeto numérico. Solo se propone un entero si ambas lecturas coinciden y ambas tienen confianza interna de al menos 55. Esta confianza no es una probabilidad calibrada ni garantiza exactitud. El desacuerdo y las lecturas débiles se dejan pendientes. No se corrigen letras a números ni se completa un valor faltante.

La lectura de página completa se mantiene para texto y fecha. Si encuentra más de un encabezado de Unidades disponibles no propone inventario de esa página, para evitar mezclar formularios. La selección manual del cuadro correcto y la revisión humana siguen siendo necesarias; seleccionar títulos o filas equivocadas puede asignar números a un grupo incorrecto.

No hay llamadas a proveedores externos, modelos nuevos ni claves nuevas. Se reutilizan los archivos y licencias OCR ya alojados en el sitio. El lector de cédulas conserva su interfaz y sus reglas. Rotar o cambiar la selección invalida la interpretación anterior. Cancelar termina el trabajo y no debe alterar un diálogo abierto después.

## Validación y límites

Pruebas puras: selección convexa, transformación de cuatro esquinas, abstención con varios formularios, celdas vacías/líneas negras, desacuerdo/confianza baja y cero explícito.

Prueba de OCR real: hoja sintética con números azules impresos en cursiva, inclinación, un cuadro vecino con 999 y otro formulario vacío. Recupera cinco valores conocidos, conserva once celdas sin cantidades y no incorpora la anotación vecina. Es una prueba sintética; no demuestra precisión sobre la fotografía manuscrita del usuario.

Pruebas de interfaz: selección mediante teclado, separación de columnas, reinicio al rotar, visualización móvil y conservación del guardado/reintento y de los permisos existentes. Se mantiene la regresión del lector de cédulas. CI ejecuta el OCR real local.

La escritura manuscrita, sombras, desenfoque, tachaduras o una mala selección pueden seguir impidiendo la lectura. No hay guardado automático de cantidades ni liberación clínica. Revertir esta versión restaura la interfaz anterior sin borrar las fotografías privadas ya guardadas.
