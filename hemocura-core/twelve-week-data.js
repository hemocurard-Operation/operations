import {getSupabase} from './supabase.js';
const sb=()=>getSupabase();

export async function listPlans(){
  const {data,error}=await sb().from('operational_plans').select('*').order('start_date',{ascending:false});
  if(error)throw new Error(`Planes: ${error.message}`);
  return data||[];
}

export async function createPlan(payload){
  const {data,error}=await sb().from('operational_plans').insert(payload).select('*').single();
  if(error)throw new Error(`Crear plan: ${error.message}`);
  return data;
}

export async function updatePlan(id,payload){
  const {data,error}=await sb().from('operational_plans').update(payload).eq('id',id).select('*').single();
  if(error)throw new Error(`Actualizar plan: ${error.message}`);
  return data;
}

export async function listPlanLines(planId){
  const {data,error}=await sb().from('operational_plan_lines').select('*').eq('plan_id',planId).order('week_number');
  if(error)throw new Error(`Líneas del plan: ${error.message}`);
  return data||[];
}

export async function createPlanLine(payload){
  const {data,error}=await sb().from('operational_plan_lines').insert(payload).select('*').single();
  if(error)throw new Error(`Crear línea: ${error.message}`);
  return data;
}

export async function updatePlanLine(id,payload){
  const {data,error}=await sb().from('operational_plan_lines').update(payload).eq('id',id).select('*').single();
  if(error)throw new Error(`Actualizar línea: ${error.message}`);
  return data;
}

export async function listTasks(planId){
  const {data,error}=await sb().from('work_tasks').select('*').eq('plan_id',planId).order('due_date');
  if(error)throw new Error(`Tareas: ${error.message}`);
  return data||[];
}

export async function createTask(payload){
  const {data,error}=await sb().from('work_tasks').insert(payload).select('*').single();
  if(error)throw new Error(`Crear tarea: ${error.message}`);
  return data;
}

export async function updateTask(id,payload){
  const {data,error}=await sb().from('work_tasks').update(payload).eq('id',id).select('*').single();
  if(error)throw new Error(`Actualizar tarea: ${error.message}`);
  return data;
}

export async function listProfiles(){
  const {data,error}=await sb().from('profiles').select('id,full_name').order('full_name');
  if(error)throw new Error(`Perfiles: ${error.message}`);
  return data||[];
}
