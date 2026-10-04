import { getSupabase } from './supabase.js';
const sb=()=>getSupabase();

async function many(label,p){
  const {data,error}=await p;
  if(error) throw new Error(`${label}: ${error.message}`);
  return data||[];
}
async function one(label,p){
  const {data,error}=await p;
  if(error) throw new Error(`${label}: ${error.message}`);
  return data;
}

export const internalAuditData={
  branches:()=>many('Sucursales',sb().from('branches').select('id,code,name').eq('active',true).order('name')),
  processes:()=>many('Procesos',sb().from('quality_processes').select('id,code,name,owner_user_id').eq('active',true).order('name')),
  profiles:()=>many('Usuarios',sb().from('profiles').select('id,full_name,branch_id').order('full_name')),
  criteria:()=>many('Criterios',sb().from('audit_criteria_catalog').select('*').eq('active',true).order('clause_reference')),
  programs:()=>many('Programas',sb().from('vw_audit_program_summary').select('*').order('program_year',{ascending:false})),
  audits:()=>many('Auditorías',sb().from('vw_internal_audit_portfolio').select('*').order('planned_date',{ascending:false}).limit(300)),
  findings:()=>many('Hallazgos',sb().from('vw_audit_findings_open').select('*').order('severity').order('due_date',{ascending:true,nullsFirst:false}).limit(300)),

  createProgram:async p=>{
    const {data,error}=await sb().from('audit_programs').insert(p).select('*').single();
    if(error) throw new Error(`Programa: ${error.message}`);
    return data;
  },
  createAudit:async p=>{
    const {data,error}=await sb().from('internal_audits').insert(p).select('*').single();
    if(error) throw new Error(`Auditoría: ${error.message}`);
    return data;
  },
  assignCriterion:async p=>{
    const {data,error}=await sb().from('audit_plan_criteria').upsert(p,{onConflict:'audit_id,criterion_id'}).select('*').single();
    if(error) throw new Error(`Criterio: ${error.message}`);
    return data;
  },
  createFinding:async p=>{
    const {data,error}=await sb().from('audit_findings').insert(p).select('*').single();
    if(error) throw new Error(`Hallazgo: ${error.message}`);
    return data;
  },
  addEvidence:async p=>{
    const {data,error}=await sb().from('audit_evidence').insert(p).select('*').single();
    if(error) throw new Error(`Evidencia: ${error.message}`);
    return data;
  },
  findingToNc:async(id,owner,due)=>{
    const {data,error}=await sb().rpc('audit_finding_to_nonconformity',{p_finding_id:id,p_owner_user_id:owner,p_due_date:due||null});
    if(error) throw new Error(`Crear NC: ${error.message}`);
    return data;
  },
  findingToCapa:async(id,plan,owner,due)=>{
    const {data,error}=await sb().rpc('audit_finding_create_capa',{p_finding_id:id,p_action_plan:plan,p_owner_user_id:owner,p_due_date:due||null});
    if(error) throw new Error(`Crear CAPA: ${error.message}`);
    return data;
  }
};
