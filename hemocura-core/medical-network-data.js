import { getSupabase } from './supabase.js';
async function userId(){const {data}=await getSupabase().auth.getUser();return data?.user?.id||null}
export async function loadMedicalNetwork(){const sb=getSupabase();const [network,branches,customers,demands]=await Promise.all([sb.from('vw_medical_network_performance').select('*').order('converted_referrals',{ascending:false}),sb.from('branches').select('id,name,code').eq('active',true).order('name'),sb.from('customers').select('id,name').eq('active',true).order('name'),sb.from('clinical_demand_requests').select('id,branch_id,customer_id,priority,status,requested_at').in('status',['ABIERTA','EN_PROCESO']).order('requested_at',{ascending:false}).limit(100)]);for(const [label,r] of [['Red',network],['Sucursales',branches],['Clientes',customers],['Demanda',demands]])if(r.error)throw new Error(`${label}: ${r.error.message}`);return{network:network.data||[],branches:branches.data||[],customers:customers.data||[],demands:demands.data||[]}}
export async function createReferrer(payload){const created_by=await userId();const {data,error}=await getSupabase().from('medical_referrers').insert({...payload,created_by}).select('*').single();if(error)throw new Error(`Médico: ${error.message}`);return data}
export async function createReferral(payload){const created_by=await userId();const {data,error}=await getSupabase().from('medical_referral_events').insert({...payload,created_by}).select('*').single();if(error)throw new Error(`Referencia: ${error.message}`);return data}

// Predictive route planning: who to visit today, based on reception_days/
// reception_shift/visit_frequency_days/last_visit_at (see
// 20261103190000_referrer_visit_route_planning.sql).
export async function loadVisitRoute(branchId){
  const sb=getSupabase();
  let q=sb.from('vw_referrer_visit_route').select('*').order('days_overdue',{ascending:false,nullsFirst:false});
  if(branchId)q=q.eq('branch_id',branchId);
  const {data,error}=await q;
  if(error)throw new Error(`Ruta de visitas: ${error.message}`);
  return data||[];
}

// Logs the outcome of a doctor visit (medical_referral_events, channel
// VISITA) and advances last_visit_at so the next due date recalculates.
export async function logReferrerVisit(referrerId,{branchId,outcome,notes,visitDate}){
  const created_by=await userId();
  const date=visitDate||new Date().toISOString().slice(0,10);
  const {error:eventError}=await getSupabase().from('medical_referral_events').insert({
    referrer_id:referrerId,branch_id:branchId||null,referral_date:date,
    channel:'VISITA',status:outcome==='NO_DISPONIBLE'?'NO_CONVERTIDO':'CONTACTADO',
    notes:notes||null,created_by
  });
  if(eventError)throw new Error(`Registro de visita: ${eventError.message}`);
  if(outcome==='VISITADO'){
    const {error:updateError}=await getSupabase().from('medical_referrers').update({last_visit_at:date}).eq('id',referrerId);
    if(updateError)throw new Error(`Última visita: ${updateError.message}`);
  }
}

export async function updateReferrerReception(referrerId,payload){
  const {data,error}=await getSupabase().from('medical_referrers').update(payload).eq('id',referrerId).select('*').single();
  if(error)throw new Error(`Condiciones de recepción: ${error.message}`);
  return data;
}
