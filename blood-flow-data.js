import { getSupabase } from './supabase.js';
const sb=()=>getSupabase();
async function q(label,p){const {data,error}=await p;if(error)throw new Error(`${label}: ${error.message}`);return data||[]}
export const flowData={
  queue:()=>q('Cola liberación',sb().from('vw_screening_release_queue').select('*').order('donation_date',{ascending:false}).limit(300)),
  flow:()=>q('Flujo sanguíneo',sb().from('vw_blood_flow_status').select('*').order('donation_date',{ascending:false}).limit(300)),
  alerts:()=>q('Alertas flujo',sb().from('vw_blood_flow_alerts').select('*').limit(300)),
  funnel:()=>q('Embudo 30d',sb().from('vw_blood_flow_funnel_30d').select('*')),
  availableUnits:()=>q('Unidades disponibles',sb().from('blood_inventory_units').select('id,unit_code,source_unit_code,branch_id,component_name,abo,rh,expiry_date').eq('screening_status','APTO').eq('inventory_status','DISPONIBLE').order('expiry_date',{ascending:true,nullsFirst:false}).limit(300)),
  releaseUnit:async(sourceUnitCode,decision,rationale,evidence=null)=>{
    const {data,error}=await sb().rpc('review_and_release_unit',{p_source_unit_code:sourceUnitCode,p_decision:decision,p_rationale:rationale,p_evidence_reference:evidence});
    if(error) throw new Error(`Liberación: ${error.message}`);
    return data;
  }
};
