import { getSupabase } from './supabase.js';

async function read(label, query) {
  const {data,error}=await query;
  if(error)throw new Error(`${label}: ${error.message}`);
  return data||[];
}
async function all(label, makeQuery) {
  const rows=[];
  for(let offset=0;;offset+=500){
    const page=await read(label,makeQuery().range(offset,offset+499));
    rows.push(...page);if(page.length<500)return rows;
  }
}
async function write(label,query){
  const {data,error}=await query.select('*').single();
  if(error){if(error.code==='PGRST116')throw new Error('El registro cambió o no tiene permisos. Actualice la ficha.');if(error.code==='23505'&&label==='Visita')throw new Error('Este donante ya tiene una cita activa. Coordine su reprogramación.');throw new Error(`${label}: ${error.message}`)}
  if(!data)throw new Error('El registro cambió o no tiene permisos. Actualice la ficha.');
  return data;
}
const sb=()=>getSupabase();
const PROFILE_FIELDS='id,donor_code,branch_id,full_name,cedula,birth_date,sex,phone,preferred_channel,abo,rh,status,registration_date,donor_type,effective_donation,deferral_reason,observations,last_donation_date,next_donation_date,agenda_state,reference_source';
const AGENDA_FIELDS='id,donor_code,branch_id,full_name,cedula,phone,last_donation_date,next_donation_date,agenda_state,reference_source,last_contact_id,last_contact_at,last_contact_outcome,next_contact_at,active_visit_id,visit_starts_at,visit_branch_id,visit_status';
async function donorPage({branch='',search='',group='',offset=0,limit=25,focus=null,signal}={}){
 const controller=new AbortController(),cancel=()=>controller.abort();const timeout=setTimeout(cancel,12000);
 if(signal?.aborted)cancel();signal?.addEventListener('abort',cancel,{once:true});
 try{
  let query=sb().rpc('donor_search_page',{p_branch:branch||null,p_search:search,p_group:group,p_offset:offset,p_limit:limit,p_focus:focus||null});
  if(query.abortSignal)query=query.abortSignal(controller.signal);
  const {data,error}=await query;if(error)throw Error(error.message);
  if(!data||!Array.isArray(data.rows)||!Number.isInteger(data.total)||!Number.isInteger(data.offset))throw Error('Respuesta incompleta de la búsqueda. Actualice para reintentar.');
  return data;
 }finally{clearTimeout(timeout);signal?.removeEventListener('abort',cancel)}
}

export const donorManagement={
  page:donorPage,
  agenda:()=>all('Agenda y contactos',()=>sb().from('vw_donor_coordination').select(AGENDA_FIELDS).order('registration_date',{ascending:false}).order('id')),
  byCedula:async number=>{const {data,error}=await sb().from('vw_donor_next_donation').select(PROFILE_FIELDS).eq('cedula',number).maybeSingle();if(error)throw new Error(`Consultar cédula: ${error.message}`);return data||null},
  detail:async id=>{
    const [donations,comments,contacts,visits,source,profile]=await Promise.all([
      all('Historial',()=>sb().from('donations').select('*').eq('donor_id',id).order('donation_date',{ascending:false}).order('id')),
      all('Laboratorio',()=>sb().from('donor_lab_comments').select('*').eq('donor_id',id).order('created_at',{ascending:false}).order('id')),
      all('Contactos',()=>sb().from('donor_contacts').select('*').eq('donor_id',id).order('contacted_at',{ascending:false}).order('id')),
      all('Agenda',()=>sb().from('donor_visits').select('*').eq('donor_id',id).order('starts_at',{ascending:false}).order('id')),
      read('Antecedentes importados',sb().from('donors').select('donor_import_metadata').eq('id',id).single()),
      read('Ficha',sb().from('vw_donor_coordination').select(PROFILE_FIELDS).eq('id',id).single())
    ]);return {profile,donations,comments,contacts,visits,imported:source.donor_import_metadata||null};
  },
  saveProfile:(id,payload)=>write('Ficha',id?sb().from('donors').update(payload).eq('id',id):sb().from('donors').insert(payload)),
  comment:p=>write('Comentario',sb().from('donor_lab_comments').insert(p)),
  contact:p=>write('Contacto',sb().from('donor_contacts').insert(p)),
  visit:(id,revision,p)=>write('Visita',id?sb().from('donor_visits').update(p).eq('id',id).eq('revision',revision):sb().from('donor_visits').insert(p))
};
