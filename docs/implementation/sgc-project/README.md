# Implementación guiada del SGC

Ruta: `index.html#sgcimplementation`. Seis fases, 44 pasos iniciales ampliables y 12 puertas de decisión. Cada proyecto define sede, alcance, responsable, revisor independiente y fechas; conserva una copia de la plantilla y el historial de cambios. No se crean proyectos reales automáticamente.

## Uso

1. Crear el proyecto con alcance real y revisor distinto del responsable.
2. Distribuir responsables y fechas; agregar pasos específicos del alcance cuando corresponda.
3. Ejecutar instrucciones y criterios, adjuntar evidencias y versiones documentales aprobadas.
4. Enviar a revisión independiente y superar las puertas en orden.
5. Revisar eficacia, auditoría y decisiones de gerencia antes de cerrar. El cierre no concede acreditación.

La guía HC-SGC-IMP-001 contiene el procedimiento completo y enlaza los recursos adaptados. El maestro v3, arquitectura v2 y recursos legales permanecen en BORRADOR; no sustituyen documentos aprobados sin el circuito documental. Capacitación conserva su versión 1.0-RC. Los enlaces a otros módulos respetan los módulos habilitados del usuario. La agenda por área sigue siendo el punto para compromisos diarios, referenciando proyecto y paso.

## Seguridad y evidencia

Se reutilizan QUALITY_VIEW, QUALITY_WRITE, QUALITY_DAILY_REVIEW y DOCUMENTS_WRITE. La visibilidad inicial replica Calidad y es ajustable por Super Usuario. No se alteran usuarios ni asignaciones de roles.

Seis tablas tienen RLS y solo lectura directa para clientes autenticados. Las mutaciones pasan por `sgc_project_action`, SECURITY DEFINER deliberado con identidad activa, permisos, sede canónica, pertenencia, revisión independiente y control de versión. Los ayudantes privados y acceso anónimo están revocados. Este escritor privilegiado requiere mantener estas validaciones en cualquier ampliación futura.

Las versiones documentales se validan contra una aprobación ejecutada en el circuito formal. Replanificar o reabrir invalida puertas afectadas y posteriores. Evidencia obsoleta no cuenta en el avance. Los períodos de observación se validan con fecha de República Dominicana, incluyendo el mínimo de seis meses para evidencia longitudinal. No hay cumplimiento inferido por completar casillas ni aprobación automática.

## Validación

184 comprobaciones en PostgreSQL aislado, 23 verificaciones de navegador del módulo, 9 pruebas de dominio, 26 regresiones de Calidad y 39 del flujo operativo. Los actores y datos de prueba no se insertan en producción. Los informes adjuntos distinguen pruebas locales y auditoría de producción.
