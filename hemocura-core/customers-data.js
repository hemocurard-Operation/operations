import { getSupabase } from './supabase.js';
async function userId(){const {data}=await getSupabase().auth.getUser();return data?.user?.id||null}
export async function loadCustomerWorkspace(){
  const sb=getSupabase();
  const [summary,customers,agreements,feedback,branches]=await Promise.all([
    sb.from('vw_customer_value_summary').select('*').order('billed_amount',{ascending:false}),
    sb.from('customers').select('*').order('name'),
    sb.from('customer_service_agreements').select('*').order('start_date',{ascending:false}),
    sb.from('customer_feedback').select('*').order('feedback_date',{ascending:false}).limit(200),
    sb.from('branches').select('id,code,name').eq('active',true).order('name')
  ]);
  for(const [label,r] of [['resumen',summary],['clientes',customers],['acuerdos',agreements],['feedback',feedback],['sucursales',branches]]) if(r.error) throw new Error(`${label}: ${r.error.message}`);
  return {summary:summary.data||[],customers:customers.data||[],agreements:agreements.data||[],feedback:feedback.data||[],branches:branches.data||[]};
}
export async function createCustomer(payload){const {data,error}=await getSupabase().from('customers').insert(payload).select('*').single();if(error)throw new Error(`Crear cliente: ${error.message}`);return data}
export async function createAgreement(payload){const created_by=await userId();const {data,error}=await getSupabase().from('customer_service_agreements').insert({...payload,created_by}).select('*').single();if(error)throw new Error(`Crear acuerdo: ${error.message}`);return data}
export async function createFeedback(payload){const created_by=await userId();const {data,error}=await getSupabase().from('customer_feedback').insert({...payload,created_by}).select('*').single();if(error)throw new Error(`Crear feedback: ${error.message}`);return data}
