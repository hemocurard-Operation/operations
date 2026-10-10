# HemoCura · Ejecución TRN-051 a TRN-100

Fecha: 2026-10-10  
Rama: `feature/training-release-1-0-trn051-100`  
Release candidato: `TRN-1.0-RC`

## Resultado ejecutivo

El sistema de entrenamiento evolucionó de un HTML didáctico a un módulo integrado con HemoCura y Supabase. La implementación técnica de las capacidades TRN-051–094 está disponible, con un único gate de ejecución en TRN-060: la primera certificación end-to-end requiere dos perfiles reales distintos (participante + evaluador). La base de producción tiene actualmente un solo perfil, por lo que ese caso no se falsifica.

TRN-095–100 son gates humanos/release: aprobación documental, UAT por rol, cierre de hallazgos y liberación. Se dejaron mecanismos y casos preparados, pero no se marcan PASS sin evidencia real.

## Estado por bloque

| Iteraciones | Estado | Evidencia principal |
|---|---|---|
| TRN-051–059 | IMPLEMENTADO | `training.html`, `training-app.js`, RLS, evidencia práctica, gate de puesto/competencia |
| TRN-060 | LISTO / NO EJECUTADO | Requiere participante y evaluador reales distintos |
| TRN-061–070 | IMPLEMENTADO | certificados, QR, verificación, estados, revocación, vigencia, recertificación |
| TRN-071–080 | IMPLEMENTADO | BI por sucursal/puesto/competencia/módulo, duración, riesgo, reporte mensual, Revisión Dirección |
| TRN-081–087 | IMPLEMENTADO | banco ampliado, aleatorización, dificultad por reintento, microentrenamiento y remediación dirigida |
| TRN-088–090 | IMPLEMENTADO | Edge Function JWT `training-tutor`: tutor, explicador de error y ejercicio guiado |
| TRN-091–094 | IMPLEMENTADO | matriz puesto→competencia, documento controlado, autorización separada, versionado |
| TRN-095 | GATE HUMANO | `HC-TRN-SUITE-001` está BORRADOR. Backend impide aprobar `TRN-1.0-RC` hasta APROBADO/VIGENTE |
| TRN-096–098 | UAT PREPARADA | `UAT-TRN-AO-001`, `UAT-TRN-LAB-001`, `UAT-TRN-ADM-001` activos y críticos |
| TRN-099 | GATE DE CIERRE | workflow `HemoCura Training Safety`; cierre final depende de resultados UAT |
| TRN-100 | BLOQUEADO POR GATES | liberar 1.0 solo después de TRN-095–099 PASS |

## Controles de seguridad implementados

- RLS activo en todas las tablas nuevas expuestas.
- Sin acceso anónimo a datos de entrenamiento/certificación.
- Perfiles del personal solo se cargan para `ADMIN`, `CALIDAD` o `GERENCIA_OPERATIVA`.
- Participante y evaluador deben ser distintos.
- Un certificado solo puede emitirse si la competencia es obligatoria para un puesto activo asignado al participante.
- Autorizar uso del sistema es una acción separada de certificar competencia.
- La autorización de uso no concede autoridad clínica.
- Tutor HemoCura usa contenido aprobado y declara `clinical_decision=false`.
- No se exponen claves `service_role` en frontend.
- Vistas nuevas usan `security_invoker=true`.
- Funciones nuevas fijan `search_path` y no son SECURITY DEFINER.

## Control documental

Se creó `HC-TRN-SUITE-001`, versión `1.0-RC`, en `document_register` como BORRADOR y se vinculó a `training_content_versions.TRN-1.0-RC`. El trigger `trg_training_content_approval_gate` bloquea la aprobación del contenido mientras ese documento no esté `APROBADO` o `VIGENTE`.

## UAT pendiente por datos reales

Los tres casos UAT requieren usuarios reales del proceso. No se crearán perfiles ficticios para producir un PASS artificial. Para completar TRN-096–098 se necesitan, como mínimo, perfiles reales que cubran:

1. Asistente de Operaciones.
2. Laboratorio / Calidad / Médico-Gerente Técnico.
3. Super Usuario / Gerencia / TI.
4. Un evaluador autorizado distinto del participante en cada certificación.

## Criterio de liberación TRN-100

Liberar `Entrenamiento HemoCura 1.0` únicamente cuando:

- `HC-TRN-SUITE-001` esté formalmente aprobado/vigente.
- los tres casos UAT de capacitación tengan evidencia y resultado PASS;
- no existan hallazgos críticos abiertos derivados de UAT;
- CI `HemoCura Training Safety` esté verde;
- las guardias clínicas permanezcan sin cambios;
- la primera certificación end-to-end haya producido participación, evaluación, evidencia práctica, certificado y verificación trazables.
