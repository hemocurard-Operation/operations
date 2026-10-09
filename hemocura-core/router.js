const GROUP_ORDER=['INICIO','TRABAJO DIARIO','LABORATORIO Y SANGRE','CALIDAD Y SEGURIDAD','GESTIÓN','ADMINISTRACIÓN'];
const ROUTES={
  dashboard:{title:'Inicio',subtitle:'Resumen priorizado según tu rol',group:'INICIO',order:10},
  command:{title:'Centro de Mando',subtitle:'Cierre diario, score y excepciones',group:'INICIO',order:20},

  quickcapture:{title:'Captura rápida',subtitle:'Donantes, tamizaje, requisiciones, despachos e incidencias en formularios simples',group:'TRABAJO DIARIO',order:5},
  dispatches:{title:'Despachos',subtitle:'Despacho físico y conciliación',group:'TRABAJO DIARIO',order:10},
  requisitions:{title:'Requisiciones',subtitle:'Solicitud y autorización de insumos',group:'TRABAJO DIARIO',order:20},
  sales:{title:'Ventas / Salidas',subtitle:'Salidas y facturación operativa',group:'TRABAJO DIARIO',order:30},
  inventory:{title:'Insumos',subtitle:'Inventario de reactivos y materiales',group:'TRABAJO DIARIO',order:40},
  supply:{title:'Abastecimiento',subtitle:'Demanda, cobertura y donantes requeridos',group:'TRABAJO DIARIO',order:50},
  planning:{title:'Planificación',subtitle:'Plan operativo y forecast SHADOW',group:'TRABAJO DIARIO',order:60},

  donors:{title:'Donantes',subtitle:'Captura y revisión humana de donantes',group:'LABORATORIO Y SANGRE',order:10},
  screening:{title:'Tamizaje',subtitle:'Pruebas, reactivos, lotes y resultados',group:'LABORATORIO Y SANGRE',order:20},
  production:{title:'Producción',subtitle:'Componentes producidos y rendimiento',group:'LABORATORIO Y SANGRE',order:30},
  bloodinventory:{title:'Inventario de Sangre',subtitle:'Disponibilidad por componente, ABO y Rh',group:'LABORATORIO Y SANGRE',order:40},
  bloodflow:{title:'Flujo Sanguíneo',subtitle:'Donación, tamizaje, liberación, inventario y salida',group:'LABORATORIO Y SANGRE',order:50},
  analyticalqc:{title:'Calidad Analítica',subtitle:'Métodos, IQC, desviaciones y EQA/PT',group:'LABORATORIO Y SANGRE',order:60},
  coldchain:{title:'Cadena de Frío',subtitle:'Almacenamiento, transporte y excursiones',group:'LABORATORIO Y SANGRE',order:70},
  hemovigilance:{title:'Hemovigilancia',subtitle:'Eventos adversos, casi eventos y retiros',group:'LABORATORIO Y SANGRE',order:80},
  resources:{title:'Recursos Críticos',subtitle:'Equipos, reactivos y ambiente',group:'LABORATORIO Y SANGRE',order:90},

  quality:{title:'SGC',subtitle:'Incidencias, NC, CAPA y alertas',group:'CALIDAD Y SEGURIDAD',order:10},
  approvals:{title:'Aprobaciones',subtitle:'Segregación de funciones y decisiones',group:'CALIDAD Y SEGURIDAD',order:20},
  qmsgov:{title:'Gobierno QMS',subtitle:'Documentos, CAPA y aprobaciones',group:'CALIDAD Y SEGURIDAD',order:30},
  internalaudits:{title:'Auditorías Internas',subtitle:'Programa, hallazgos y evidencia',group:'CALIDAD Y SEGURIDAD',order:40},
  inspections:{title:'Inspecciones',subtitle:'Inspección de sucursal y hallazgos',group:'CALIDAD Y SEGURIDAD',order:50},
  competencies:{title:'Competencias',subtitle:'Puestos, capacitación y brechas',group:'CALIDAD Y SEGURIDAD',order:60},
  documents:{title:'Control Documental',subtitle:'Documentos y cambios',group:'CALIDAD Y SEGURIDAD',order:70},
  compliance:{title:'Compliance',subtitle:'Riesgos y cumplimiento',group:'CALIDAD Y SEGURIDAD',order:80},

  bi:{title:'Inteligencia de Negocios',subtitle:'Indicadores y análisis operativo',group:'GESTIÓN',order:10},
  management:{title:'Revisión Dirección',subtitle:'Objetivos, riesgos y seguimiento',group:'GESTIÓN',order:20},
  projects:{title:'Proyectos',subtitle:'Portafolio, avance y dependencias',group:'GESTIÓN',order:30},
  continuity:{title:'Continuidad',subtitle:'Continuidad operativa e integridad de datos',group:'GESTIÓN',order:40},
  suppliers:{title:'Proveedores',subtitle:'Compras críticas y evaluación',group:'GESTIÓN',order:50},

  settings:{title:'Configuración',subtitle:'Usuarios, roles y catálogos',group:'ADMINISTRACIÓN',order:10},
  security:{title:'Seguridad y Acceso',subtitle:'Roles, permisos, sucursal y RLS',group:'ADMINISTRACIÓN',order:20},
  diagnostics:{title:'Diagnóstico',subtitle:'Configuración, Auth, RLS y migraciones',group:'ADMINISTRACIÓN',order:30},
  audit:{title:'Auditoría del Sistema',subtitle:'Trazabilidad y revisión del proyecto',group:'ADMINISTRACIÓN',order:40},
  uat:{title:'Validación UAT',subtitle:'Pruebas de aceptación',group:'ADMINISTRACIÓN',order:50},
  integration:{title:'Integración',subtitle:'Validación end-to-end',group:'ADMINISTRACIÓN',order:60},
  releasegate:{title:'Release Gate',subtitle:'Schema, migraciones y despliegue',group:'ADMINISTRACIÓN',order:70},
  release1:{title:'Release 1.0',subtitle:'Gate final de liberación',group:'ADMINISTRACIÓN',order:80},
  qa:{title:'QA Técnico',subtitle:'Validación integral',group:'ADMINISTRACIÓN',order:90}
};
export function routeList(){
  return Object.entries(ROUTES).sort((a,b)=>{
    const ga=GROUP_ORDER.indexOf(a[1].group),gb=GROUP_ORDER.indexOf(b[1].group);
    return (ga-gb)||((a[1].order||999)-(b[1].order||999))||a[1].title.localeCompare(b[1].title);
  });
}
export function routeGroups(){return [...GROUP_ORDER]}
export function getRoute(){const k=(location.hash||'#dashboard').replace('#','').split('?')[0];return ROUTES[k]?k:'dashboard'}
export function getRouteMeta(k){return ROUTES[k]||ROUTES.dashboard}
export function navigate(k){location.hash=`#${ROUTES[k]?k:'dashboard'}`}
