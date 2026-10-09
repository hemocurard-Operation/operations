# C15-A · Captura simplificada de datos

## Estado

**DISEÑADO: PASS**  
**GENERADO: PASS**  
**VALIDADO EN CI: PASS**  
**INSTALADO EN PRODUCCIÓN: NO**

La rama `feat/c15a-simplified-form-capture` superó los cuatro gates ejecutados sobre el candidato: HemoCura Runtime Contract Gate, HemoCura Frontend Browser Smoke, HemoCura Frontend RPC Cutover y HemoCura Remediation Sequencer. La validación confirma integridad del frontend y sus contratos estáticos; no sustituye una prueba de escritura real con cada rol contra Supabase.

Esta iteración usa como referencia los dos libros entregados por HemoCura y, para los formularios, los esquemas de respuesta presentes en `Hemocura_Hoja_Central_Hibrido.xlsx`. Los cinco enlaces `forms.gle` no pudieron ser leídos directamente desde el entorno de revisión, por lo que no se atribuye un enlace concreto a un formulario sin evidencia.

## Hallazgos del material suministrado

### Hoja central híbrida

El libro declara que la operación diaria entra por Google Forms en hojas `Resp_*` y por AppSheet para inventario/requerimientos. Las estructuras observadas incluyen:

- `Resp_Donantes`: fecha, sucursal, presentados, diferidos, donaciones efectivas y observaciones.
- `Resp_Tamizaje`: fecha, sucursal y cantidades montadas por prueba, además de totales de donantes.
- `Resp_Despachos`: fecha, turno, cantidades por componente, observaciones y sucursal.
- `Reporte Incidencias`: fecha/hora, sucursal, reportante, clasificación, proceso, severidad, descripción, afectación, acción inmediata, evidencia y seguimiento de Calidad.
- `Requerimientos` / `Inventario`: patrón horizontal repetido de “ítem + cantidad” hasta 10 veces.

El patrón de hasta 10 ítems produce tablas muy anchas y encabezados repetidos. `Requerimientos` llega hasta la columna BA y mezcla varias columnas llamadas `Cantidad`. Esto dificulta validar, filtrar y escalar la captura.

Se detectaron además señales de calidad de datos que justifican simplificar formularios: un valor de despacho no numérico (`O`) en una columna de cantidad, un `#REF!` del Dashboard por referencia a `Requerimientos1`, varios `#VALUE!` en `Inventario1` y un `#DIV/0!` en `Calculo Precios` cuando falta la cantidad de presentación.

### Libro de cálculo de precios

El modelo de precios ya tiene una arquitectura razonable: catálogo de insumos, costo por unidad de consumo, recetas, mano de obra, indirectos y precios. Su mayor oportunidad de simplificación está en **capturar cambios de precio/proveedor/presentación mediante un formulario administrativo**, en vez de editar directamente múltiples columnas. Ese subflujo queda propuesto para C15-B; no se modifica todavía el motor de precios.

## Principio de diseño C15-A

La regla es **“capturar una vez el contexto y repetir solo la línea variable”**:

1. Fecha, sucursal, turno, responsable o área se precargan o recuerdan localmente.
2. Los detalles poco frecuentes se ocultan en secciones desplegables.
3. Los formularios de múltiples ítems usan líneas dinámicas (+ Agregar) y no columnas fijas del 1.º al 10.º.
4. Se ofrecen acciones `Guardar y agregar otro` / `Guardar y siguiente prueba` cuando el trabajo es secuencial.
5. No se autocompletan decisiones clínicas ni resultados analíticos.

## Cambios implementados en la rama

### Donantes

- Datos esenciales primero: código, fecha, sucursal, tipo, revisión humana y donación efectiva.
- ABO/Rh, diferimiento y observaciones quedan en un bloque complementario desplegable.
- Recuerda sucursal y tipo usados recientemente.
- `Guardar y agregar otro` evita reescribir contexto en jornadas de alto volumen.
- Se mantiene la revisión humana; no hay elegibilidad automática.

### Tamizaje

- `Guardar y siguiente prueba` conserva fecha, sucursal, unidad, reactivo, lote, vencimiento y responsable.
- **No conserva ni copia el resultado de la prueba**.
- Recuerda sucursal y responsable para reducir tecleo repetitivo.

### Requisiciones

- Se elimina del frontend el concepto de “primer insumo” único.
- Una requisición acepta tantas líneas como sean necesarias con `+ Agregar insumo`.
- Encabezado (fecha/sucursal/área/prioridad) se captura una sola vez.
- Las líneas se normalizan para `requisition_lines`, evitando el diseño de 10 pares de columnas.

### Incidencias

- Se incorpora `Nueva incidencia` en SGC.
- Fecha, hora y sucursal se precargan.
- Clasificación, proceso y severidad son selecciones simples.
- El detalle de afectación solo se habilita si el usuario marca que hubo afectación.
- `Requiere seguimiento por Calidad` es una decisión explícita del usuario; no se deriva automáticamente de severidad.

### Despachos

- Se incorpora `Nuevo despacho` con encabezado único y líneas dinámicas por producto.
- El usuario selecciona producto + unidades y puede agregar tantas líneas como necesite.
- El despacho se guarda inicialmente como `BORRADOR`.
- No se precargan cantidades, compatibilidades, selección FEFO ni liberación clínica.

## Impacto esperado

La iteración reduce repetición de fecha/sucursal/turno, elimina columnas fijas por posición de ítem y aproxima la captura al flujo real: **encabezado + líneas**. Esto también hace más sencillo migrar gradualmente desde Google Forms/AppSheet hacia la Suite sin perder la trazabilidad histórica de las hojas existentes.

## Gate antes de producción

Antes del merge a `main` deben ejecutarse pruebas reales de escritura con los roles autorizados para confirmar políticas RLS y permisos de Supabase en cinco flujos: donante secuencial, tamizaje secuencial, requisición multilínea, incidencia y despacho BORRADOR con líneas. Hasta completar ese gate, C15-A permanece **VALIDADO EN CI / NO INSTALADO EN PRODUCCIÓN**.

## Fuera de alcance

- No se eliminaron ni editaron los Google Forms actuales.
- No se importaron automáticamente respuestas históricas.
- No se modificó `js/config.js`.
- No se activaron decisiones clínicas automáticas.
- No se cambió el modelo de cálculo de precios.

## Próxima iteración recomendada · C15-B

Crear un **Formulario de Actualización de Costos y Catálogo** para el libro de precios: artículo, proveedor, presentación, unidades por presentación, precio, fecha de cotización y vigencia. El sistema calcularía costo unitario y validaría cantidades faltantes antes de permitir el cambio, evitando `#DIV/0!` y edición manual de celdas sensibles.
