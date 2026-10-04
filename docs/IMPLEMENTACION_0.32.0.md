# HemoCura v0.32.0

## Instalación
1. Subir SAFE PATCH sobre v0.31.0.
2. NO tocar `js/config.js`.
3. Ejecutar `sql/32_QMS_APPROVAL_INTEGRATION_v0_32.sql`.
4. Abrir `#qmsgov`.
5. Solicitar aprobación de un documento.
6. Aprobar desde `#approvals` con usuario distinto.
7. Ejecutar la aprobación.
8. Confirmar documento `APROBADO`.
9. Para CAPA, verificar primero `effectiveness_status = EFECTIVA` o `VERIFICADA`.
10. Solicitar cierre CAPA.
11. Aprobar y ejecutar.
12. Revisar `#audit`, `#diagnostics`, `#releasegate`, `#qa`.
