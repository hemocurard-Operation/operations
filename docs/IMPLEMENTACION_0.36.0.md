# HemoCura v0.36.0

## Instalación
1. Subir SAFE PATCH sobre v0.35.0.
2. NO tocar `js/config.js`.
3. Ejecutar `sql/36_ANALYTICAL_QC_v0_36.sql`.
4. Cerrar sesión y volver a iniciar.
5. Abrir `#analyticalqc`.
6. Registrar métodos.
7. Registrar verificaciones/validaciones.
8. Configurar planes IQC con límites aprobados por el laboratorio.
9. Registrar controles y revisar alertas.
10. Abrir desviación ante control fuera de rango cuando corresponda.
11. Configurar programas EQA/PT y eventos.
12. Vincular desviaciones relevantes con NC/CAPA.
13. Ejecutar `#diagnostics`, `#releasegate` y `#qa`.

## Guardrail
Los flags estadísticos son apoyo al control del proceso. No sustituyen revisión profesional ni interpretación clínica.
