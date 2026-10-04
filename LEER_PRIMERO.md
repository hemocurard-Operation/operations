# HemoCura v0.31.0 SAFE PATCH

1. NO reemplaza js/config.js.
2. Subir sobre v0.30.0.
3. Ejecutar sql/31_APPROVALS_SOD_v0_31.sql.
4. Cerrar sesión y volver a iniciar.
5. Abrir #approvals.
6. Probar solicitud → aprobación → ejecución con usuarios distintos.
7. Revisar #audit.
8. Ejecutar #diagnostics, #releasegate y #qa.

Las políticas nacen en modo no obligatorio (`enforce_before_execution=false`) para validar sin interrumpir la operación.
