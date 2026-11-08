# Agentes de mejora · 0.58.0

En Orquestación y Resiliencia se añaden seis agentes de apoyo: abastecimiento/merma, proveedores, cobranza, calidad/cumplimiento, servicios/coordinación y calidad de información. Son evaluadores deterministas basados en reglas, no un modelo de IA externo ni procesos autónomos en un servidor.

Se evalúan al abrir la pantalla usando la consulta actual y al pulsar Actualizar y evaluar. Los cinco primeros ordenan las señales existentes de vw_orchestration_priority_queue por dominio, prioridad y fecha; el de información identifica scores inferiores a 80/100 o no evaluables en vw_data_quality_readiness. Cada hallazgo muestra clave, fuente, evidencia, recomendación y alcance. Las claves se deduplican y los dominios nuevos se conservan en coordinación. No se inventan indicadores de SLA, ahorros ni decisiones clínicas.

Se respeta la sesión, RLS, módulos habilitados y permisos existentes. El acceso al módulo relacionado se comprueba de nuevo al navegar. No se añaden SQL, permisos ni credenciales. No se modifican precios, existencias, cuentas, cobros o decisiones clínicas y no se envían datos a un proveedor de IA. El seguimiento y cualquier escritura continúan en los módulos operativos con revisión humana.

La consulta existente de Orquestación conserva hasta 300 registros por fuente y ahora ejecuta sus siete lecturas en paralelo. La interfaz declara el muestreo y advierte cuando alcanza el límite; sin hallazgos no significa ausencia de riesgos fuera de la muestra. Ante una evaluación fallida se retiran los hallazgos anteriores. No hay ejecución programada, historial persistente ni cobertura de módulos que no tengan señales en estas fuentes.

Validación con datos ficticios: siete casos de reglas y catorce verificaciones de navegador (dominios, evidencia, filtros, actualización, fallos, escape HTML, límites, permisos, móvil y ausencia de escrituras). CI Chromium, Firefox y WebKit. La liberación clínica permanece bajo control humano.
