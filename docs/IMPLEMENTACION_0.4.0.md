# Implementación HemoCura v0.4.0

## Antes
La v0.3.0 debe:
- autenticar;
- mostrar layout;
- navegar correctamente.

## Archivos NUEVOS
- `hemocura-core/data.js`
- `hemocura-core/dashboard.js`

## Archivos MODIFICADOS
- `hemocura-core/views.js`
- `hemocura-core/layout.js`
- `css/app.css`
- `VERSION.json`
- `README.md`

## Importante
Conserve su `js/config.js` funcional de v0.3.0. No es necesario reemplazarlo.

## GitHub.com
Puede subir solo los archivos del paquete PATCH:
1. Abra el repositorio.
2. `Add file → Upload files`.
3. Arrastre manteniendo las rutas.
4. Commit: `HemoCura v0.4.0 Dashboard Supabase`.

## Resultado esperado
Dashboard muestra por sucursal:
- unidades vendidas;
- unidades despachadas;
- ingresos;
- costo;
- margen;
- incidencias;
- alertas abiertas;
- alertas críticas.

Además muestra alertas de gestión abiertas.

## Si el Dashboard muestra cero
Puede ser correcto si hoy no hay actividad.

## Si dice "permission denied"
Revisar RLS/grants de las vistas.

## Si dice "relation does not exist"
La base no tiene instalada la vista correspondiente.
