# HemoCura v0.30.0

## Importante sobre config.js
No es necesario cambiar inmediatamente el `validateConfig()` productivo.
v0.30 introduce un adaptador que acepta:
- formato antiguo: array de problemas;
- formato futuro: objeto `{ok, problems, notes}`.

## Instalación
1. Subir SAFE PATCH sobre v0.29.0.
2. NO tocar `js/config.js`.
3. Ejecutar `sql/30_UNIFIED_DIAGNOSTICS_v0_30.sql`.
4. Abrir `deployment-check.html`.
5. Probar login.
6. Abrir `#diagnostics`.
7. Corregir errores en el orden mostrado.
8. Ejecutar `#releasegate`.
9. Ejecutar `#qa`.
