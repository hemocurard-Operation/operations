# HemoCura 0.2.0 — Supabase + Auth

## Archivos que cambian

- `index.html`
- `login.html`
- `css/app.css`
- `js/app.js`
- `js/login.js`
- `js/config.js`
- `hemocura-core/bootstrap.js`
- `hemocura-core/supabase.js`
- `hemocura-core/auth.js`
- `VERSION.json`

## Implementación en github.com

1. Subir/reemplazar los archivos del paquete.
2. Editar `js/config.js`.
3. Reemplazar:
   - `SUPABASE_URL`
   - `SUPABASE_PUBLISHABLE_KEY`
4. Guardar/commit.
5. Abrir `/operations/login.html`.
6. El estado debe decir: `Supabase conectado. Ingrese sus credenciales.`
7. Iniciar sesión con un usuario existente en Supabase Auth.
8. Debe redirigir a `/operations/` y mostrar `Sesión iniciada`.

## Diagnóstico

### Si muestra "Configuración pendiente"
El problema está en `js/config.js`.

### Si muestra "Error conectando con Supabase"
Revisar F12 → Console / Network y las credenciales públicas.

### Si dice "Invalid login credentials"
Supabase está conectado; revisar usuario/contraseña.

### Si login funciona pero vuelve a login
Revisar almacenamiento/cookies del navegador y Console.

## Regla

No continuar a Dashboard v0.3.0 hasta que:
- Supabase conecte.
- Login funcione.
- Logout funcione.
- La sesión sobreviva a recargar la página.
