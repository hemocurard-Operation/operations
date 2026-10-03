# Implementación v0.12.0 RC

## Requisito
v0.11.0 funcional.

## Nuevos
- hemocura-core/qa-data.js
- hemocura-core/qa.js

## Modificados
- hemocura-core/router.js
- hemocura-core/views.js
- hemocura-core/layout.js
- css/app.css
- VERSION.json

## Uso
1. Subir PATCH.
2. Abrir `/operations/#qa`.
3. Ejecutar QA completo.
4. Revisar cualquier ERROR.
5. Corregir únicamente el subsistema fallido.
6. Repetir QA.
7. Completar checklist de liberación.
8. No declarar producción si quedan checks técnicos fallidos.

## Criterio RC
Técnicamente APTO cuando:
- failed = 0 en QA;
- login/logout/persistencia confirmados;
- RLS revisado;
- backup confirmado;
- ningún módulo clínico SHADOW/BLOCKED se usa como control automático.
