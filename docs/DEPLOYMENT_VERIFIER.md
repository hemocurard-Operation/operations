# Deployment Verifier — v0.15.0

## URL
`https://hemocurard-operation.github.io/operations/status.html`

## No depende de
- login;
- sesión Supabase;
- RLS;
- tablas;
- vistas;
- RPC.

## Comprueba
- status.html
- VERSION.json
- RELEASE_MANIFEST.json
- index.html
- login.html
- CSS
- app.js
- login.js
- bootstrap.js
- layout.js
- router.js
- supabase.js

Todas las peticiones utilizan `cache: no-store` y query anti-cache.

## Interpretación
### status.html no abre
Problema de GitHub Pages, repo, publicación o ruta.

### status.html abre pero index.html da error
Despliegue incompleto.

### JS 404
Ruta/archivo incorrecto.

### Todo OK y app no inicia
Revisar:
- Supabase URL/key;
- Auth;
- RLS;
- Console;
- Network.
