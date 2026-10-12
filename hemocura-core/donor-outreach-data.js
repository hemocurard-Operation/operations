import { getSupabase } from './supabase.js';

async function userId(){const {data}=await getSupabase().auth.getUser();return data?.user?.id||null}

export async function loadDonorOutreach(){
  const sb=getSupabase();
  const [campaigns,branches]=await Promise.all([
    sb.from('vw_donor_campaign_performance').select('*').order('start_date',{ascending:false}),
    sb.from('branches').select('id,code,name').eq('active',true).order('name')
  ]);
  if(campaigns.error) throw new Error(`Campañas: ${campaigns.error.message}`);
  if(branches.error) throw new Error(`Sucursales: ${branches.error.message}`);
  return {campaigns:campaigns.data||[],branches:branches.data||[]};
}

export async function createCampaign(payload){
  const created_by=await userId();
  const {data,error}=await getSupabase().from('donor_campaigns').insert({...payload,created_by}).select('*').single();
  if(error) throw new Error(`Crear campaña: ${error.message}`);
  return data;
}

export async function setCampaignStatus(id,status){
  const {data,error}=await getSupabase().from('donor_campaigns').update({status,updated_at:new Date().toISOString()}).eq('id',id).select('*').single();
  if(error) throw new Error(`Actualizar campaña: ${error.message}`);
  return data;
}
