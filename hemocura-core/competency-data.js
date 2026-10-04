import { getSupabase } from './supabase.js';
const sb=()=>getSupabase();

async function many(label,p){
  const {data,error}=await p;
  if(error) throw new Error(`${label}: ${error.message}`);
  return data||[];
}

export const competencyData={
  profiles:()=>many('Usuarios',sb().from('profiles').select('id,full_name,branch_id').order('full_name')),
  branches:()=>many('Sucursales',sb().from('branches').select('id,code,name').eq('active',true).order('name')),
  roles:()=>many('Puestos',sb().from('job_roles').select('*').eq('active',true).order('title')),
  competencies:()=>many('Competencias',sb().from('competency_catalog').select('*').eq('active',true).order('category').order('title')),
  gaps:()=>many('Brechas',sb().from('vw_staff_competency_gaps').select('*').order('competency_status').order('competency_title').limit(500)),
  compliance:()=>many('Cumplimiento',sb().from('vw_competency_compliance_summary').select('*').order('compliance_pct',{ascending:true})),
  alerts:()=>many('Alertas',sb().from('vw_competency_alerts').select('*').order('severity').limit(500)),
  trainings:()=>many('Capacitaciones',sb().from('training_events').select('*').order('start_date',{ascending:false}).limit(300)),
  createRole:async p=>{const {data,error}=await sb().from('job_roles').insert(p).select('*').single();if(error)throw new Error(`Puesto: ${error.message}`);return data},
  createCompetency:async p=>{const {data,error}=await sb().from('competency_catalog').insert(p).select('*').single();if(error)throw new Error(`Competencia: ${error.message}`);return data},
  assignRole:async p=>{const {data,error}=await sb().from('staff_job_assignments').insert(p).select('*').single();if(error)throw new Error(`Asignación: ${error.message}`);return data},
  assignCompetency:async p=>{const {data,error}=await sb().from('job_role_competencies').upsert(p,{onConflict:'job_role_id,competency_id'}).select('*').single();if(error)throw new Error(`Matriz: ${error.message}`);return data},
  createAssessment:async p=>{const {data,error}=await sb().from('competency_assessments').insert(p).select('*').single();if(error)throw new Error(`Evaluación: ${error.message}`);return data},
  createTraining:async p=>{const {data,error}=await sb().from('training_events').insert(p).select('*').single();if(error)throw new Error(`Capacitación: ${error.message}`);return data}
};
