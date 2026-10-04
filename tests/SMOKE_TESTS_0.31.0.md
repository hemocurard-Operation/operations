# Smoke Tests v0.31.0

1. SQL 31 instala.
2. #approvals carga.
3. Crear solicitud funciona.
4. Solicitante no puede autoaprobar si policy lo prohíbe.
5. Rol no autorizado no puede aprobar.
6. Aprobador autorizado puede aprobar.
7. Rechazo cambia estado a RECHAZADA.
8. Aprobación alcanza required_approvals.
9. Ejecución sin APROBADA falla.
10. UNIT_RELEASE aprobada puede ejecutar review_and_release_unit.
11. DAILY_CLOSE aprobada puede ejecutar capture_daily_operational_close.
12. Auditoría registra request/approve/reject/execute.
13. SAFE PATCH no contiene js/config.js.
