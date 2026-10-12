import { getSupabase } from './supabase.js';

async function userId(){const {data}=await getSupabase().auth.getUser();return data?.user?.id||null}

export async function loadDonorOutreach(){
  const sb=getSupabase();
  const [campaigns,branches,donations]=await Promise.all([
    sb.from('vw_donor_campaign_performance').select('*').order('start_date',{ascending:false}),
    sb.from('branches').select('id,code,name').eq('active',true).order('name'),
    sb.from('donations').select('id,branch_id,donation_date,status,campaign_id').order('donation_date',{ascending:false}).limit(100)
  ]);
  if(campaigns.error) throw new Error(`Campañas: ${campaigns.error.message}`);
  if(branches.error) throw new Error(`Sucursales: ${branches.error.message}`);
  if(donations.error) throw new Error(`Donaciones: ${donations.error.message}`);
  return {campaigns:campaigns.data||[],branches:branches.data||[],donations:donations.data||[]};
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

export async function linkDonationToCampaign(donationId,campaignId){
  const {data,error}=await getSupabase().from('donations').update({campaign_id:campaignId||null}).eq('id',donationId).select('id,branch_id,donation_date,status,campaign_id').single();
  if(error) throw new Error(`Atribuir donación: ${error.message}`);
  return data;
}
