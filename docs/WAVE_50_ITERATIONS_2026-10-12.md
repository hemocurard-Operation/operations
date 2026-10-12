# HemoCura · Ola de 50 iteraciones

Fecha de inicio: 2026-10-12

Objetivo: ejecutar 50 iteraciones consecutivas sobre la línea actual de `main`, sin reiniciar trabajo previo ni reintroducir ramas históricas obsoletas.

## Bloque A · UX y captura (I-224–I-233)
1. I-224 UX 2: mantener un solo formulario visible por tarea.
2. I-225 Indicador de progreso de captura.
3. I-226 Resumen de campos obligatorios pendientes.
4. I-227 Prevención de pérdida de cambios no guardados.
5. I-228 Navegación segura entre formularios.
6. I-229 Mejoras de accesibilidad y foco.
7. I-230 Contexto de sucursal visible y heredado.
8. I-231 Mensajes de error accionables.
9. I-232 Optimización móvil de acciones primarias.
10. I-233 Consolidación de patrones UX en Quick Capture y Reporte Diario.

## Bloque B · Usuarios, roles y administración (I-234–I-243)
11. I-234 Filtro/búsqueda de usuarios.
12. I-235 Filtro por sucursal.
13. I-236 Filtro por rol.
14. I-237 Mostrar estado activo/confirmación/último acceso.
15. I-238 Alta por invitación como opción recomendada.
16. I-239 Alta con contraseña temporal controlada.
17. I-240 Asignación de rol adicional.
18. I-241 Retiro de rol con protección contra auto-bloqueo administrativo.
19. I-242 Activación/desactivación de usuario en Auth + profile.
20. I-243 Auditoría de acciones administrativas.

## Bloque C · Seguridad y Supabase (I-244–I-253)
21. I-244 Security Advisor baseline actual.
22. I-245 Inventario de vistas owner-privilege.
23. I-246 Clasificación de vistas por criticidad.
24. I-247 Inventario de funciones con search_path mutable.
25. I-248 Clasificación de SECURITY DEFINER por intención.
26. I-249 Gate de service_role fuera del frontend.
27. I-250 Gate de JWT obligatorio en funciones administrativas.
28. I-251 Verificación de ACCESS_ADMIN server-side.
29. I-252 Preparación de hardening por lotes, sin cambios masivos a ciegas.
30. I-253 Registro explícito de deuda de leaked-password protection.

## Bloque D · SGC / ISO 15189 y operación (I-254–I-263)
31. I-254 Conectar Mi trabajo con tareas de calidad.
32. I-255 Priorizar no conformidades/CAPA.
33. I-256 Priorizar documentos pendientes.
34. I-257 Priorizar competencias/recertificación.
35. I-258 Priorizar auditorías internas.
36. I-259 Conectar capacitación contextual con módulos.
37. I-260 Mantener segregación participante/evaluador.
38. I-261 Mantener decisiones clínicas fuera de automatización.
39. I-262 Evidencia de trazabilidad de cambios.
40. I-263 Preparar matriz de cierre operativo + SGC.

## Bloque E · QA, release y gobernanza (I-264–I-273)
41. I-264 Workflow de seguridad de Users Admin.
42. I-265 Workflow de UX progresiva.
43. I-266 Runtime Contract Gate.
44. I-267 Frontend Source of Truth.
45. I-268 Quick Capture Safety.
46. I-269 Daily Report Safety.
47. I-270 Training Native Safety.
48. I-271 Verificación de PR sin deuda histórica abierta.
49. I-272 Consolidación del reporte de 50 iteraciones.
50. I-273 Gate final de esta ola: merge solo si CI queda verde.

## Criterio de cierre
Una iteración se considera `DONE` cuando el cambio está implementado o la validación está registrada. Las acciones de alto riesgo en producción pueden cerrar como `PREPARED/BLOCKED_BY_SAFETY` cuando aplicar el cambio sin validación adicional pueda degradar RLS, Auth, trazabilidad o procesos clínicos.
