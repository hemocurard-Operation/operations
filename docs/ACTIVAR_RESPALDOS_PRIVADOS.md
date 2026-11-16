# Activar y verificar respaldos privados

La automatización existente exporta la base de datos, cifra con age, envía a un destino privado con rclone y vuelve a leer el archivo cifrado para comparar su hash. La copia no incluye los archivos físicos de Storage ni las claves de la plataforma. Una copia válida tampoco demuestra por sí sola que se pueda restaurar.

Verificación de esta entrega: las dos últimas ejecuciones programadas consultadas estaban omitidas. El entorno de trabajo no tiene las cuatro configuraciones siguientes. No se ha declarado una copia ni una restauración exitosas.

## Configuración requerida

En [Settings → Secrets and variables → Actions](https://github.com/hemocurard-Operation/operations/settings/secrets/actions):

| Tipo | Nombre | Contenido esperado |
|---|---|---|
| Secret | `HC_BACKUP_DB_URL` | Conexión privada autorizada para exportar la base de datos. |
| Secret | `HC_RCLONE_CONFIG_TEXT` | Configuración privada de rclone con acceso al destino elegido. |
| Variable | `HC_BACKUP_REMOTE` | Nombre del remoto y carpeta o bucket privado. Un correo electrónico no basta. |
| Variable | `HC_BACKUP_AGE_RECIPIENT` | Destinatario público de cifrado age. La identidad privada debe conservarse por separado. |

Nunca enviar estas credenciales al chat, al repositorio ni a registros públicos.

## Cierre verificable

1. Identificar el servicio y la carpeta/bucket; confirmar que no sean públicos y quién puede recuperar las copias.
2. Configurar los cuatro ajustes anteriores.
3. Ejecutar manualmente `Private encrypted database backup` desde Actions. El preflight identifica solo los nombres de ajustes ausentes, nunca sus valores.
4. Confirmar la copia cifrada, lectura remota y coincidencia de hash.
5. Restaurar una copia en un destino de ensayo aislado autorizado; cotejar esquema, historial de migraciones y registros. Nunca restaurar sobre producción para probar.
6. Documentar fecha, copia usada, resultado y responsable; comprobar también la recuperación de Storage y de la configuración de plataforma mediante sus procedimientos separados.
7. Tras la copia y revisión de recuperación satisfactorias, activar la variable `HC_BACKUPS_ENABLED=true` y verificar una ejecución programada.

La firma médica de reglas de donación y la revisión legal de requisitos son procesos distintos y no deben marcarse como realizados por habilitar respaldos o desplegar tablas.
