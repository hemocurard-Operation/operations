# HemoCura — Rollback

## Frontend
1. Identificar último commit/tag estable.
2. Restaurar archivos de esa versión.
3. Esperar GitHub Pages.
4. Abrir DevTools → Application.
5. Si hay caché antigua, limpiar site data / Service Worker.
6. Validar login y módulo afectado.

## Base de datos
El rollback del frontend NO revierte datos ni migraciones SQL.

Para base de datos:
- detener escrituras si hay riesgo de integridad;
- identificar migración/cambio;
- usar backup/restauración o script SQL de reversión previamente validado;
- documentar el incidente.

Nunca improvisar una reversión SQL sobre producción sin respaldo.
