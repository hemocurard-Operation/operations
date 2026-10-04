# Smoke Tests v0.32.0

1. SQL 32 instala.
2. #qmsgov carga.
3. Documento elegible permite solicitar aprobación.
4. Documento pasa a EN_REVISION.
5. approval_request_id queda vinculado.
6. Aprobación ejecutada pone documento APROBADO.
7. document_changes se marca APROBADO.
8. CAPA sin efectividad verificada no permite solicitar cierre.
9. CAPA con EFECTIVA/VERIFICADA permite solicitud.
10. Aprobación ejecutada cierra CAPA.
11. Auditoría registra ejecución.
12. SAFE PATCH no contiene js/config.js.
