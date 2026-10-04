# HemoCura v0.27.0

## Instalación
1. Subir SAFE PATCH sobre v0.26.0.
2. Ejecutar `sql/27_AUDIT_TRACE_EXCEPTIONS_v0_27.sql`.
3. Abrir #audit.
4. Revisar candidatos a excepción.
5. Crear una excepción desde candidato.
6. Verificar que no se duplique si ya está abierta.
7. Registrar una revisión semanal.
8. Revisar bitácora.
9. Ejecutar #qa.

## Principio
Las alertas generan candidatos. La creación de excepción sigue siendo controlada por usuario.
