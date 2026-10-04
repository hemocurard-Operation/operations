const ROUTES={
 dashboard:{title:'Centro de Operaciones',subtitle:'Operaciones, sangre, calidad y cumplimiento'},
 command:{title:'Centro de Mando',subtitle:'Cierre diario, score y gestión por excepciones'},
 sales:{title:'Ventas / Salidas',subtitle:'Control operativo de salidas y facturación'},
 donors:{title:'Donantes',subtitle:'Donantes y donaciones efectivas'},
 screening:{title:'Tamizaje',subtitle:'Pruebas, reactivos, lotes y resultados'},
 bloodflow:{title:'Flujo Sanguíneo',subtitle:'Donación, tamizaje, liberación, inventario y salida'},
 production:{title:'Producción',subtitle:'Componentes producidos y rendimiento'},
 supply:{title:'Abastecimiento',subtitle:'Demanda, cobertura y donantes requeridos'},
 bloodinventory:{title:'Inventario de Sangre',subtitle:'Disponibilidad por componente, ABO y Rh'},
 dispatches:{title:'Despachos',subtitle:'Despacho físico y conciliación'},
 inventory:{title:'Insumos',subtitle:'Inventario de reactivos y materiales'},
 requisitions:{title:'Requisiciones',subtitle:'Solicitud y autorización de insumos'},
 inspections:{title:'Inspecciones',subtitle:'Inspección de sucursal y hallazgos'},
 planning:{title:'Planificación',subtitle:'Plan operativo y forecast SHADOW'},
 quality:{title:'SGC',subtitle:'Incidencias, NC, CAPA y alertas'},
 documents:{title:'Control Documental',subtitle:'Documentos y cambios'},
 compliance:{title:'Compliance',subtitle:'Riesgos y cumplimiento'},
 bi:{title:'Inteligencia de Negocios',subtitle:'Indicadores y análisis operativo'},
 projects:{title:'Proyectos',subtitle:'Portafolio, avance y dependencias'},
 settings:{title:'Administración',subtitle:'Usuarios, roles y diagnóstico'},
 qa:{title:'QA Técnico',subtitle:'Validación integral'}
};
export function routeList(){return Object.entries(ROUTES)}
export function getRoute(){const k=(location.hash||'#dashboard').replace('#','').split('?')[0];return ROUTES[k]?k:'dashboard'}
export function getRouteMeta(k){return ROUTES[k]||ROUTES.dashboard}
export function navigate(k){location.hash=`#${ROUTES[k]?k:'dashboard'}`}
