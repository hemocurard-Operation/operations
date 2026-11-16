// Presentation taxonomy only. Callers must pass entries already authorized by
// filterRoutes/canRoute; grouping never grants data permissions or activates a route.
const moduleDefinition=(id,title,description,icon,routeKeys)=>Object.freeze({id,title,description,icon,routeKeys:Object.freeze(routeKeys)});
export const OPERATIONS_MODULES=Object.freeze([
 moduleDefinition('inventario','Inventario','Existencias, laboratorio, insumos, requisiciones y abastecimiento.','package',[
  'bloodinventory','inventory','supplycatalog','requisitions','suppliers','supply','planning','operationsoutlook','sales','laboratory','screening','production','bloodflow','resources','maintenance','cleaning','environmental','dailyinventory'
 ]),
 moduleDefinition('logistica','Logística','Viajes, entregas, traslados y cadena de frío.','truck',[
  'extratrips','teamdeliveries','dispatches','transfers','supplytransfers','coldchain','transport'
 ]),
 moduleDefinition('calidad','Sistema de Gestión de la Calidad','No conformidades, CAPA, documentos, formación y revisión.','badge-check',[
  'sgcimplementation','quality','bloodquality','analyticalqc','actions','isocompliance','approvals','qmsgov','internalaudits','inspections','training','competencies','documents','hemovigilance','management','projects','continuity'
 ]),
 moduleDefinition('compliance','Compliance · leyes dominicanas','Matriz normativa, habilitaciones, evidencias y vigencias.','scale',[
  'regulatorymatrix','licenses','compliance'
 ]),
 moduleDefinition('donantes','Donantes','Registros, agenda de donación, captación y seguimiento.','heart-handshake',[
  'donors','donoroutreach'
 ]),
 moduleDefinition('comercial','Comercial','Centros, visitas, servicios, oportunidades y análisis operativo.','handshake',[
  'commercial','commercialcalendar','commercialgoals','customers','medicalnetwork','congresses','hyperbaric','twelveweek','valuechain','serviceperformance','bi','predictive'
 ]),
 moduleDefinition('finanzas','Finanzas','Reportes de unidades vendidas, comparativos y actividad por centro.','chart-no-axes-combined',[
  'economics','shiftreport','collections'
 ])
]);
export const OPERATIONS_GENERAL_ROUTES=Object.freeze(['mywork','dashboard','workflow','quickcapture','areaagenda','command','decisioncenter','orchestration']);
export const OPERATIONS_UTILITY_ROUTES=Object.freeze(['settings','userworkspaces','users','security','diagnostics','audit','uat','integration','releasegate','release1','qa']);
// These source-only drafts have no active access contract and must not appear
// just because a caller supplies their old router metadata.
export const OPERATIONS_DEFERRED_ROUTES=Object.freeze(['payables','budgets']);
const routeModule=new Map(OPERATIONS_MODULES.flatMap(module=>module.routeKeys.map(key=>[key,module])));
const general=new Set(OPERATIONS_GENERAL_ROUTES),utilities=new Set(OPERATIONS_UTILITY_ROUTES);
export function moduleForRoute(routeKey){return routeModule.get(routeKey)||null}
export function navigationForRoute(routeKey){return moduleForRoute(routeKey)?.id||(general.has(routeKey)?'general':utilities.has(routeKey)?'utilities':null)}
export function operationsNavigation(authorizedEntries=[]){
 const unique=new Map();for(const entry of authorizedEntries){if(!Array.isArray(entry)||entry.length<2||typeof entry[0]!=='string'||!entry[1]||typeof entry[1]!=='object')continue;if(navigationForRoute(entry[0])&&!unique.has(entry[0]))unique.set(entry[0],entry)}
 const entries=[...unique.values()];
 return {modules:OPERATIONS_MODULES.map(module=>({...module,entries:module.routeKeys.filter(key=>unique.has(key)).map(key=>unique.get(key))})).filter(module=>module.entries.length),general:entries.filter(([key])=>general.has(key)),utilities:entries.filter(([key])=>utilities.has(key))};
}
