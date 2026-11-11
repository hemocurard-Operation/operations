// Unifies existing scheduling sources, including the gated CRM map agenda,
// without copying events or creating a parallel scheduling table. Preserves
// legacy sources:
// commercial_visits (client visits, already in
// workflow-data.js), projects with domain='COMERCIAL' (product launches,
// already in blood-operations-data.js), and medical_referral_events with a
// future referral_date (specialist activities, already in
// medical-network-data.js — referral_date defaults to today but nothing
// stops scheduling it ahead).
import {workflowData} from './workflow-data.js';
import {bloodData} from './blood-operations-data.js';
import {loadMedicalNetwork,createReferral} from './medical-network-data.js';
import {getSupabase} from './supabase.js';

export async function loadCommercialCalendar(branchId){
  const results=await Promise.allSettled([
    workflowData.visits(branchId),workflowData.customers(),bloodData.projects(),
    loadMedicalNetwork(),loadActivities(branchId),loadMapAgenda(branchId)
  ]);
  const labels=['visitas a clientes','clientes','lanzamientos','especialistas','actividades con especialistas'];
  const warnings=[];
  const value=(index,fallback)=>{
    const result=results[index];
    if(result.status==='fulfilled')return result.value;
    warnings.push(`No se pudieron cargar ${labels[index]}. ${result.reason?.message||'Error de conexión.'}`);
    return fallback;
  };
  const visits=value(0,[]),customers=value(1,[]),projects=value(2,[]),network=value(3,{network:[]}),activities=value(4,[]);
  let mapAgenda={enabled:null,visits:[],error:''};
  if(results[5].status==='fulfilled')mapAgenda=results[5].value;
  else mapAgenda.error='No se pudieron cargar visitas del mapa. '+(results[5].reason?.message||'Error de conexión.');
  if(mapAgenda.error)warnings.push(mapAgenda.error);
  return {visits,customers,launches:projects.filter(p=>p.domain==='COMERCIAL'),referrers:network.network||[],activities,
    crmVisits:mapAgenda.enabled===true?mapAgenda.visits:[],crmAgendaEnabled:mapAgenda.enabled,crmAgendaError:mapAgenda.error||'',warnings};
}

async function loadMapAgenda(branchId){
  const {data,error}=await getSupabase().rpc('commercial_agenda',{p_branch:branchId});
  if(error)throw Error(error.message);
  if(!data||typeof data.enabled!=='boolean'||!Array.isArray(data.visits))throw Error('Respuesta incompleta del origen CRM.');
  return {enabled:data.enabled,visits:data.enabled?data.visits:[],error:''};
}

async function loadActivities(branchId){
  const sb=getSupabase();
  const {data,error}=await sb.from('medical_referral_events').select('*')
    .eq('branch_id',branchId)
    .order('referral_date',{ascending:false})
    .limit(300);
  if(error)throw new Error(`Actividades con especialistas: ${error.message}`);
  return data||[];
}

export async function createLaunchProject(payload){
  return bloodData.createProject({...payload,domain:'COMERCIAL'});
}

export async function createSpecialistActivity(payload){
  return createReferral(payload);
}

export async function createVisit(branchId,payload){
  return workflowData.saveVisit(branchId,null,payload);
}

// Quick inline status change from the calendar cell (Confirmar/Cancelar).
// Carries over the visit's existing commitment/evidence/followup_at so the
// update doesn't null them out — wf_save_visit replaces all three on every
// call, it doesn't merge.
export async function updateVisitStatus(branchId,visit,status){
  return workflowData.saveVisit(branchId,visit.id,{
    status,evidence:visit.evidence||'',commitment:visit.commitment||'',followup_at:visit.followup_at||''
  });
}
