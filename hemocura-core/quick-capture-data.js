import { getSupabase } from './supabase.js';

const sb=()=>getSupabase();

export async function quickCaptureProducts(){
  const {data,error}=await sb().from('products').select('id,code,name,category,unit_of_measure,active').eq('active',true).order('name');
  if(error) throw new Error(`Catálogo: ${error.message}`);
  return data||[];
}

export async function createDispatchDraft(header,lines=[]){
  if(!lines.length) throw new Error('El despacho requiere al menos una línea.');
  const {data:dispatch,error}=await sb().from('dispatches').insert({
    dispatch_date:header.dispatch_date,
    branch_id:header.branch_id,
    customer_id:header.customer_id||null,
    shift:header.shift||null,
    dispatch_type:header.dispatch_type||'venta',
    status:'BORRADOR',
    notes:header.notes||null
  }).select('*').single();
  if(error) throw new Error(`Crear despacho: ${error.message}`);
  const {error:lineError}=await sb().from('dispatch_lines').insert(lines.map(line=>({
    dispatch_id:dispatch.id,
    product_id:line.product_id,
    units:Number(line.units),
    is_sale:line.is_sale!==false,
    sale_generated:false
  })));
  if(lineError) throw new Error(`Despacho ${dispatch.id} creado como BORRADOR, pero las líneas requieren revisión: ${lineError.message}`);
  return dispatch;
}

export async function createIncident(payload){
  let reportedBy=null;
  try{
    const {data}=await sb().auth.getUser();
    reportedBy=data?.user?.id||null;
  }catch{}
  const {data,error}=await sb().from('incidents').insert({
    incident_code:payload.incidentCode,
    incident_date:payload.incidentDate,
    incident_time:payload.incidentTime||null,
    branch_id:payload.branchId||null,
    reported_by:reportedBy,
    classification:payload.classification||null,
    process_name:payload.processName||null,
    severity:payload.severity||null,
    description:payload.description,
    patient_or_donor_affected:!!payload.patientOrDonorAffected,
    impact_detail:payload.impactDetail||null,
    immediate_action:payload.immediateAction||null,
    evidence_url:payload.evidenceUrl||null,
    requires_quality_followup:!!payload.requiresQualityFollowup
  }).select('*').single();
  if(error) throw new Error(`Incidencia: ${error.message}`);
  return data;
}
