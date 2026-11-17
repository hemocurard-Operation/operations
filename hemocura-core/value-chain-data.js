import {loadAccess} from './access-control.js';
import {readUnitSales} from './unit-sales-data.js';
import {localDay} from './workflow-domain.js';
import { getSupabase } from './supabase.js';

async function userId(){
  const {data}=await getSupabase().auth.getUser();
  return data?.user?.id||null;
}

export async function loadValueChainWorkspace(){
  const sb=getSupabase(),access=await loadAccess(),canReadUnits=['SALES_VIEW','ECONOMICS_VIEW','CUSTOMER_VIEW'].some(p=>access.permissions.has(p));
  const today=localDay(),from=new Date(Date.parse(today+'T00:00:00Z')-29*86400000).toISOString().slice(0,10);
  const [scorecard,stages,demand,branches,customers,products,sales]=await Promise.all([
    sb.from('vw_value_chain_scorecard').select('branch_id,branch_code,branch_name,open_demand,available_units,dispatches_30d,active_campaigns,open_feedback,open_actions').order('branch_name'),
    sb.from('value_chain_stage_catalog').select('*').eq('active',true).order('sequence_no'),
    sb.from('clinical_demand_requests').select('*').order('requested_at',{ascending:false}).limit(150),
    sb.from('branches').select('id,code,name').eq('active',true).order('name'),
    sb.from('customers').select('id,name,customer_type,active').eq('active',true).order('name'),
    sb.from('products').select('id,code,name,category,active').eq('active',true).order('name'),
    canReadUnits?readUnitSales({from,to:today}):Promise.resolve(null)
  ]);
  for(const [label,r] of [['scorecard',scorecard],['stages',stages],['demand',demand],['branches',branches],['customers',customers],['products',products]]){
    if(r.error) throw new Error(`Cadena de valor · ${label}: ${r.error.message}`);
  }
  return {sales,salesPeriod:{from,to:today},scorecard:scorecard.data||[],stages:stages.data||[],demand:demand.data||[],branches:branches.data||[],customers:customers.data||[],products:products.data||[]};
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
