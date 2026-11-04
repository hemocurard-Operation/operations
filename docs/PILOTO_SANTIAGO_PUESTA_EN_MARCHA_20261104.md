# Hemocura 0.49.2 · preparación técnica y piloto Santiago

Destino exclusivo: `hemocurard-Operation/operations`, Supabase `tiothqiljipdamgudvcb`.
Solicitud: corregir hallazgos y preparar la puesta en marcha con Santiago y usuarios de prueba. SoFa no forma parte de esta entrega.

## Alcance y compatibilidad

La migración `production_security_privacy_readiness` conserva firmas y columnas de las vistas existentes. Endurece permisos: las llamadas anónimas y nueve RPC heredados quedan retirados; la aplicación utiliza sus reemplazos `hc_*`. No es una promesa de compatibilidad para clientes externos que dependan de permisos inseguros. `hc_review_donor_status` también queda sin ejecución directa por carecer de alcance de sucursal suficiente.

- Vistas públicas con `security_invoker`, funciones con ruta fija, actor activo en entradas privilegiadas y privilegios predeterminados restringidos.
- Cámara hiperbárica: proyección comprobada por rol/sucursal; identificador opaco sin iniciales; sin nombre, teléfono, etiqueta libre ni notas para lectores sin permiso PII. Se retira la lectura directa de esas columnas y el acceso indirecto mediante auditoría.
- FEFO y cuarentena por temperatura: doble condición real en backend, conservando las funciones públicas. No se habilita automatización clínica ni se alteran unidades reales.
- Índices aditivos para claves foráneas y claves técnicas en dos tablas temporales. No elimina filas, índices históricos ni restricciones de negocio. Los índices se construyen en transacción con espera de bloqueo máxima de cinco segundos; una instalación que no consiga el bloqueo revierte y debe reprogramarse.
- Optimiza expresiones de identidad RLS sin fusionar políticas de negocio. Reconcilia 17 marcadores de migraciones únicamente contra el historial real.
- UAT y Liberación muestran ejecución, errores, prueba identificada y evidencias. El backend impide cerrar UAT incompleta, aprobar PASS sin evidencia, modificar pruebas ajenas y usar una persona para firmar dos áreas.
- La preparación técnica se calcula; una versión `PRUEBA:` jamás acredita liberación productiva. No activa el modo clínico.
- Los formularios avisan al abandonar cambios y bloquean navegación durante un guardado. Los errores conservan los campos de UAT/liberación. No hay guardado de datos clínicos en localStorage/sessionStorage ni recuperación garantizada después de un cierre forzado.

## Piloto reproducible

Ejecutar en PostgreSQL desechable:

```sh
python tools/workflow_postgres_runner.py --allow-external-prerequisite-fixture --report-dir /tmp/hemocura-pilot
```

El piloto usa la sucursal Santiago (`STI`) y seis identidades ficticias `pilot-sti-1@example.invalid` a `pilot-sti-6@example.invalid`: Operaciones, Calidad, TI, Gerencia, lector restringido y clínico ficticio. Se crean únicamente en transacciones locales, con rollback. No son credenciales de acceso al sistema publicado.

Reconstruye metadatos heredados que el repositorio no contenía mediante fixtures explícitos: estructuras/políticas y configuración, sin copiar pacientes, donantes, usuarios o resultados de producción. Comprueba privacidad, sucursal, usuario inactivo, UAT, cuatro firmas distintas ficticias, bloqueo de liberación de prueba, doble condición clínica y regresión de operaciones/calidad/laboratorio/compras. Las firmas sintéticas no son aprobación clínica ni validación normativa. Esta reconstrucción tampoco prueba una restauración real de una copia de seguridad productiva.

Pruebas de navegador:

```sh
NODE_PATH=/opt/codex/runtimes/codex-primary-runtime/dependencies/node/node_modules HEMOCURA_BROWSER=/usr/bin/chromium node tools/workflow_browser_runner.cjs
```

Incluyen mocks locales, pruebas de error/reintento, progreso, doble clic, conservación de campos, escape de texto, acceso por rol y vistas móviles. No envían datos clínicos a servicios externos.

## Activación y aceptación humana

1. Aplicar la migración, verificar metadatos/advisors, publicar 0.49.2 y comprobar login y recursos. Mantener `LIVE_LIMITED`, operación paralela y automatización clínica apagada.
2. Un Super Usuario revisa en Configuración la disponibilidad de módulos `uat` y `release1` para los roles autorizados. La migración añade entradas ausentes y respeta las entradas existentes deshabilitadas; no elude el trigger de administración de roles.
3. En `index.html#uat`, una ejecución marcada como práctica usa `PRUEBA:`. Para la aceptación formal, los responsables humanos crean la ejecución de la versión real y documentan resultados observados y evidencias verificables de todos los casos.
4. En `index.html#release1`, Operaciones, Calidad, TI y Gerencia firman con cuatro identidades activas diferentes y evidencia. Una prueba automatizada no sustituye ninguna firma. Nunca compartir cuentas.
5. Antes de considerar la salida clínica: evidencia de restauración de backup en entorno aislado, revisión de protección contra contraseñas filtradas en Supabase Auth (puede requerir plan Pro), capacitación y aceptación clínica real. No cambiar de plan automáticamente.
6. La pantalla muestra verificaciones técnicas y los requisitos externos. El indicador calculado no sustituye esas comprobaciones ni cambia el modo operativo; habilitar automatización clínica requiere un procedimiento clínico autorizado separado.

## Reversión y continuidad

Conservar el modo limitado y apagar cualquier flag de piloto ante errores. Restaurar únicamente archivos de interfaz de la versión anterior si es necesario; mantener las correcciones de seguridad. No reabrir acceso anónimo, PII o RPC inseguros para resolver una incidencia de interfaz. Un fallo transaccional de migración revierte el bloque entero. Revertir cambios de datos posteriores requiere el procedimiento de recuperación aprobado, no un script de borrado.

No forzar recarga de pestañas con trabajo abierto. Terminar el guardado y navegar voluntariamente a la versión nueva. La protección de progreso nueva solo actúa después de cargar sus recursos; no puede recuperar retrospectivamente datos perdidos por versiones anteriores.

Los avisos de índices sin uso y políticas permisivas múltiples requieren análisis de carga y semántica; eliminarlos automáticamente puede romper autorización o rendimiento. Las funciones privilegiadas que conservan permisos son entradas intencionales verificadas, no una razón para conceder acceso general.

## Resultado verificado de esta entrega

Migración aplicada en Hemocura: `20261104174434_production_security_privacy_readiness`.

- 472 comprobaciones PostgreSQL aprobadas, reconstruyendo 91 archivos de esquema/candidatos. Incluye regresión posterior al endurecimiento de calidad, laboratorio y compras; esta última adapta el antiguo fixture de identidad a los roles reales y verifica la auditoría como observador de pruebas, sin ampliar permisos del operador.
- 39 comprobaciones del flujo de trabajo en navegador y 25 de UAT/liberación. Linter de migración, contrato de frontend, sintaxis JavaScript y presupuesto UX aprobados.
- Verificación productiva por metadatos: cero vistas con privilegios del propietario, tablas sin RLS, rutas de función mutables, lecturas anónimas, funciones privilegiadas anónimas, políticas FOR ALL amplias, acceso crudo a identidad del paciente, claves foráneas sin índice y tablas con TRUNCATE autenticado. Ambas tablas staging tienen clave primaria.
- Las 145 vistas accesibles por authenticated aceptan consultas `LIMIT 0` sin errores de permisos después del cambio; no se consultaron registros clínicos ni se suplantó a empleados.
- Preparación técnica `true`; preparación UAT y firmas `false`; cero ejecuciones, firmas o usuarios sintéticos insertados en producción. Modo `LIVE_LIMITED`, automatización clínica desactivada. Hay 14 casos activos pendientes de aceptación formal.
- Advisors posteriores: 56 avisos de funciones SECURITY DEFINER autenticadas (entradas y ayudas intencionales sujetas a permisos), un aviso de contraseñas filtradas todavía deshabilitadas; sin avisos de vistas definer ni rutas mutables. Rendimiento conserva 242 avisos de políticas permisivas múltiples y 442 índices todavía sin uso registrado, incluidos índices nuevos sin carga observada. No confundir índices nuevos no utilizados aún con un defecto demostrado.

La puesta en marcha técnica/piloto es verificable. La aceptación clínica y la autorización formal de operación plena no se acreditan con cuentas ficticias. Antes de esa decisión siguen siendo necesarias la configuración externa de Auth, evidencia real de recuperación de respaldo y las firmas humanas descritas arriba.
