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

export const resourcesData={
  branches:()=>many('Sucursales',sb().from('branches').select('id,code,name').eq('active',true).order('name')),
  profiles:()=>many('Usuarios',sb().from('profiles').select('id,full_name,branch_id').order('full_name')),
  equipment:()=>many('Equipos',sb().from('lab_equipment').select('*').order('equipment_code').limit(500)),
  equipmentAlerts:()=>many('Alertas equipos',sb().from('vw_equipment_alerts').select('*').order('due_date')),
  reagents:()=>many('Reactivos',sb().from('reagent_lots').select('*').order('expiry_date').limit(500)),
  reagentAlerts:()=>many('Alertas reactivos',sb().from('vw_reagent_alerts').select('*').order('expiry_date')),
  environmental:()=>many('Ambiente',sb().from('vw_environmental_alerts').select('*').order('reading_time',{ascending:false}).limit(300)),
  points:()=>many('Puntos',sb().from('environmental_points').select('*').eq('active',true).order('point_code')),
  summary:()=>one('Resumen recursos',sb().from('vw_resource_control_summary').select('*').single()),

  createEquipment:async p=>{const {data,error}=await sb().from('lab_equipment').insert(p).select('*').single();if(error)throw new Error(`Equipo: ${error.message}`);return data},
  createReagent:async p=>{const {data,error}=await sb().from('reagent_lots').insert(p).select('*').single();if(error)throw new Error(`Reactivo: ${error.message}`);return data},
  createPoint:async p=>{const {data,error}=await sb().from('environmental_points').insert(p).select('*').single();if(error)throw new Error(`Punto ambiental: ${error.message}`);return data},
  addReading:async p=>{const {data,error}=await sb().from('environmental_readings').insert(p).select('*').single();if(error)throw new Error(`Lectura: ${error.message}`);return data},
  createService:async p=>{const {data,error}=await sb().from('equipment_service_events').insert(p).select('*').single();if(error)throw new Error(`Servicio equipo: ${error.message}`);return data}
};
