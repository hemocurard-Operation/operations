# I-012 · Clasificación de módulos legacy divergentes en raíz

**Versión candidata:** 0.49.1 RC
**Fecha:** 2026-11-03
**Contrato de referencia:** `contracts/frontend-source-of-truth-v0.45.10.json` → `preserved_divergent_modules`

---

## Contexto

El contrato `frontend-source-of-truth-v0.45.10.json` marca 10 módulos de la raíz del repo como `preserved_divergent_modules`, con la regla:

> "Divergent legacy root modules are preserved until their unique behavior is explicitly classified or archived."

Este documento cumple ese requisito: clasifica el comportamiento de cada módulo divergente frente a su equivalente canónico en `hemocura-core/`, para habilitar su retiro formal en una iteración posterior.

## Metodología

Para cada par (`<archivo>.js` en raíz vs `hemocura-core/<archivo>.js`):

1. Se comparó el conjunto de símbolos exportados (`export function|const`).
2. Se comparó el conjunto de imports (dependencias declaradas).
3. Se inspeccionaron las diferencias de línea para detectar lógica exclusiva de la raíz.

## Resultado por módulo

| Módulo | Exports root-only | Exports core-only | Veredicto |
|---|---|---|---|
| `blood-operations-data.js` | ninguno | ninguno | SUPERSEDED — misma API pública, la raíz es una revisión anterior sin comportamiento exclusivo. |
| `command-data.js` | ninguno | ninguno | SUPERSEDED — igual API; core tiene más datos/branches. |
| `donors.js` | ninguno | ninguno | SUPERSEDED — mismo export `mountDonors`; la raíz es una UI más simple y antigua (27 vs 133 líneas), sin flujo ni validaciones exclusivas. |
| `layout.js` | ninguno | 17 rutas adicionales (`mountUsers`, `mountValueChain`, `mountServicePerformance`, `mountDonorOutreach`, `mountMedicalNetwork`, `mountCustomers`, `mountCollections`, `mountEconomics`, `mountIntegratedActions`, `mountTraining`, `mountMyWork`, `mountDecisionCenter`, `mountPredictive`, `mountOrchestration`, `mountQuickCapture`, `mountDailyInventory`, `mountSupplyTransfers`) | SUPERSEDED — `hemocura-core/layout.js` es un superconjunto estricto; la raíz es un snapshot anterior al que le faltan módulos agregados después. |
| `ops-dashboard.js` | ninguno | ninguno | SUPERSEDED — misma API; core amplía el dashboard con más KPIs. |
| `production.js` | ninguno | ninguno | SUPERSEDED — misma API, implementación más simple en raíz. |
| `release-data.js` | ninguno | ninguno | SUPERSEDED — diferencia mínima (3 líneas), sin comportamiento exclusivo. |
| `release-gate.js` | ninguno (función interna `fetchTextNoCache` renombrada a `checkFrontendFile` en core) | ninguno nuevo como export público | SUPERSEDED — refactor interno de nombre de función auxiliar; misma lógica de verificación de gate. |
| `router.js` | ninguno | ninguno | SUPERSEDED — mismo conjunto de rutas exportadas; core agrega metadata de rutas nuevas (coherente con los módulos nuevos de `layout.js`). |
| `screening.js` | ninguno | ninguno | SUPERSEDED — misma API, implementación más simple en raíz. |
| `views.js` | ninguno | ninguno | SUPERSEDED — misma API; la raíz (56 líneas) es una versión anterior más extensa en marcado pero sin comportamiento exclusivo frente a la versión core (10 líneas). |

## Conclusión

**Ninguno de los 11 módulos divergentes tiene comportamiento público exclusivo que no exista ya en `hemocura-core/`.** Todos son revisiones anteriores de los mismos módulos, superadas por la implementación canónica actual. No se identificó lógica de negocio, validación o flujo que deba migrarse antes de retirarlos.

## Recomendación

Quedan clasificados como **`SUPERSEDED_NO_UNIQUE_BEHAVIOR`** y listos para la fase de archivado/retiro que exige la regla del contrato ("preserved until... classified or archived"). El retiro efectivo (borrarlos y actualizar `max_root_shadow_modules` / `preserved_divergent_modules` en el contrato) debe hacerse en una iteración separada, ya que CI (`frontend_source_truth_gate.py`) fallará hasta que el contrato se actualice junto con la eliminación de archivos.
