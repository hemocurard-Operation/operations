import { accessData } from './access-data.js';

const ROUTE_PERMISSION={
  dashboard:'DASHBOARD_VIEW',
  command:'COMMAND_VIEW',
  quickcapture:'DASHBOARD_VIEW',
  audit:'AUDIT_VIEW',
  releasegate:'RELEASE_GATE_VIEW',
  sales:'SALES_VIEW',
  donors:'DONORS_VIEW',
  screening:'SCREENING_VIEW',
  bloodflow:'BLOOD_INVENTORY_VIEW',
  production:'BLOOD_INVENTORY_WRITE',
  supply:'SUPPLY_VIEW',
  bloodinventory:'BLOOD_INVENTORY_VIEW',
  dispatches:'DISPATCH_VIEW',
  inventory:'BLOOD_INVENTORY_VIEW',
  requisitions:'DISPATCH_VIEW',
  inspections:'QUALITY_VIEW',
  planning:'SUPPLY_VIEW',
  quality:'QUALITY_VIEW',
  documents:'DOCUMENTS_VIEW',
  compliance:'COMPLIANCE_VIEW',
  bi:'BI_VIEW',
  projects:'PROJECTS_VIEW',
  settings:'ADMIN_VIEW',
  qa:'RELEASE_GATE_VIEW',
  security:'ACCESS_ADMIN',
  diagnostics:'RELEASE_GATE_VIEW',
  approvals:'APPROVAL_VIEW',
  qmsgov:'QUALITY_VIEW',
  internalaudits:'INTERNAL_AUDIT_VIEW',
  competencies:'COMPETENCY_VIEW',
  resources:'RESOURCES_VIEW',
  analyticalqc:'ANALYTICAL_QC_VIEW',
  release1:'RELEASE_GATE_VIEW',
  uat:'RELEASE_GATE_VIEW',
  integration:'RELEASE_GATE_VIEW',
  continuity:'CONTINUITY_VIEW',
  management:'MANAGEMENT_REVIEW_VIEW',
  coldchain:'COLD_CHAIN_VIEW',
  hemovigilance:'HEMOVIGILANCE_VIEW',
  suppliers:'SUPPLIERS_VIEW'
};

let cache=null;

export async function loadAccess(){
  if(cache) return cache;
  const [context,rows]=await Promise.all([
    accessData.context(),
    accessData.permissions()
  ]);
  const permissions=new Set(rows.map(x=>x.permission_code));
  cache={context,rows,permissions};
  console.info('[HEMOCURA_ACCESS] loaded',context?.email,[...permissions]);
  return cache;
}

export function resetAccessCache(){cache=null}

export async function canRoute(route){
  const a=await loadAccess();
  const permission=ROUTE_PERMISSION[route] || 'DASHBOARD_VIEW';
  const allowed=a.permissions.has(permission);
  await accessData.log(route,permission,allowed,allowed?'PERMISSION_GRANTED':'PERMISSION_DENIED');
  return {allowed,permission,context:a.context};
}

export async function filterRoutes(routeEntries){
  const a=await loadAccess();
  return routeEntries.filter(([key])=>{
    const permission=ROUTE_PERMISSION[key]||'DASHBOARD_VIEW';
    return a.permissions.has(permission);
  });
}

export function requiredPermission(route){return ROUTE_PERMISSION[route]||'DASHBOARD_VIEW'}
