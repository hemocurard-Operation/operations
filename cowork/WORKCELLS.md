# HemoCura Cowork v1 · Workcells

## 1. Desarrollo

**Responsabilidad:** frontend, router, layout, módulos, UX, integración de versiones y PR.

**Entradas:** issues, hallazgos de QA, cambios de contrato, requerimientos operativos.

**Salidas:** código, PR, smoke frontend, changelog.

**Gate:** CI + smoke navegador.

## 2. Base de Datos

**Responsabilidad:** schema, migraciones, vistas, RPC, constraints y consistencia de datos.

**Entradas:** contratos runtime, requisitos funcionales y cambios de proceso.

**Salidas:** preflight SQL, migration/patch, validator SQL.

**Gate:** validator real sobre Supabase.

## 3. QA / Validación

**Responsabilidad:** security linter, runtime contract, smoke, UAT y Doctor.

**Entradas:** código y migraciones candidatas.

**Salidas:** PASS/FAIL reproducible y evidencia.

**Gate:** no existe `VALIDADO` sin prueba ejecutada.

## 4. Seguridad

**Responsabilidad:** roles, grants, RLS, SECURITY DEFINER, search_path, superficie anon y segregación de funciones.

**Entradas:** Security Advisor, pg_catalog, policies, permisos reales.

**Salidas:** hardening incremental y validator.

**Gate:** no debilitar RLS para resolver compatibilidad.

## 5. Calidad / ISO 15189

**Responsabilidad:** incidencias, NC, CAPA, documentos, auditorías, competencias, recursos, hemovigilancia y trazabilidad del SGC.

**Entradas:** operación real, hallazgos y requerimientos normativos.

**Salidas:** evidencia, seguimiento, control documental y acciones de mejora.

**Gate:** el software soporta el SGC; no declara por sí solo conformidad ISO 15189.

## 6. Gerencia Operativa

**Responsabilidad:** prioridades, KPIs, riesgos, continuidad, readiness, release y secuencia de implementación.

**Entradas:** Control Center, Doctor, estados de workcells.

**Salidas:** próxima acción segura, decisión de avance y cierre de release.

**Gate:** ninguna prioridad comercial u operativa puede saltar un STOP de seguridad o clínico.
