# HemoCura · Training Native 1.1 RC — Informe de ejecución

## Objetivo
Convertir Capacitación de una aplicación paralela en un módulo nativo de la Suite y fortalecer la integridad de la evidencia de competencia.

## Implementado
- Ruta SPA `#training` dentro de **Calidad y Seguridad**.
- Permisos separados: `TRAINING_SELF`, `TRAINING_ASSESS`, `TRAINING_ADMIN`.
- `SUPER_USUARIO` no obtiene permisos de evaluación/certificación por privilegio tecnológico.
- Asignación de capacitación derivada del **puesto activo**; el usuario no selecciona manualmente un rol para certificarse.
- Asignación formal de puesto disponible para `TRAINING_ADMIN` desde Competencias mediante `training_assign_job_role`; el sistema no infiere ni autoasigna puestos reales.
- 7 programas gobernados, 11 mapeos puesto→programa y 35 preguntas en Supabase.
- Contenido, práctica y microentrenamiento fuera del JavaScript y versionados en base de datos.
- El banco de preguntas visible al navegador no expone `correct_index` ni explicación.
- Calificación mediante `training_submit_quiz`; la nota se calcula en PostgreSQL.
- Certificación transaccional mediante `training_finalize_competency`.
- Certificado generado en servidor, segregación participante/evaluador y verificación de puesto activo.
- Práctica supervisada registrada solo por `TRAINING_ASSESS`.
- Certificados y autorizaciones sin INSERT/UPDATE directo desde navegador; se usan RPCs controlados.
- Autorización de uso separada de la competencia y sin conceder autoridad clínica.
- Recertificación, analítica por puesto/competencia/riesgo y entrada para Revisión por la Dirección.
- Entrenamiento contextual: “Aprender este proceso” desde módulos operativos.
- Event bus explícito para capacitación; se eliminan polling/MutationObserver del diseño nuevo.
- Tutor HemoCura v2 con JWT y recuperación exclusiva desde documentos `APROBADO`/`VIGENTE`.
- Contrato runtime y snapshot Supabase reconciliados.
- CI `HemoCura Training Native Safety`.

## Gobierno del contenido
`TRN-1.0-RC` permanece `DRAFT` y `HC-TRN-SUITE-001` permanece `BORRADOR`. El sistema no permite ofrecer el programa como contenido aprobado ni certificar mientras el documento controlado no esté `APROBADO` o `VIGENTE`.

## Gates humanos pendientes
1. Asignar formalmente puestos a usuarios reales en `staff_job_assignments` mediante la nueva operación gobernada.
2. Contar con participante y evaluador distintos.
3. Aprobar el documento `HC-TRN-SUITE-001` mediante Control Documental.
4. Ejecutar UAT-TRN-AO-001, UAT-TRN-LAB-001 y UAT-TRN-ADM-001 con usuarios reales.
5. Corregir hallazgos y obtener signoffs requeridos antes del Release 1.0.

No se deben falsificar estos gates ni asignar puestos a una persona por inferencia del sistema.

## Seguridad
Las vistas nuevas usan `security_invoker=true`. Los RPCs `training_assign_job_role`, `training_submit_quiz`, `training_finalize_competency`, `training_authorize_system_use`, `training_revoke_certificate` y `training_revoke_authorization` son `SECURITY DEFINER` intencionales, con `SET search_path=''`, autenticación/permiso internos y sin `EXECUTE` para `PUBLIC`/`anon`. Esta exposición controlada permite mantener las tablas de evidencia, certificados, autorizaciones y asignaciones críticas sin escritura privilegiada directa desde el navegador.

La deuda legacy de Security Advisor sigue gobernada por la secuencia C12 → C13A → C13C1 → ...; este release no sustituye ni adelanta esa remediación.
