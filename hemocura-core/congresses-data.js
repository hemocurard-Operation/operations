import {getSupabase} from './supabase.js';
const sb=()=>getSupabase();

export async function listCongresses(){
  const {data,error}=await sb().from('medical_congresses').select('*').order('start_date',{ascending:false}).limit(200);
  if(error)throw new Error(`Congresos: ${error.message}`);
  return data||[];
}

export async function createCongress(payload){
  const {data,error}=await sb().from('medical_congresses').insert(payload).select('*').single();
  if(error)throw new Error(`Crear congreso: ${error.message}`);
  return data;
}

export async function updateCongress(id,payload){
  const {data,error}=await sb().from('medical_congresses').update(payload).eq('id',id).select('*').single();
  if(error)throw new Error(`Actualizar congreso: ${error.message}`);
  return data;
}

export async function listAttendance(congressId){
  const {data,error}=await sb().from('congress_attendance').select('*,medical_referrers(full_name,specialty)').eq('congress_id',congressId).order('created_at',{ascending:false});
  if(error)throw new Error(`Asistencia: ${error.message}`);
  return data||[];
}

export async function listAttendanceByReferrer(referrerId){
  const {data,error}=await sb().from('congress_attendance').select('*,medical_congresses(name,scope,location,start_date)').eq('referrer_id',referrerId).order('created_at',{ascending:false});
  if(error)throw new Error(`Congresos del médico: ${error.message}`);
  return data||[];
}

export async function createAttendance(payload){
  const {data,error}=await sb().from('congress_attendance').insert(payload).select('*').single();
  if(error)throw new Error(`Registrar asistencia: ${error.message}`);
  return data;
}

export async function listNews(){
  const {data,error}=await sb().from('medical_news').select('*').order('published_at',{ascending:false}).limit(100);
  if(error)throw new Error(`Noticias: ${error.message}`);
  return data||[];
}

export async function createNews(payload){
  const {data,error}=await sb().from('medical_news').insert(payload).select('*').single();
  if(error)throw new Error(`Crear noticia: ${error.message}`);
  return data;
}

export async function updateNews(id,payload){
  const {data,error}=await sb().from('medical_news').update(payload).eq('id',id).select('*').single();
  if(error)throw new Error(`Actualizar noticia: ${error.message}`);
  return data;
}

export async function listReferrers(){
  const {data,error}=await sb().from('medical_referrers').select('id,referrer_code,full_name,specialty').order('full_name');
  if(error)throw new Error(`Médicos: ${error.message}`);
  return data||[];
}
