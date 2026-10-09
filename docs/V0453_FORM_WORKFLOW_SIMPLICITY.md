# HemoCura v0.45.3 · Flujo de formularios simple + normalización de libros legados

## Objetivo
Reducir el esfuerzo de carga sin debilitar los controles clínicos ni sustituir la revisión humana. Esta iteración parte de los dos libros suministrados, de las hojas de respuestas históricas y de los cinco enlaces `forms.gle` proporcionados.

## Fuentes evaluadas
- `Hemocura_Hoja_Central_Hibrido.xlsx`.
- `Hemocura_Calculo_Precios_Banco_Sangre.xlsx`.
- Cinco enlaces históricos de Google Forms suministrados por el usuario.

Los enlaces cortos `forms.gle` no exponen en el entorno de revisión metadata suficiente para asociar con certeza cada URL a un proceso. Por ello no se inventa esa relación; el rediseño se fundamenta en las hojas `Resp_Donantes`, `Resp_Tamizaje`, `Resp_Despachos`, `Reporte Incidencias` y `Requerimientos` del libro central.

## Hallazgos de carga
| Flujo | Estructura heredada observada | Problema | Diseño simplificado |
|---|---|---|---|
| Donantes | 7 columnas de respuesta agregada | Fecha/sucursal repetidas y captura separada de la ficha individual | Contexto común + captura mínima + opcionales plegables |
| Tamizaje | 14 columnas, con pruebas fijas y totales de donantes repetidos | Matriz ancha y duplicación de datos | Unidad + panel de pruebas seleccionables; resultado explícito |
| Despachos | 11 columnas, con una columna por componente | Muchos ceros y estructura rígida | Líneas dinámicas producto/cantidad; creación en BORRADOR |
| Incidencias | 14 campos | Sobrecarga para eventos simples | Esenciales primero + detalle adicional plegable |
| Requerimientos | 53 columnas y hasta 15 pares Ítem/Cantidad | Difícil de completar, mantener y analizar | Cabecera + N líneas normalizadas |
| Inventario inicial | 89 columnas | Un artículo por columna; mezcla de texto y cantidad | Una fila por artículo/sucursal/lote |

## Mejora frontend v0.45.3
La ruta `Captura rápida` conserva los controles seguros de v0.45.2 y añade una capa de navegación de un solo formulario a la vez.

- Selector inicial: Donante, Tamizaje, Requisición, Despacho o Incidencia.
- Sólo un formulario operativo permanece expandido a la vez.
- El último formulario utilizado se recuerda localmente en el navegador.
- En la primera entrada se prioriza un panel por rol operativo: laboratorio → tamizaje; asistente de operaciones → requisición; médico/gerente técnico o calidad → incidencia.
- El contexto Fecha/Sucursal/Turno sigue compartido entre formularios.
- No se recuerdan ni se infieren resultados de tamizaje.
- No se automatiza elegibilidad del donante, compatibilidad transfusional ni liberación de componentes.

## Libros resultantes
### Libro central
Se genera una copia de trabajo con nuevas hojas:
- `Captura_Simple`: mapa de procesos y principios de captura.
- `Req_Simple`: una fila por artículo solicitado, con listas desplegables.
- `Inv_Inicial_Simple`: una fila por artículo/sucursal/lote.
- `Mapa_Formularios`: trazabilidad entre estructura heredada y estructura simplificada.
- `Calidad_Datos`: hallazgos de calidad de datos legados.

En esa copia se corrige únicamente el KPI roto `Dashboard!B12`, que apuntaba a la hoja inexistente `Requerimientos1`; ahora cuenta estados `SOLICITADO` y `PENDIENTE` de `Req_Simple`.

No se alteran automáticamente los errores heredados de `Inventario1` ni la lógica financiera de `Calculo Precios`, porque requieren saneamiento/validación específica y no deben ocultarse mediante fórmulas defensivas sin aprobación.

### Libro de cálculo de precios
El modelo ya presenta una estructura más normalizada. Se añade una hoja `Carga_Simple` que separa claramente entradas de salidas y muestra indicadores de completitud:
- Insumos pendientes de precio.
- Roles con salario faltante o cero.
- Rubros indirectos sin monto.
- Unidades vendibles proyectadas por mes.

No se modifica ninguna fórmula financiera del libro de precios.

## Guardrails conservados
1. Tamizaje: ninguna prueba ni resultado se asume automáticamente.
2. Donantes: revisión clínica humana; estado inicial seguro.
3. Despachos: la captura rápida crea sólo BORRADOR.
4. Requisiciones/despachos: no se permiten líneas duplicadas dentro del mismo formulario.
5. `js/config.js` permanece protegido y sin cambios.
6. El frontend no incorpora `service_role`.

## Criterio de validación
La iteración se considera lista para merge sólo si pasan:
- HemoCura Quick Capture Safety.
- Runtime Contract Gate.
- Frontend Browser Smoke.
- Integridad de rutas/mounts.

Supabase DDL: **NO APLICA** para esta iteración; se reutilizan contratos y RLS existentes.
