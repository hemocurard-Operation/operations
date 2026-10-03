# HemoCura — Go-Live Runbook

## 1. Antes del despliegue
1. Confirmar backup de Supabase.
2. Confirmar export adicional de datos críticos si aplica.
3. Confirmar commit/tag estable.
4. Ejecutar `#qa`.
5. Resolver fallos críticos.
6. Revisar RLS.
7. Confirmar Clinical Core SHADOW/BLOCKED.
8. Confirmar operación paralela si aplica.

## 2. Despliegue
1. Subir versión aprobada a GitHub.
2. Esperar publicación de GitHub Pages.
3. Abrir `/operations/`.
4. Validar versión visible.
5. Login.
6. Dashboard.
7. Ventas.
8. Despachos.
9. Inventario.
10. Costos.
11. Calidad.
12. Planificación.
13. Configuración.
14. `#qa`.
15. `#release`.

## 3. Criterio de detención
Detener despliegue si:
- login falla;
- RLS expone sucursal no autorizada;
- escritura incorrecta;
- totales se alteran;
- inventario no concilia;
- una migración faltante bloquea operación.

## 4. Post-Go-Live
Ejecutar validación al inicio, después de primeras transacciones y al cierre del día.
