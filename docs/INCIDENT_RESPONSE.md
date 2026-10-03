# Respuesta a incidentes

## Severidad
### P1
- pérdida/corrupción de datos;
- acceso no autorizado;
- RLS incorrecto;
- operación crítica bloqueada.

Acción: detener escrituras afectadas y activar rollback/contingencia.

### P2
- módulo importante no disponible;
- conciliación incorrecta;
- cálculo financiero inconsistente.

Acción: aislar módulo y continuar solo procesos seguros.

### P3
- error visual;
- filtro;
- etiqueta;
- reporte secundario.

Acción: registrar y corregir en siguiente hotfix.

## Registro mínimo
- versión;
- hora;
- usuario/rol;
- módulo;
- pasos;
- error Console;
- error Network;
- objeto Supabase;
- impacto;
- corrección;
- validación posterior.
