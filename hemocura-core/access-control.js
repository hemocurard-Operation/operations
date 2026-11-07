import { accessData } from './access-data.js';
import {getSupabase} from './supabase.js';
export const ROUTE_PERMISSION={
  teamdeliveries:'DELIVERIES_VIEW',
  extratrips:'TRIPS_VIEW',
  laboratory:'SCREENING_VIEW',
  sgcimplementation:'QUALITY_VIEW',
  areaagenda:'WORK_AGENDA_VIEW',
  workflow:'WORKFLOW_VIEW',commercial:'COMMERCIAL_VIEW',commercialcalendar:'COMMERCIAL_VIEW',hyperbaric:'HYPERBARIC_VIEW',bloodquality:'QUALITY_VIEW',transfers:'BLOOD_INVENTORY_VIEW',shiftreport:'SALES_VIEW',supplycatalog:'SUPPLY_VIEW',mywork:'DASHBOARD_VIEW',dashboard:'DASHBOARD_VIEW',command:'COMMAND_VIEW',decisioncenter:'DECISION_CENTER_VIEW',predictive:'PREDICTIVE_VIEW',orchestration:'ORCHESTRATION_VIEW',quickcapture:'DASHBOARD_VIEW',audit:'AUDIT_VIEW',releasegate:'RELEASE_GATE_VIEW',sales:'SALES_VIEW',donors:'DONORS_VIEW',screening:'SCREENING_VIEW',bloodflow:'BLOOD_INVENTORY_VIEW',production:'BLOOD_INVENTORY_WRITE',supply:'SUPPLY_VIEW',bloodinventory:'BLOOD_INVENTORY_VIEW',dailyinventory:'DAILY_REPORT_VIEW',dispatches:'DISPATCH_VIEW',inventory:'BLOOD_INVENTORY_VIEW',supplytransfers:'SUPPLY_TRANSFER_VIEW',requisitions:'DISPATCH_VIEW',valuechain:'VALUE_CHAIN_VIEW',serviceperformance:'SERVICE_PERFORMANCE_VIEW',donoroutreach:'DONOR_OUTREACH_VIEW',medicalnetwork:'MEDICAL_NETWORK_VIEW',customers:'CUSTOMER_VIEW',collections:'COLLECTIONS_VIEW',economics:'ECONOMICS_VIEW',actions:'ACTIONS_VIEW',inspections:'QUALITY_VIEW',isocompliance:'ISO_COMPLIANCE_VIEW',planning:'SUPPLY_VIEW',quality:'QUALITY_VIEW',training:'TRAINING_SELF',documents:'DOCUMENTS_VIEW',compliance:'COMPLIANCE_VIEW',bi:'BI_VIEW',projects:'PROJECTS_VIEW',settings:'ADMIN_VIEW',users:'ACCESS_ADMIN',qa:'RELEASE_GATE_VIEW',security:'ACCESS_ADMIN',diagnostics:'RELEASE_GATE_VIEW',approvals:'APPROVAL_VIEW',qmsgov:'QUALITY_VIEW',internalaudits:'INTERNAL_AUDIT_VIEW',competencies:'COMPETENCY_VIEW',resources:'RESOURCES_VIEW',maintenance:'RESOURCES_VIEW',twelveweek:'PROJECTS_VIEW',congresses:'COMMERCIAL_VIEW',environmental:'RESOURCES_VIEW',analyticalqc:'ANALYTICAL_QC_VIEW',release1:'RELEASE_GATE_VIEW',uat:'RELEASE_GATE_VIEW',integration:'RELEASE_GATE_VIEW',continuity:'CONTINUITY_VIEW',management:'MANAGEMENT_REVIEW_VIEW',coldchain:'COLD_CHAIN_VIEW',transport:'COLD_CHAIN_VIEW',hemovigilance:'HEMOVIGILANCE_VIEW',suppliers:'SUPPLIERS_VIEW'
};
let cache=null,pending=null,expires=0,epoch=0,watching=false;
let modules=null,modulePending=null,moduleExpires=0;
function watchIdentity(){
 if(watching)return;
 const auth=getSupabase().auth;
 if(!auth?.onAuthStateChange)return;
 watching=true;
 auth.onAuthStateChange(event=>{
  if(['SIGNED_OUT','SIGNED_IN','USER_UPDATED','TOKEN_REFRESHED'].includes(event))resetAccessCache();
  if(event==='SIGNED_OUT')import('./crm-drafts.js').then(m=>m.clearCrmDrafts()).catch(()=>console.warn('[LOCAL_DRAFT_CLEANUP_FAILED]'));
 });
}
export async function loadAccess(){
 watchIdentity();
 if(cache&&Date.now()<expires)return cache;
 if(pending)return pending;
 const started=epoch;
 const request=Promise.all([accessData.context(),accessData.permissions()]).then(([context,rows])=>{
  const value={context,rows,permissions:new Set(rows.map(x=>x.permission_code))};
  if(started===epoch){cache=value;expires=Date.now()+30000}
  return value;
 }).finally(()=>{if(pending===request)pending=null});
 pending=request;return request;
}
export function resetAccessCache(){epoch++;cache=null;pending=null;expires=0;modules=null;modulePending=null;moduleExpires=0}
// A short in-memory window coalesces shell/navigation reads. SQL authorization is always authoritative.
export async function activeModuleKeys(){
 if(modules&&Date.now()<moduleExpires)return new Set(modules);
 if(modulePending)return new Set(await modulePending);
 const started=epoch;
 const request=accessData.modules().then(rows=>{
  const value=rows.filter(x=>x.enabled===true).map(x=>x.route_key);
  if(started===epoch){modules=value;moduleExpires=Date.now()+1000}
  return value;
 }).finally(()=>{if(modulePending===request)modulePending=null});
 modulePending=request;return new Set(await request);
}
export async function canRoute(route){const a=await loadAccess(),modules=await activeModuleKeys();const permission=ROUTE_PERMISSION[route];const allowed=!!permission&&modules.has(route)&&a.permissions.has(permission);const reason=allowed?'PERMISSION_GRANTED':permission&&!modules.has(route)?'MODULE_DISABLED_FOR_ROLE':'PERMISSION_DENIED';await accessData.log(route,permission||null,allowed,reason);return{allowed,permission:permission||'Módulo no registrado',reason,context:a.context}}
export async function filterRoutes(routeEntries){const [a,modules]=await Promise.all([loadAccess(),activeModuleKeys()]);return routeEntries.filter(([key])=>!!ROUTE_PERMISSION[key]&&modules.has(key)&&a.permissions.has(ROUTE_PERMISSION[key]))}
export function requiredPermission(route){return ROUTE_PERMISSION[route]||null}
