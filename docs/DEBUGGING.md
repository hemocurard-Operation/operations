# Diagnóstico v0.11.0

Esperado:
[HEMOCURA_ROUTER] settings
[HEMOCURA_SETTINGS] profiles
[HEMOCURA_PERMISSIONS] roles
[HEMOCURA_PRODUCTION_CONTROL]
[HEMOCURA_SETTINGS] módulo OK

Al ejecutar diagnóstico:
[HEMOCURA_DIAGNOSTICS] iniciando
[HEMOCURA_DIAGNOSTICS] finalizado

Errores:
[HEMOCURA_SETTINGS_ERROR]

Interpretación:
- profiles muestra solo el propio usuario → RLS funcionando según rol.
- app_feature_flags no existe → Producción Caliente no instalado.
- production_healthcheck no existe → paquete de control de producción no instalado.
- permission denied → revisar grant/RLS del objeto específico.
- una sola vista falla → corregir esa vista, no toda la aplicación.
