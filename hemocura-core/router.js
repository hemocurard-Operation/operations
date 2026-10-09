const GROUP_ORDER=['INICIO','OPERACIÓN','CALIDAD','GERENCIA','ADMINISTRACIÓN','SISTEMA'];
const ROUTES={
  dashboard:{title:'Mi trabajo',subtitle:'Tareas frecuentes, pendientes y estado operativo',group:'INICIO',order:10},
  command:{title:'Centro de Mando',subtitle:'Cierre diario, score y gestión por excepciones',group:'INICIO',order:20},

  donors:{title:'Donantes',subtitle:'Donantes y donaciones efectivas',group:'OPERACIÓN',order:10},
  screening:{title:'Tamizaje',subtitle:'Pruebas, reactivos, lotes y resultados',group:'OPERACIÓN',order:20},
  bloodflow:{title:'Flujo Sanguíneo',subtitle:'Donación, tamizaje, liberación, inventario y salida',group:'OPERACIÓN',order:30},
  production:{title:'Producción',subtitle:'Componentes producidos y rendimiento',group:'OPERACIÓN',order:40},
  supply:{title:'Abastecimiento',subtitle:'Demanda, cobertura y donantes requeridos',group:'OPERACIÓN',order:45},
  bloodinventory:{title:'Inventario de Sangre',subtitle:'Disponibilidad por componente, ABO y Rh',group:'OPERACIÓN',order:50},
  dispatches:{title:'Despachos',subtitle:'Despacho físico y conciliación',group:'OPERACIÓN',order:60},
  inventory:{title:'Insumos',subtitle:'Inventario de reactivos y materiales',group:'OPERACIÓN',order:70},
  requisitions:{title:'Requisiciones',subtitle:'Solicitud y autorización de insumos',group:'OPERACIÓN',order:80},
  planning:{title:'Planificación',subtitle:'Plan operativo y forecast SHADOW',group:'OPERACIÓN',order:90},
  sales:{title:'Ventas / Salidas',subtitle:'Control operativo de salidas y facturación',group:'OPERACIÓN',order:100},

  incidents:{title:'Reportar Incidencia',subtitle:'Captura simple de eventos para seguimiento de Calidad',group:'CALIDAD',order:5},
  quality:{title:'SGC',subtitle:'Incidencias, NC, CAPA y alertas',group:'CALIDAD',order:10},
  approvals:{title:'Aprobaciones',subtitle:'Segregación de funciones y firma operativa',group:'CALIDAD',order:20},
  qmsgov:{title:'Gobierno QMS',subtitle:'Documentos, CAPA y aprobaciones',group:'CALIDAD',order:30},
  internalaudits:{title:'Auditorías Internas',subtitle:'Programa anual, hallazgos y evidencia',group:'CALIDAD',order:40},
  competencies:{title:'Competencias',subtitle:'Puestos, capacitación, evaluación y brechas',group:'CALIDAD',order:50},
  resources:{title:'Recursos Críticos',subtitle:'Equipos, reactivos y condiciones ambientales',group:'CALIDAD',order:60},
  analyticalqc:{title:'Calidad Analítica',subtitle:'Métodos, IQC, desviaciones y EQA/PT',group:'CALIDAD',order:70},
  coldchain:{title:'Cadena de Frío',subtitle:'Almacenamiento, transporte y excursiones',group:'CALIDAD',order:80},
  hemovigilance:{title:'Hemovigilancia',subtitle:'Eventos adversos, casi eventos y retiros',group:'CALIDAD',order:90},
  inspections:{title:'Inspecciones',subtitle:'Inspección de sucursal y hallazgos',group:'CALIDAD',order:100},
  documents:{title:'Control Documental',subtitle:'Documentos y cambios',group:'CALIDAD',order:110},
  compliance:{title:'Compliance',subtitle:'Riesgos y cumplimiento',group:'CALIDAD',order:120},

  management:{title:'Revisión Dirección',subtitle:'Objetivos, riesgos y seguimiento',group:'GERENCIA',order:10},
  continuity:{title:'Continuidad',subtitle:'Continuidad operativa e integridad de datos',group:'GERENCIA',order:20},
  bi:{title:'Inteligencia de Negocios',subtitle:'Indicadores y análisis operativo',group:'GERENCIA',order:30},
  projects:{title:'Proyectos',subtitle:'Portafolio, avance y dependencias',group:'GERENCIA',order:40},

  suppliers:{title:'Proveedores',subtitle:'Compras críticas y evaluación',group:'ADMINISTRACIÓN',order:10},
  settings:{title:'Administración',subtitle:'Usuarios, roles y diagnóstico',group:'ADMINISTRACIÓN',order:20},
  security:{title:'Seguridad y Acceso',subtitle:'Roles, permisos, sucursal y RLS',group:'ADMINISTRACIÓN',order:30},

  diagnostics:{title:'Diagnóstico',subtitle:'Configuración, red, Auth, perfil, RLS y migraciones',group:'SISTEMA',order:10},
  audit:{title:'Auditoría',subtitle:'Trazabilidad, candidatos y revisión semanal',group:'SISTEMA',order:20},
  uat:{title:'Validación UAT',subtitle:'Pruebas de aceptación y liberación',group:'SISTEMA',order:30},
  integration:{title:'Integración',subtitle:'Validación funcional end-to-end',group:'SISTEMA',order:40},
  releasegate:{title:'Release Gate',subtitle:'Configuración, schema, migraciones y despliegue',group:'SISTEMA',order:50},
  release1:{title:'Release 1.0',subtitle:'Gate final de liberación',group:'SISTEMA',order:60},
  qa:{title:'QA Técnico',subtitle:'Validación integral',group:'SISTEMA',order:70}
};
export function routeList(){return Object.entries(ROUTES).sort((a,b)=>{const ga=GROUP_ORDER.indexOf(a[1].group),gb=GROUP_ORDER.indexOf(b[1].group);return (ga-gb)||((a[1].order||999)-(b[1].order||999))||a[1].title.localeCompare(b[1].title)})}
export function routeGroups(){return [...GROUP_ORDER]}
export function getRoute(){const k=(location.hash||'#dashboard').replace('#','').split('?')[0];return ROUTES[k]?k:'dashboard'}
export function getRouteMeta(k){return ROUTES[k]||ROUTES.dashboard}
export function navigate(k){location.hash=`#${ROUTES[k]?k:'dashboard'}`}
