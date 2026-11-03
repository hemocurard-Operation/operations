// Unifies three existing data sources into one calendar instead of creating a
// parallel scheduling table: commercial_visits (client visits, already in
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
  const [visits,customers,projects,network]=await Promise.all([
    workflowData.visits(branchId),
    workflowData.customers(),
    bloodData.projects(),
    loadMedicalNetwork()
  ]);
  const launches=projects.filter(p=>p.domain==='COMERCIAL');
  return {visits,customers,launches,referrers:network.network,activities:await loadActivities(branchId)};
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
