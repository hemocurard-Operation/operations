# HemoCura v0.45.4 · Ergonomía de formularios y consistencia de captura

## Objetivo
Reducir clics, errores de captura y campos innecesarios sin convertir el frontend en un motor de decisión clínica. Esta iteración profundiza el rediseño iniciado en v0.45.3 a partir de `Hemocura_Hoja_Central_Hibrido.xlsx`, `Hemocura_Calculo_Precios_Banco_Sangre.xlsx`, las hojas históricas de respuestas y los cinco enlaces de Google Forms suministrados.

## Principio de diseño
La captura se divide en dos categorías:

1. **Captura simple / repetitiva**: contexto reutilizable, un formulario visible a la vez, listas, líneas dinámicas y detalles opcionales plegables.
2. **Transacciones críticas**: continúan sujetas a controles de Supabase/Web App; el frontend no confirma disponibilidad clínica, compatibilidad, elegibilidad ni liberación.

Los enlaces cortos `forms.gle` se conservan como contingencia histórica. Como no fue posible asociar cada URL con certeza a un proceso desde su metadata pública, no se inventa esa correspondencia.

## Hallazgos de los archivos suministrados
- `Resp_Donantes` repite fecha/sucursal y captura totales agregados separados de la ficha individual.
- `Resp_Tamizaje` usa una matriz ancha con una columna fija por prueba y repite totales diarios.
- `Resp_Despachos` usa una columna por componente, generando muchos ceros y poca flexibilidad.
- `Reporte Incidencias` contiene 14 campos aunque muchos eventos sólo requieren datos esenciales al inicio.
- `Requerimientos` llega a 53 columnas por repetir hasta 15 pares Ítem/Cantidad.
- `Inventario1` tiene una estructura muy ancha (89 columnas), más difícil de mantener que un modelo por filas.
- El libro de precios ya es relativamente normalizado; allí la mejora debe concentrarse en entrada de parámetros faltantes, no en reescribir fórmulas financieras.

## Mejoras v0.45.4
### 1. Donantes: consistencia visible e inmediata
Cuando el estado cambia a `DIFERIDO`:
- la casilla de donación efectiva se desmarca;
- la casilla queda deshabilitada mientras permanezca diferido;
- el motivo de diferimiento se vuelve obligatorio;
- el bloque de datos opcionales se abre automáticamente.

Además existe un guard de submit que bloquea la combinación `DIFERIDO + donación efectiva` antes de enviar datos. Esta regla ya estaba presente en la arquitectura Google Forms v2.2.0 y ahora queda reflejada también en la captura rápida.

### 2. Sucursal: un clic menos cuando no existe ambigüedad
Si el usuario sólo tiene una sucursal disponible y todavía no hay una seleccionada, la captura rápida la preselecciona y reutiliza el contexto. Si existen varias sucursales, el sistema sigue exigiendo selección explícita.

### 3. Incidencias: detalle progresivo
El formulario conserva sólo clasificación, proceso, severidad y descripción como núcleo visible. El bloque de detalle se abre automáticamente cuando:
- se marca afectación a paciente/donante;
- se solicita seguimiento de Calidad; o
- la severidad es 4 o 5.

No se inventa contenido ni se autocompletan acciones; únicamente se muestra el lugar correcto para documentarlas.

### 4. Navegación y móvil
Al elegir Donante, Tamizaje, Requisición, Despacho o Incidencia:
- sólo queda abierto el formulario seleccionado;
- el sistema recuerda la última opción usada;
- se hace foco en el primer campo editable para acelerar teclado/móvil;
- el formulario inicial continúa priorizándose por rol.

### 5. Tamizaje permanece explícito
No se guarda ni infiere ningún resultado clínico en la capa de navegación. Cada prueba debe seleccionarse y cada resultado debe elegirse de forma explícita en el formulario de tamizaje.

## Flujo recomendado de captura
`Seleccionar proceso → reutilizar Fecha/Sucursal/Turno → completar esenciales → abrir detalles sólo si aplica → validar consistencia → guardar → preparar siguiente registro`.

## Guardrails
- Sin elegibilidad automática de donantes.
- Sin resultado de tamizaje precargado o inferido.
- Sin compatibilidad transfusional automática.
- Sin liberación automática de componentes.
- Los despachos rápidos continúan creándose sólo como `BORRADOR`.
- `js/config.js` no se modifica.
- No se incorpora `service_role` al frontend.

## Validación requerida
La iteración sólo puede fusionarse si pasan:
- HemoCura Quick Capture Safety, incluyendo los nuevos guards de v0.45.4.
- Frontend Browser Smoke.
- Runtime Contract Gate cuando sea disparado por el cambio.
- GitHub Pages build/deployment posterior al merge.

## Supabase
No se requiere DDL ni modificación de RLS para esta iteración. El alcance es de ergonomía y validación de interfaz sobre contratos backend ya existentes.
