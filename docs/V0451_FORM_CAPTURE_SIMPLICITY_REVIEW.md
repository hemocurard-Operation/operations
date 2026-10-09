# HemoCura v0.45.1 · Simplificación de captura por formularios

## Objetivo
Reducir fricción, escritura repetitiva y errores de transcripción en la carga diaria, reutilizando el modelo de datos ya existente y manteniendo los controles clínicos y de seguridad.

## Material revisado
- `Hemocura_Hoja_Central_Hibrido.xlsx`.
- `Hemocura_Calculo_Precios_Banco_Sangre.xlsx`.
- Cinco enlaces `forms.gle` suministrados para los formularios históricos.
- Frontend HemoCura v0.45.0 y contratos de datos existentes en GitHub/Supabase.

Los enlaces cortos de Google Forms no expusieron en el entorno de revisión metadata suficiente para identificar con certeza el proceso correspondiente a cada URL. Se conservan como contingencia con etiquetas neutrales; no se inventó una asociación.

## Hallazgos de usabilidad

| Flujo heredado | Forma observada | Problema de uso | Diseño v0.45.1 |
|---|---|---|---|
| Donantes | Registro diario agregado con fecha/sucursal/presentados/diferidos/efectivos | Poca granularidad y repetición de contexto | Captura mínima por donante + detalle opcional + contexto persistente |
| Tamizaje | Una columna por prueba: HIV, HTLV, CORE, Hep B, Hep C, Sífilis, etc. | Repetición y formulario horizontal | Una unidad + tabla de pruebas seleccionables + un solo envío |
| Despachos | Una columna fija por componente | Se vuelve rígido al agregar productos | Líneas dinámicas producto/cantidad |
| Inventario | Pares Artículo/Cantidad repetidos hasta 10 veces | Muchos campos vacíos y desplazamiento horizontal | Catálogo/autocompletar + líneas dinámicas |
| Requerimientos | Pares Artículo/Cantidad repetidos hasta 15 veces; hoja muy ancha | Alta fricción y riesgo de error | Encabezado único + N líneas, siguiendo el patrón normalizado de `Req_Lineas` |
| Incidencias | Formulario amplio de aproximadamente 14 datos | Demasiado detalle visible desde el inicio | 6 datos esenciales + detalle adicional plegable |
| Catálogos/precios | Artículos, categorías, unidades y parámetros centrales | Riesgo de volver a escribir nombres | `select`/`datalist` alimentados por catálogo de productos |

## Cambio funcional
Se crea `Captura rápida` como primera opción del grupo **TRABAJO DIARIO**. La pantalla comparte `Fecha`, `Sucursal` y `Turno` entre formularios y guarda ese contexto localmente en la estación de trabajo.

Incluye cinco formularios progresivos:
1. Donante.
2. Tamizaje por unidad con carga en lote.
3. Requisición con líneas dinámicas.
4. Despacho con líneas dinámicas y guardado exclusivamente en `BORRADOR`.
5. Incidencia breve con detalle adicional opcional.

## Principios de diseño
- Campos esenciales primero.
- Campos opcionales dentro de secciones plegables.
- Contexto compartido para evitar reingreso.
- Catálogos antes que texto libre.
- Líneas dinámicas en lugar de columnas repetidas.
- Mensaje de resultado visible después de guardar.
- Formularios históricos disponibles como contingencia durante transición.

## Guardrails clínicos
- El sistema no determina elegibilidad de donantes.
- El sistema no determina compatibilidad transfusional.
- Captura rápida no libera componentes sanguíneos.
- Despachos creados desde Captura rápida permanecen `BORRADOR`.
- La revisión clínica y liberación siguen requiriendo intervención humana autorizada.

## Archivos v0.45.1
- `hemocura-core/quick-capture.js`
- `hemocura-core/quick-capture-data.js`
- `hemocura-core/blood-operations-data.js`
- `hemocura-core/router.js`
- `hemocura-core/views.js`
- `hemocura-core/access-control.js`
- `hemocura-core/layout.js`
- `VERSION.json`

`js/config.js` permanece protegido y no se modifica.

## Estado
- DISEÑADO: PASS
- GENERADO EN RAMA: PASS
- ESQUEMA SUPABASE NUEVO: NO REQUERIDO
- CI / BROWSER SMOKE: PENDIENTE HASTA PR
- PRODUCCIÓN: SIN CAMBIOS HASTA MERGE + DEPLOY PASS
