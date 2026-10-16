# Donantes: ficha primero y lista debajo

La ficha aparece inmediatamente después de la búsqueda. Anterior y Siguiente recorren todo el resultado filtrado en el mismo orden de la lista, conservando la posición de la ficha. El contador muestra la posición real y los extremos deshabilitan el botón correspondiente.

La búsqueda por nombre, cédula y código se combina con sucursal y grupo sanguíneo. Las cédulas aceptan separadores. Un nombre con números se busca como texto, evitando que sus números amplíen accidentalmente el resultado por cédula. Si un filtro excluye al donante actual se abre el primer resultado válido; si no hay coincidencias se vacía la ficha.

El directorio muestra inicialmente 25 registros y Cargar más añade el siguiente bloque sin quitar los anteriores. La navegación de ficha atraviesa los límites de esos bloques y amplía la lista cuando hace falta para mostrar el registro seleccionado. La fila actual queda resaltada. La lectura paginada del SDK continúa recuperando todos los registros autorizados; no se limita el resultado a la primera página del servidor.

Se muestran seis datos principales: cédula, sexo, grupo, teléfono, última donación y próxima fecha de referencia. Otros datos, historial, comentarios y seguimiento se despliegan cuando se necesitan. Los diferimientos permanecen visibles en la ficha compacta. Contacto y citas tienen acciones directas. La agenda general y las comunicaciones quedan después del directorio.

La interfaz solicita descartar cambios si hay notas o una visita sin guardar. Durante un guardado bloquea los cambios de selección. Las respuestas de historial que llegan tarde no reemplazan la ficha de otro donante. Los paneles desplegados se conservan al guardar en la misma ficha.

No hay migraciones ni cambios en roles, datos clínicos, cálculo de 84 días o base de donantes. Navegar y buscar no escribe registros.

## Verificación

- `node tools/donors_navigation_runner.cjs`: navegación a través del registro 25, límites, carga incremental, filtros, resultados vacíos, cambios sin guardar, respuestas tardías, bloqueo durante guardado, permisos de consulta y móvil.
- `node tools/donors_browser_runner.cjs`: regresiones de cédula, edición, laboratorio, contacto y agenda; se adaptan las acciones a los paneles desplegables.
- `node tools/coordination_browser_runner.cjs`: compatibilidad con comunicaciones y calendario.

Todas las pruebas de navegador usan el módulo real con un SDK local inyectado, datos ficticios y conexiones externas bloqueadas.
