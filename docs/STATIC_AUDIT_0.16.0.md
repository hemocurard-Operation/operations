# HemoCura v0.16.0 — Auditoría estática

## Resultado ejecutado sobre v0.15.0

### Aprobado
- 32 archivos JavaScript revisados.
- Todos pasan `node --check`.
- No existen imports relativos rotos.
- `index.html` existe.
- `login.html` existe.
- `status.html` existe.
- `VERSION.json` existe.
- `RELEASE_MANIFEST.json` existe.
- `router.js` y `layout.js` existen.
- No se detectó registro activo de Service Worker desde JS/HTML.

### Hallazgo crítico
El paquete completo contiene `js/config.js` con:

- `https://TU-PROYECTO.supabase.co`
- `TU_CLAVE_PUBLICABLE`

Esto es correcto como plantilla de desarrollo, pero **NO es apto para despliegue directo**.

## Política desde v0.16.0

1. Si una instalación existente ya tiene `js/config.js` correcto:
   - usar `Hemocura_v0_16_0_SAFE_PATCH.zip`;
   - no reemplazar `js/config.js`.

2. Si se usa el paquete completo:
   - editar `js/config.js` antes de publicar;
   - `status.html` bloqueará el diagnóstico verde mientras detecte placeholders.

3. Nunca colocar:
   - `service_role`;
   - secretos privados;
   - claves backend en `js/config.js`.

## Resultado de auditoría
**Código estático: APROBADO.**
**Configuración del ZIP completo: REQUIERE PERSONALIZACIÓN.**
