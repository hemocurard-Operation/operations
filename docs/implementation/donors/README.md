# Distribución del módulo de donantes · 13 de octubre de 2026

La ruta existente `#donors` presenta identificación e historial a la izquierda, agenda y seguimiento a la derecha. La búsqueda admite nombre, código y cédula con o sin separadores. Los registros anteriores sin identificación muestran «Sin registrar» y pueden completarse sin perder su ID ni las donaciones asociadas.

Se agregan nombre, cédula normalizada de once dígitos, sexo, teléfono y canal preferido. El historial consulta `donations` por `donor_id`, sin generar donaciones desde una asistencia. Las anotaciones de laboratorio y contactos son registros inmutables con fecha y responsable establecidos por el servidor. Las visitas pueden confirmarse, reprogramarse, marcar asistencia/inasistencia y cancelarse. Solo se permite una visita activa por donante. Reprogramar conserva la fecha/centro/estado anterior y el responsable de cada cambio; las actualizaciones comprueban revisión para evitar sobreescritura simultánea.

Permisos: `DONORS_VIEW` para leer; `DONORS_WRITE` para ficha/contactos/agenda; `SCREENING_WRITE` para comentarios de laboratorio. RLS comprueba perfil activo, sucursal y donante asociado. El guard clínico existente se conserva. Nuevas fichas ingresan con estado `PENDIENTE`; gestionar una visita no cambia elegibilidad, donación efectiva ni inventario. No se envían llamadas, mensajes o recordatorios automáticamente.

Migración aditiva: `supabase/migrations/20261013183215_donor_management.sql`. Creada mediante CLI oficial y sincronizada con la versión registrada por Supabase al aplicarla. Se verificó primero en PostgreSQL 17 aislado, luego en transacción con rollback sobre el esquema real antes de la aplicación. La verificación posterior confirmó cinco columnas nuevas, tres tablas con RLS, acceso anónimo denegado y conservación del trigger clínico; ningún registro de donante o donación fue reescrito.

Validación: 23 comprobaciones SQL (con helpers de autorización simulados, sin producción) y 17 de navegador con SDK ficticio, incluido flujo de alta/edición/contacto/reprogramación, aislamiento del historial, escape de texto, rol de lectura y móvil de 390 px. No se inició sesión con una cuenta real ni se ingresaron pacientes ficticios a producción. El asesor de seguridad no identificó hallazgos para los nuevos objetos; los avisos existentes del proyecto quedan fuera de esta modificación.

Repetir pruebas:

```sh
python tools/donors_postgres_runner.py
npm ci --prefix tests/wave50
node tools/donors_browser_runner.cjs
```

El runner de PostgreSQL requiere Docker local y utiliza un contenedor desechable sin red. El navegador usa Chromium del sistema, `HEMOCURA_BROWSER` o el Chromium de Playwright instalado. La CI ejecuta ambos.
