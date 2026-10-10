# I-010 · Clasificación completa de sombras legacy + limpieza B

**Versión candidata:** 0.45.10 RC  
**Fecha:** 2026-10-10

## Objetivo

Clasificar los 22 módulos sombra restantes de la raíz frente a `hemocura-core/`, retirar únicamente los idénticos y preservar explícitamente los divergentes.

## Resultado de clasificación

### IDENTICAL · retirados en I-010

| Legacy raíz | Canónico | SHA común |
|---|---|---|
| `compliance.js` | `hemocura-core/compliance.js` | `040ee494fb1c3eda7a7d978bb5a2133373f9847e` |
| `documents.js` | `hemocura-core/documents.js` | `0efa9ba5bdcb7c316eb28f0295c87f973ae377c3` |
| `inspections.js` | `hemocura-core/inspections.js` | `3d71efdbfe37d85fe71c764754a41a75ae8f75e0` |
| `integrated-qms-data.js` | `hemocura-core/integrated-qms-data.js` | `ba828dba4f90d38a0856daf1c84e050e9221b78d` |
| `projects.js` | `hemocura-core/projects.js` | `c29e09af3161086d511260c5dc4b1591cf6b7555` |
| `qms-action-board.js` | `hemocura-core/qms-action-board.js` | `d13bdd312a0393f50252dee08dbbd286c1866527` |
| `quality.js` | `hemocura-core/quality.js` | `0ea22f8c57f85db6e47a383d8bcfc2147c37736d` |
| `requisitions.js` | `hemocura-core/requisitions.js` | `839c74b04e87605cabc8e1b419e926b894459ef9` |
| `supply-data.js` | `hemocura-core/supply-data.js` | `0057187e59129a194e00a2132c0eb887f961b889` |
| `supply-planning.js` | `hemocura-core/supply-planning.js` | `15c1043e0661be1b912418d3167bd956d10e6b7e` |
| `operational-sales.js` | `hemocura-core/operational-sales.js` | `d8aab1a9619ea14136d78b6591dcfcd5011e4b50` |

### DIVERGENT · preservados

| Legacy raíz | SHA legacy | SHA canónico | Decisión |
|---|---|---|---|
| `blood-operations-data.js` | `bc17f4d19062d4b84e4ff258aae42bb78302cac5` | `e58711876ab76c35155389186a5635d1d39a2f5f` | Preservar |
| `command-data.js` | `9685c5fc1afd06a01641ae02a95de2a75201bdf8` | `be7e9e9bd2f7619efdec71cbbf1e13b923d9acc2` | Preservar |
| `donors.js` | `fb52a7a7e5bccbd5c16997bbf6ffd667a96a47ee` | `d3181583c1abca453252d145c06eb4033bb4ff60` | Preservar |
| `layout.js` | `06f067ae0943c3ed202facdd385e5a55416890db` | `aa98b55440cdc528008d7616ced925ae72793ff1` | Preservar |
| `ops-dashboard.js` | `7a4345cb4d97c56a3cdc9b3dcc666e197ec29365` | `61c980ce4afcab4a5c52f14dc6754804257ab7fa` | Preservar |
| `production.js` | `13c11be162cdc10d5ba50dd5bd831f2dc8c550f0` | `07e180f174089ca23f5e057ae61b01b70eb57acb` | Preservar |
| `release-data.js` | `9a304f20ae5b18701abea99e9160178c523ccc1b` | `db811f55a8cd62335a6b5c142747ff9cbee0f76a` | Preservar |
| `release-gate.js` | `deb8ab74aa5bac56757dd69c14df3629ba3e985a` | `42ad06a916d2f416f9fb1666e47e9258a9e5ad1d` | Preservar |
| `router.js` | `bf58d3828bb0dd67a4a60406842d504a87b35386` | `0e2fba999e5937dd6ab96d82402b54f36797ed4a` | Preservar |
| `screening.js` | `d1c3a9cbebd39e0d864621c63686fbd0e1d37bf4` | `5c2727a5418835e179e24e6269b2aadeb22dcad1` | Preservar |
| `views.js` | `f9081a19770487cf32c3c7e5745382214fc8e0ed` | `0f77c43e147fcb3e7350de72b777172052f62a8f` | Preservar |

## Efecto acumulado I-008 → I-010

- Estado inicial medido: 27 sombras raíz ↔ core.
- I-009 retiró 5 exactos: 27 → 22.
- I-010 retira 11 exactos: 22 → **11**.
- Los 11 restantes son todos divergentes y quedan protegidos contra borrado accidental.

## Contrato de Source of Truth v0.45.10

El nuevo contrato exige:

- máximo 11 sombras;
- los 16 duplicados exactos retirados deben permanecer ausentes;
- sus módulos canónicos deben permanecer presentes;
- los 11 pares divergentes deben mantener ambas versiones presentes y con contenido diferente;
- `hemocura-core` no puede importar desde la raíz legacy;
- la cadena de arranque canónica no puede cambiar.

## Impacto

- Runtime: sin cambio esperado.
- Supabase: sin cambio.
- RLS/RPC: sin cambio.
- Funcionalidad clínica: sin cambio.
- `js/config.js`: sin cambio.

## Próxima iteración

**I-011 · Análisis semántico de los 11 divergentes.**

No consiste en borrar. Para cada par se debe determinar qué diferencias representan mejoras antiguas, código obsoleto o comportamiento aún no migrado. La salida será una decisión `ARCHIVE / PORT_MISSING_BEHAVIOR / KEEP_FOR_EVIDENCE`, con pruebas específicas antes de retirar cualquier legado divergente.