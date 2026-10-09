# HemoCura v0.45.2 · Formularios simples con defaults seguros

## Objetivo
Reducir aún más la fricción de captura detectada al comparar `Hemocura_Hoja_Central_Hibrido.xlsx`, `Hemocura_Calculo_Precios_Banco_Sangre.xlsx`, los cinco enlaces históricos de Google Forms y la implementación v0.45.1, sin convertir la simplificación en decisiones clínicas automáticas.

## Hallazgo principal de la auditoría de v0.45.1
La pantalla `Captura rápida` resolvió buena parte de la repetición de los formularios heredados, pero el tamizaje tenía dos defaults que podían inducir una captura no deliberada: todas las pruebas iniciaban seleccionadas y el resultado iniciaba en `NO_REACTIVO`.

La v0.45.2 elimina ese patrón. Ningún resultado de tamizaje queda precargado y una prueba no se envía hasta que el usuario la selecciona y asigna un resultado explícito.

## Mejoras derivadas de los archivos revisados

| Problema observado | Mejora v0.45.2 |
|---|---|
| Tamizaje heredado con muchas columnas fijas | Panel por unidad con pruebas seleccionables |
| Riesgo de aceptar un resultado por defecto | Resultado vacío, deshabilitado hasta seleccionar la prueba y validación explícita antes de guardar |
| Fecha/sucursal/turno repetidos | Contexto compartido con guardado automático local |
| Reactivo, lote y responsable repetidos por unidad | Opción de recordar estos tres datos en la estación de trabajo; nunca se recuerdan resultados clínicos |
| Requerimientos con hasta 15 pares Artículo/Cantidad | Líneas dinámicas y control de artículos duplicados |
| Despachos con una columna fija por componente | Líneas dinámicas producto/unidades y rechazo de duplicados |
| Cantidades susceptibles a texto accidental | `input type=number`, mínimo y paso decimal |
| Incidencias extensas | Datos esenciales visibles y detalle adicional plegable |
| Captura consecutiva | Después de guardar se prepara el siguiente registro y se conserva el contexto operativo |

## Cambios funcionales

### Donantes
- El estado inicial visible es siempre `PENDIENTE`.
- Si el operador selecciona `DIFERIDO`, el motivo se vuelve obligatorio antes de guardar.
- Después de guardar se prepara un nuevo código y vuelve a `PENDIENTE`.
- El sistema no determina elegibilidad.

### Tamizaje
- Las pruebas empiezan sin seleccionar.
- Los resultados empiezan vacíos y deshabilitados.
- `Seleccionar panel` habilita las pruebas, pero no asigna resultados.
- El envío se bloquea si alguna prueba seleccionada no tiene resultado explícito.
- Puede recordarse reactivo/plataforma, lote y responsable para acelerar captura repetitiva.
- Después de guardar se limpia unidad y resultados; nunca se reutilizan resultados previos.

### Requisiciones
- Cada artículo aparece en una sola línea.
- Si el mismo artículo se repite, el formulario bloquea el envío y pide ajustar la cantidad en la línea existente.
- Se mantienen las líneas normalizadas del backend, evitando la estructura horizontal del formulario heredado.

### Despachos
- Cada producto aparece en una sola línea.
- Las cantidades son numéricas.
- El registro creado por Captura rápida permanece en `BORRADOR`.
- No confirma salida, no libera componentes y no determina compatibilidad transfusional.

### Incidencias
- Se mantiene el formulario progresivo: clasificación, proceso, severidad y descripción primero; afectación, acción y evidencia como detalle cuando corresponda.

## Formularios Google suministrados
Los cinco enlaces `forms.gle` continúan disponibles como contingencia. El entorno de revisión no expuso metadata suficiente para identificar con certeza qué URL corresponde a cada proceso. No se asignaron nombres inventados a esos enlaces.

## Calidad de los archivos de origen
Durante la revisión del libro central también se observaron errores heredados de hoja de cálculo (`#REF!`, `#DIV/0!` y algunos `#VALUE!`). No se trasladan esos errores al nuevo flujo. Deben tratarse en una iteración separada de saneamiento del modelo Excel, porque esta v0.45.2 se limita a seguridad y simplicidad de captura.

## Gate automático
Se incorpora `tools/test_quick_capture_safety.py` y el workflow `HemoCura Quick Capture Safety` para impedir regresiones en los siguientes puntos:
- versión esperada;
- resultado de tamizaje vacío por defecto;
- resultados deshabilitados hasta selección de la prueba;
- validación de resultado explícito;
- ausencia de checkboxes de pruebas marcados por defecto;
- donante en `PENDIENTE`;
- prevención de duplicados en requisiciones y despachos;
- despacho forzado a `BORRADOR`;
- copy de guardrail clínico;
- no modificación/referencia de `js/config.js` desde el módulo.

## Alcance técnico
Esta iteración no requiere nuevo DDL en Supabase. Reutiliza tablas, RLS y contratos existentes. `js/config.js` permanece protegido y sin cambios.

## Estado inicial
- DISEÑADO: PASS
- GENERADO EN RAMA: PASS
- TEST LOCAL DEL GATE: PASS 11/11
- CI GITHUB: PENDIENTE PR
- BROWSER SMOKE: PENDIENTE PR
- SUPABASE DDL: NO APLICA
- PRODUCCIÓN: SIN CAMBIOS HASTA MERGE + DEPLOY PASS
