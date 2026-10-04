# HemoCura v0.31.0

## Instalación
1. Subir SAFE PATCH sobre v0.30.0.
2. NO tocar `js/config.js`.
3. Ejecutar `sql/31_APPROVALS_SOD_v0_31.sql`.
4. Cerrar sesión y volver a iniciar.
5. Abrir `#approvals`.
6. Crear una solicitud UNIT_RELEASE o DAILY_CLOSE de prueba.
7. Intentar aprobarla con el mismo usuario: debe fallar si la política exige segregación.
8. Aprobar con un segundo usuario autorizado.
9. Ejecutar con un usuario distinto al solicitante.
10. Revisar auditoría.
11. Ejecutar `#diagnostics`, `#releasegate` y `#qa`.

## Importante
Las políticas se crean con `enforce_before_execution=false`.
Esto permite validar el flujo sin romper los procesos actuales.
La activación obligatoria debe hacerse después de pruebas.
