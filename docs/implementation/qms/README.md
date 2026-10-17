# Calidad: información y decisiones

Implementación solicitada tras comparar HemoCura con MasterControl, Reliance y Qualio. Fecha de trabajo: 16 de octubre de 2026 (America/Santo_Domingo). Los nombres de migraciones y marcas técnicas usan UTC.

## Estado

Migración `20261017005235_quality_information_decisions` aplicada tras autorización expresa de reintento. La auditoría de producción comprobó RLS, funciones con seguridad del llamante, prohibición de acceso anónimo, historial protegido y conservación de los 2742 donantes y 11 vínculos de roles. La interfaz forma parte de esta entrega. Su publicación se realiza mediante GitHub Pages después de integrar los cambios; el estado del despliegue se consulta en las Actions del repositorio.

El asesor de seguridad no registró hallazgos nuevos. Las vistas con seguridad del definidor señaladas bajaron de 66 a 60; permanecen hallazgos preexistentes en otros objetos del sistema y configuración Auth. Esta auditoría verifica el alcance de la mejora y no certifica la seguridad de toda la aplicación. Referencia: https://supabase.com/docs/guides/database/database-linter?lint=0010_security_definer_view

## Ventanas

- `#quality`: prioridades; expedientes de no conformidad/CAPA; riesgos; documentos/cambios; auditorías/competencias; proveedores; decisiones y agenda.
- `#management`: revisiones con resumen, decisiones/recursos y compromisos; aprobación por otro usuario; seguimiento con evidencia y plazo original.
- `#qmsgov`: conserva la aprobación documental y de cierre CAPA. Botones sujetos a sus permisos actuales; evita mostrar cifras antiguas si falla una consulta.

## Información confiable

Las fuentes se consultan mediante páginas ordenadas hasta agotarlas, incluyendo proyectos que devuelvan menos filas que las solicitadas. Un error en cualquier página invalida esa fuente: no se publica un cero ni se habilita la exportación NC/CAPA si faltan sus fuentes. Los errores de módulos relacionados se muestran en sus pestañas.

El período representa actividad y cohortes de vencimiento. La cartera actual incluye pendientes de cualquier fecha; el listado y CSV incluyen abiertos y cerrados con actividad en el período. Las mediciones de indicadores y las incidencias se filtran por período. Las metas mostradas son las actuales, no una reconstrucción de metas históricas.

El alcance de sucursal se aplica a NC, CAPA enlazadas, riesgos, incidencias y mediciones. CAPA sin NC y registros sin sucursal se identifican como corporativos/sin vínculo; se excluyen al elegir una sucursal concreta. Documentos, cambios y objetivos se presentan por separado como corporativos. Se conservan los ámbitos autorizados por `can_access_branch`, incluidos ámbitos gerenciales heredados; no se asignan roles o permisos adicionales.

No se calculan tasas de reincidencia a partir de texto parecido. No se equipara formación completada con competencia demostrada. Las brechas persona–competencia permanecen en su módulo autorizado; los proveedores conservan la trazabilidad de recepción en Compras.

## Controles

- RLS de NC, CAPA, riesgos y revisiones comprueba perfil activo, permiso vigente y ámbito autorizado. Se reemplazan políticas antiguas por rol que eludían esos controles. Las vistas modificadas son `security_invoker`.
- Los escritores nuevos son SECURITY INVOKER, autenticados y con permisos ya existentes. No se añaden códigos de permiso ni asignaciones a usuarios/roles.
- La NC puede cerrarse con causa, evidencia, revisión independiente y CAPA vinculadas ya resueltas. Su historial y cierre quedan protegidos.
- La CAPA conserva su NC y plazo original. Guardar otra evidencia, causa, plan o responsable invalida la verificación y solicitud previa. La eficacia requiere evidencia, causa, observación y revisor distinto del responsable y ejecutor. El cierre sigue requiriendo una solicitud aprobada posterior a la verificación.
- Las revisiones se crean con compromisos en una transacción. Un responsable no elegible revierte toda la operación. La revisión empieza en borrador; admite otros compromisos antes de aprobar. Su autor no puede aprobarla. No se cierra con compromisos pendientes. El contenido aprobado y los expedientes cerrados se preservan.
- Reprogramar un compromiso exige motivo y conserva el plazo original. Su cierre requiere evidencia; la cancelación exige justificación. La actualización usa bloqueo de fila y revisión para rechazar datos obsoletos.
- La evaluación de riesgos registra controles, tratamiento y valores residuales; aceptar/cerrar exige permiso gerencial y evidencia. La evaluación de impacto de cambios documentales se actualiza mientras están pendientes, sin aprobar automáticamente el documento.
- `qms_change_history` conserva antes/después, actor y fecha; el cliente no puede escribirlo ni borrarlo. El historial de la NC se consulta en el expediente. No se elimina el historial operativo.

Los plazos anteriores al despliegue no se inventan: `original_due_known=false`. Solo los registros nuevos conservan un original verificable. Cierre a tiempo = cerrados dentro del original / obligaciones que vencían en el período; pendientes cuentan en el denominador y canceladas se excluyen. Eficacia = resultados favorables / verificaciones fechadas realizadas en el período; pendientes se presentan por separado. Denominador cero se muestra como «Sin base de cálculo».

## Agenda y límites

La agenda por área ya publicada se reutiliza mediante enlaces y códigos de expediente/compromiso. No se generan tareas duplicadas automáticamente. Completar una tarea de agenda no cierra una NC/CAPA, aprueba documentos ni libera sangre. No se envían correos/mensajes ni se activan reglas clínicas. La organización debe registrar sus expedientes reales y programar sus responsables; el despliegue no carga ejemplos en producción.

Los recursos aprobados y su justificación se registran en las decisiones; no constituyen un módulo de presupuesto ni una orden de compra. No se automatiza capacitación por cambio documental ni se promete certificación normativa. Las guías de la OMS sirven como referencia operativa.

## Referencias del análisis

- MasterControl: https://www.mastercontrol.com/quality/capa-software/management/
- Reliance (antes ETQ): https://www.octave.com/products/asset-performance-management/reliance
- Qualio: https://www.qualio.com/product/change-control-software
- OMS: https://www.who.int/publications/b/78804

## Verificación

El flujo `quality-information.yml` ejecuta reglas de cálculo, linter de seguridad de migración, reconstrucción PostgreSQL completa y navegador con fixture local. Los informes en este directorio identifican expresamente las pruebas sintéticas y la comprobación de producción por separado.
