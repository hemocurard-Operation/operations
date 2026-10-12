import { getSupabase } from './supabase.js';

async function userId(){
  const {data}=await getSupabase().auth.getUser();
  return data?.user?.id||null;
}

export async function loadValueChainWorkspace(){
  const sb=getSupabase();
  const [scorecard,stages,demand,branches,customers,products]=await Promise.all([
    sb.from('vw_value_chain_scorecard').select('*').order('branch_name'),
    sb.from('value_chain_stage_catalog').select('*').eq('active',true).order('sequence_no'),
    sb.from('clinical_demand_requests').select('*').order('requested_at',{ascending:false}).limit(150),
    sb.from('branches').select('id,code,name').eq('active',true).order('name'),
    sb.from('customers').select('id,name,customer_type,active').eq('active',true).order('name'),
    sb.from('products').select('id,code,name,category,active').eq('active',true).order('name')
  ]);
  for(const [label,r] of [['scorecard',scorecard],['stages',stages],['demand',demand],['branches',branches],['customers',customers],['products',products]]){
    if(r.error) throw new Error(`Cadena de valor · ${label}: ${r.error.message}`);
  }
  return {scorecard:scorecard.data||[],stages:stages.data||[],demand:demand.data||[],branches:branches.data||[],customers:customers.data||[],products:products.data||[]};
}

export async function createDemand(payload){
  const created_by=await userId();
  const {data,error}=await getSupabase().from('clinical_demand_requests').insert({...payload,created_by}).select('*').single();
  if(error) throw new Error(`Crear demanda: ${error.message}`);
  return data;
}

export async function updateDemandStatus(id,status){
  const {data,error}=await getSupabase().from('clinical_demand_requests').update({status}).eq('id',id).select('*').single();
  if(error) throw new Error(`Actualizar demanda: ${error.message}`);
  return data;
}
