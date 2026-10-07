# HemoCura Cowork v1

HemoCura Cowork v1 convierte el proyecto Operations en un espacio de trabajo continuo para desarrollo, base de datos, QA, seguridad, calidad e inteligencia operativa.

## Fuentes de verdad

- **GitHub**: código, PR, workflows, documentación y artefactos de release.
- **Supabase**: schema, datos operativos, Auth, RLS, funciones y estado runtime.
- **Cowork Control Center**: estado consolidado y próxima acción segura.

## Regla operativa maestra

`PREFLIGHT → PATCH → VALIDATE → CI → SMOKE → DOCTOR → GATE → NEXT`

Estados válidos:

- `DISEÑADO`
- `GENERADO`
- `INSTALADO`
- `VALIDADO`

Solo `VALIDADO` autoriza avanzar cuando la etapa exige evidencia runtime.

## Guardrails

1. No modificar producción sin preflight.
2. No usar `service_role` en frontend.
3. No sobrescribir `js/config.js` desde paquetes de release.
4. Preservar `await mountLayout(session);`.
5. No deshabilitar RLS para resolver errores.
6. No automatizar elegibilidad clínica, compatibilidad transfusional ni liberación de unidades.
7. Toda liberación clínica requiere decisión humana autorizada.
8. No declarar cumplimiento ISO 15189 por software solamente.

## Células de trabajo

- Desarrollo
- Base de Datos
- QA / Validación
- Seguridad
- Calidad / ISO 15189
- Gerencia Operativa

Ver `WORKCELLS.md`.

## Estado inicial de Cowork v1

- Frontend candidate: `0.44.2`
- Database baseline: `0.44`
- Security linter: PASS
- Runtime contract gate: PASS
- Release readiness doctor: NOT_READY
- Remediation sequencer: PASS
- Próxima acción segura: `S01_C11_2_FRONTEND_SMOKE_MERGE`

Ver `CONTROL_CENTER.md` y `TASK_QUEUE.md`.
