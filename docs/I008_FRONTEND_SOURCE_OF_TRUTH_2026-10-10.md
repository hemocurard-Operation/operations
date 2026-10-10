# I-008 · Source of Truth del frontend

**Versión candidata:** 0.45.8 RC  
**Fecha:** 2026-10-10

## Objetivo

Eliminar la ambigüedad sobre qué archivos controlan realmente HemoCura Operations y evitar que nuevas iteraciones editen copias legacy por error.

## Cadena oficial de arranque

La fuente de verdad del runtime queda declarada así:

`index.html → js/app.js → hemocura-core/bootstrap.js → hemocura-core/layout.js`

A partir de `layout.js`, los módulos funcionales activos pertenecen a `hemocura-core/`.

## Directorios canónicos

- aplicación: `hemocura-core/`;
- entrypoint del navegador: `js/app.js`;
- configuración de entorno protegida: `js/config.js`;
- estilos activos: `css/`.

Los módulos `.js` históricos que permanecen en la raíz del repositorio se clasifican como:

**LEGACY_NOT_CANONICAL_DO_NOT_EDIT**.

Esto no autoriza su eliminación masiva. Cada retiro debe demostrar que el archivo no está referenciado y debe pasar los smoke tests correspondientes.

## Limpieza realizada

Se retiró `bi (1).js`, una copia accidental con nombre de duplicado que contenía una segunda implementación del módulo de BI en la raíz. El módulo activo continúa siendo `hemocura-core/bi.js` dentro de la cadena moderna de imports.

No se eliminaron otros módulos legacy en esta iteración.

## Nuevo gate

Se incorporan:

- `contracts/frontend-source-of-truth-v0.45.8.json`;
- `tools/frontend_source_truth_gate.py`;
- `.github/workflows/frontend-source-truth.yml`.

El gate verifica:

1. existencia de la cadena oficial de runtime;
2. que `index.html` continúe cargando `./js/app.js`;
3. que `js/app.js` continúe delegando a `hemocura-core/bootstrap.js`;
4. que el entrypoint no vuelva a cargar módulos JS legacy desde la raíz;
5. que no aparezcan nombres accidentales como `archivo (1).js`, `copy*.js` o `copia*.js`;
6. que los módulos de `hemocura-core` no importen módulos legacy de la raíz;
7. que `js/config.js` permanezca presente y no aparezca un `hemocura-core/config.js` competidor;
8. que el número de módulos sombra raíz ↔ `hemocura-core` no aumente por encima del baseline histórico.

## Estado de la deuda legacy

I-008 no declara resuelta toda la duplicación histórica. La convierte en deuda **visible, medible y congelada**: no puede crecer sin romper CI.

Las siguientes iteraciones podrán reducirla en lotes pequeños, comparando contenido/imports y ejecutando smoke tras cada retiro.

## Guardrails

- Sin cambios Supabase/DDL/RLS.
- Sin cambios clínicos.
- Sin cambios en `js/config.js`.
- Sin redirección del runtime.
- Sin eliminación masiva de legacy.

## Próxima iteración

**I-009 · Reducción controlada de módulos legacy raíz.**

Agrupar duplicados por identidad SHA/semántica, retirar primero copias idénticas y sin referencias, y mantener rollback simple por PR.