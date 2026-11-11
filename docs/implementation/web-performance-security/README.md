# Rendimiento web y seguridad · 0.56.0

## Cambios

- El arranque comprueba la sesión antes de importar el shell. Las pantallas y extensiones se importan después de autorizar la ruta. Las respuestas tardías de una navegación anterior no reemplazan la pantalla vigente.
- El grafo estático del arranque sin sesión pasa de 166 módulos / 1,28 MB de fuente a ocho módulos / aproximadamente 246 KB. El shell autorizado carga 17 módulos / aproximadamente 279 KB; el resto depende de la pantalla abierta. El SDK Supabase sigue siendo local y no se modifica js/config.js.
- Las peticiones concurrentes de contexto y permisos comparten una promesa. La caché vive solo en memoria (30 segundos para contexto/permisos; los módulos solo comparten lecturas concurrentes y se vuelven a consultar en cada navegación) y se invalida al cambiar la identidad o actualizar el token. La autorización real sigue en SQL/RLS. Salir o cambiar de identidad retira el contenido protegido del arranque y vuelve al acceso.
- El listado de donantes consulta páginas de 25 resúmenes con filtros server-side, total autorizado y orden estable. La búsqueda se difiere 250 ms y las lecturas se cancelan o descartan por generación. La ficha completa y sus antecedentes se consultan por ID. La apertura desde agenda/lector/guardado localiza la página que contiene la ficha. Anterior/Siguiente cruza los límites de página.
- Agenda y comunicaciones se cargan al abrir su sección. Consultan un conjunto completo y explícito de resúmenes autorizados; sus totales y contactos no se calculan sobre la página de 25 donantes.
- La migración añade dos índices de autor en cotizaciones y usa initPlan para auth.uid() en las dos políticas de inserción, conservando todos los permisos y condiciones. Las tablas de producción se verificaron bajo 64 KiB. La migración limita espera de bloqueo y aborta si el volumen supera 64 MiB; en ese caso corresponde programar índices concurrentes.
- CSP y política de referente en acceso, activación y aplicación. La CSP conserva Workers/WASM locales, mapas optativos y PDF descargable. No constituye frame-ancestors HTTP: esa defensa necesita alojamiento/proxy configurable. Los diagnósticos de arranque escapan texto no confiable.
- Los borradores CRM vencen a los siete días al acceder al almacenamiento y se retiran al salir. No son cifrado del disco ni una política de borrado de datos clínicos guardados. Se conserva compatibilidad con borradores anteriores con fecha y se fecha la primera lectura de formatos sin fecha.
- Aviso técnico de privacidad y reglas de uso interno accesibles desde login. La dirección debe completar el responsable legal, retención formal y canal de derechos; no se presenta la documentación técnica como aprobación legal.

## Publicación

Aplicar primero la migración `web_performance_security` en la base HEMOCURA, verificar su API y permisos, reconciliar el contrato contra metadatos reales y después publicar la interfaz. La interfaz paginada necesita esa RPC: no publicar la parte cliente por separado. Se conserva LIVE_LIMITED, sin liberar unidades, confirmar elegibilidad clínica, crear empleados ni modificar datos operativos.

## Backups privados

Se verificó la cuenta de Google Drive indicada por el propietario y se conservó su estructura existente de respaldos técnicos privados. Hay una copia histórica con informe de restauración aislada; esa evidencia no hace que una nueva copia o una automatización estén verificadas. La carpeta preparada para la nueva rutina permanece privada; su identificador se configura fuera del código publicado.

`tools/backup_hemocura.sh` exporta roles, esquema, datos e historial de migraciones mediante Supabase CLI, cifra con age y verifica por hash la lectura del objeto cifrado después de subirlo por rclone. Los archivos SQL temporales y los diagnósticos privados se retiran. No se suben dumps ni claves como artifacts de CI.

La tarea de GitHub Actions está programada a las 06:00 UTC (02:00 Santo Domingo), pero **solo queda activa cuando se configura y habilita expresamente**. No se afirma que exista una copia diaria mientras falten estas variables/secrets:

| Nombre | Tipo | Contenido |
| --- | --- | --- |
| HC_BACKUP_DB_URL | Secret | Conexión PostgreSQL autorizada para exportar. No es el token de la API de gestión. |
| HC_RCLONE_CONFIG_TEXT | Secret | Configuración OAuth/identidad de ejecución de rclone para el Drive autorizado. La conexión interactiva del plugin no suministra credenciales a GitHub Actions. |
| HC_BACKUP_REMOTE | Variable | Alias rclone y ruta de la carpeta privada de destino. |
| HC_BACKUP_AGE_RECIPIENT | Variable | Destinatario público de age. La identidad privada se conserva separada de GitHub y de las copias. |
| HC_BACKUPS_ENABLED | Variable | true solo después de una ejecución manual satisfactoria y revisión de recuperación. |

No solicitar contraseñas, claves privadas o tokens por chat. Configurarlos en Settings → Secrets and variables → Actions. Usar un ejecutor confiable y una identidad de almacenamiento dedicada, con el menor acceso posible. No utilizar credenciales de otra cuenta.

La exportación es lógica y las invocaciones separadas requieren evitar DDL concurrente. Revisar personalizaciones de auth/storage, extensiones y configuración de plataforma en el ensayo de recuperación. Los secretos de plataforma y los objetos binarios de Storage necesitan procedimientos separados; hoy no hay buckets. Una restauración se ensaya en Supabase aislado compatible, nunca sobre producción por este workflow. El manifiesto dice restore_verified=false hasta que exista evidencia externa real.

## Disponibilidad y compatibilidad

`web-uptime.yml` comprueba aplicación, acceso, bootstrap y salud de Auth cada 15 minutos. No consulta tablas clínicas ni autentica empleados. GitHub registra el fallo y sus avisos dependen de las preferencias de notificación del propietario. Las programaciones de Actions son best-effort; no equivalen a un SLA u on-call 24×7.

La CI añade Chromium, Firefox y WebKit para rendimiento, CSP, privacidad y cotizaciones. WebKit en Linux y un viewport móvil no sustituyen pruebas en Safari/iPhone físico. Se escanean los dos lockfiles existentes; este control no cubre automáticamente todas las dependencias vendorizadas ni de Edge Functions.

## Verificación

- `python tools/check_startup_budget.py`
- `node tools/web_performance_browser_runner.cjs`
- `node tools/quotations_browser_runner.cjs`
- `node tools/donors_browser_runner.cjs`
- `node tools/donors_navigation_runner.cjs`
- `node tools/workflow_browser_runner.cjs`
- `node tools/crm_browser_runner.cjs`
- `node tools/cedula_ocr_runner.cjs`
- `node tools/procurement_browser_runner.cjs`
- `python tools/quotations_postgres_runner.py` (incluye búsqueda paginada, permisos e integridad de cotizaciones).
- `python tools/workflow_postgres_runner.py --allow-external-prerequisite-fixture`
- `python tests/web-performance/test_backup_pipeline.py` (cifrado real con age y rclone local, usando exportaciones sintéticas; requiere ambas utilidades).

Los tests no crean registros de ejemplo en producción. Mantener la lista de pendientes de configuración separada de los resultados aprobados; los tests sintéticos no acreditan recuperación de datos productivos ni UAT clínica.
