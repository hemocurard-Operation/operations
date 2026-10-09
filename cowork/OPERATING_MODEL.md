# HemoCura Cowork v1 · Operating Model

## Ciclo estándar

1. **PREFLIGHT**: solo lectura; confirma dependencias, estado, schema, permisos y riesgos.
2. **PATCH**: cambio mínimo, forward-only, sin borrar datos ni reinstalar la base.
3. **VALIDATE**: comprueba que el cambio quedó aplicado y cumple su objetivo.
4. **CI**: Security Linter, Runtime Contract y checks específicos de la iteración.
5. **SMOKE**: prueba funcional del flujo afectado.
6. **DOCTOR**: diagnóstico consolidado.
7. **GATE**: `PASS`, `ATTENTION` o `STOP`.
8. **NEXT**: solo si el gate lo autoriza.

## Separación de responsabilidades

- GitHub valida código, contratos, workflows y artefactos.
- Supabase valida runtime, schema, RLS, RPC y datos.
- Ningún resultado de GitHub sustituye evidencia de Supabase cuando el cambio es backend.
- Ningún preflight de Supabase sustituye smoke de navegador cuando el cambio es frontend.

## Gestión de cambios

Cada cambio debe declarar:

- objetivo;
- alcance;
- dependencias;
- archivos/objetos afectados;
- riesgo;
- preflight;
- patch;
- validator;
- smoke/UAT;
- rollback o reparación forward;
- resultado esperado.

## Protocolo STOP

Ante `FAIL`, `STOP`, `BLOCKED`, `PARTIAL` o `MISSING`:

1. detener la cadena;
2. conservar evidencia exacta;
3. identificar causa raíz;
4. preparar corrección mínima;
5. volver a ejecutar desde el gate fallido;
6. no saltar al siguiente módulo.

## Release

Un release solo puede declararse READY cuando:

- CI = PASS;
- schema/runtime contract = PASS;
- RLS/RPC security = PASS;
- smoke/UAT = PASS;
- clinical guardrails = PASS/SAFE_LIMITED documentado;
- sign-offs requeridos = completos;
- Doctor final = READY.
