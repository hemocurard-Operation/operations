# HemoCura v0.45 · Cinco iteraciones de cierre

1. **Modelo de acceso y roles**: creación de ASISTENTE_OPERACIONES, SUPER_USUARIO, MEDICO_GERENTE_TECNICO y SOCIO; ENCARGADA_LABORATORIO ya existía y se conserva.
2. **Navegación lateral**: menú reorganizado por flujo de trabajo, grupos plegables, búsqueda de módulos y etiqueta de experiencia por rol.
3. **Dashboard por rol**: accesos rápidos y prioridades diferentes para laboratorio, operaciones, gerencia, socio, administración y médico/gerente técnico.
4. **Formularios guiados**: Donantes, Tamizaje y Producción priorizan selects/datalist, autocompletado con datos recientes y menos texto libre.
5. **QA y despliegue**: VERSION 0.45.0, smoke de rutas/UX por rol y despliegue por PR + GitHub Pages.

## Dependencia no resuelta automáticamente

La creación de cuentas reales para `MEDICO_GERENTE_TECNICO` y `SOCIO` requiere correo/login real y alta mediante Supabase Auth. No se insertan registros manualmente en `auth.users` ni se generan credenciales ficticias.

## Seguridad C13-C2B

El script `sql/C13C2B_01_LEGACY_RPC_CUTOVER.sql` queda versionado como candidato. Su aplicación desde la herramienta fue bloqueada por controles de seguridad; por tanto no se marca como instalado.
