import { getSupabase } from './supabase.js';

export async function loadPenalCompliance(branchId=''){
  const sb=getSupabase();
  let assessments=sb.from('compliance_penal_assessments').select('*').order('updated_at',{ascending:false});
  let actions=sb.from('compliance_penal_actions').select('*').order('due_date',{ascending:true,nullsFirst:false});
  if(branchId==='CORPORATE'){
    assessments=assessments.is('branch_id',null);
    actions=actions.is('branch_id',null);
  }else if(branchId){
    assessments=assessments.eq('branch_id',branchId);
    actions=actions.eq('branch_id',branchId);
  }
  const [rq,aq,xq]=await Promise.all([
    sb.from('compliance_penal_requirements').select('*').eq('active',true).order('sequence_no'),
    assessments,
    actions.limit(250)
  ]);
  if(rq.error) throw new Error(`Requisitos compliance penal: ${rq.error.message}`);
  if(aq.error) throw new Error(`Evaluaciones compliance penal: ${aq.error.message}`);
  if(xq.error) throw new Error(`Acciones compliance penal: ${xq.error.message}`);
  return {requirements:rq.data||[],assessments:aq.data||[],actions:xq.data||[]};
}

export async function saveAssessment(payload){
  const sb=getSupabase();
  let q=sb.from('compliance_penal_assessments').select('id').eq('requirement_id',payload.requirement_id);
  q=payload.branch_id?q.eq('branch_id',payload.branch_id):q.is('branch_id',null);
  const {data:existing,error:findError}=await q.maybeSingle();
  if(findError) throw new Error(`Buscar evaluación: ${findError.message}`);
  const row={...payload,updated_at:new Date().toISOString(),last_reviewed_at:new Date().toISOString()};
  if(existing?.id){
    const {data,error}=await sb.from('compliance_penal_assessments').update(row).eq('id',existing.id).select('*').single();
    if(error) throw new Error(`Actualizar evaluación: ${error.message}`);
    return data;
  }
  const {data,error}=await sb.from('compliance_penal_assessments').insert(row).select('*').single();
  if(error) throw new Error(`Crear evaluación: ${error.message}`);
  return data;
}

export async function createPenalAction(payload){
  const {data,error}=await getSupabase().from('compliance_penal_actions').insert(payload).select('*').single();
  if(error) throw new Error(`Crear acción: ${error.message}`);
  return data;
}

export async function setPenalActionStatus(id,status,verification_notes=null){
  const patch={status,updated_at:new Date().toISOString()};
  if(verification_notes) patch.verification_notes=verification_notes;
  const {data,error}=await getSupabase().from('compliance_penal_actions').update(patch).eq('id',id).select('*').single();
  if(error) throw new Error(`Actualizar acción: ${error.message}`);
  return data;
}
