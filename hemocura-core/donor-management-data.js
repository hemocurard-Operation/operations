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
  if(error)throw new Error(`${label}: ${error.message}`);
  if(!data)throw new Error('El registro cambió o no tiene permisos. Actualice la ficha.');
  return data;
}
const sb=()=>getSupabase();
export const donorManagement={
  list:()=>all('Donantes',()=>sb().from('vw_donor_next_donation').select('*').order('registration_date',{ascending:false}).order('id')),
  detail:async id=>{
    const [donations,comments,contacts,visits,source]=await Promise.all([
      all('Historial',()=>sb().from('donations').select('*').eq('donor_id',id).order('donation_date',{ascending:false}).order('id')),
      all('Laboratorio',()=>sb().from('donor_lab_comments').select('*').eq('donor_id',id).order('created_at',{ascending:false}).order('id')),
      all('Contactos',()=>sb().from('donor_contacts').select('*').eq('donor_id',id).order('contacted_at',{ascending:false}).order('id')),
      all('Agenda',()=>sb().from('donor_visits').select('*').eq('donor_id',id).order('starts_at',{ascending:false}).order('id')),
      read('Antecedentes importados',sb().from('donors').select('donor_import_metadata').eq('id',id).single())
    ]);return {donations,comments,contacts,visits,imported:source.donor_import_metadata||null};
  },
  saveProfile:(id,payload)=>write('Ficha',id?sb().from('donors').update(payload).eq('id',id):sb().from('donors').insert(payload)),
  comment:p=>write('Comentario',sb().from('donor_lab_comments').insert(p)),
  contact:p=>write('Contacto',sb().from('donor_contacts').insert(p)),
  visit:(id,revision,p)=>write('Visita',id?sb().from('donor_visits').update(p).eq('id',id).eq('revision',revision):sb().from('donor_visits').insert(p))
};
