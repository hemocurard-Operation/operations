// HemoCura v11 Brecha L1 §5.8 — data layer de Limpieza de equipos.
// Todas las operaciones van vía supabase client con RLS activa.
import { getSupabase } from './supabase.js';

export const cleaningData = {
  async branches(){
    const {data,error}=await getSupabase().from('branches').select('id,name,code').eq('active',true).order('name');
    if(error) throw new Error('Sucursales: '+error.message);
    return data||[];
  },
  async equipment(branchId){
    const {data,error}=await getSupabase().from('lab_equipment')
      .select('id,equipment_code,equipment_type,status,branch_id')
      .eq('branch_id',branchId).eq('status','ACTIVO').order('equipment_code');
    if(error) throw new Error('Equipos: '+error.message);
    return data||[];
  },
  async plans(branchId){
    const {data,error}=await getSupabase().from('cleaning_plans')
      .select('id,equipment_id,branch_id,frequency_days,procedure_ref,product_name,responsible_role,checklist,active,revision,updated_at')
      .eq('branch_id',branchId).order('updated_at',{ascending:false}).limit(200);
    if(error) throw new Error('Planes: '+error.message);
    return data||[];
  },
  async records(branchId,limit=50){
    const {data,error}=await getSupabase().from('cleaning_records')
      .select('id,plan_id,equipment_id,branch_id,performed_at,performed_by,product_used,observations,evidence_reference,verified_by,verified_at')
      .eq('branch_id',branchId).order('performed_at',{ascending:false}).limit(limit);
    if(error) throw new Error('Registros: '+error.message);
    return data||[];
  },
  async alerts(branchId){
    const {data,error}=await getSupabase().from('vw_cleaning_alerts')
      .select('*').eq('branch_id',branchId).order('severity').order('days_overdue',{ascending:false}).limit(200);
    if(error) throw new Error('Alertas: '+error.message);
    return data||[];
  },
  async createPlan(payload){
    const {data,error}=await getSupabase().from('cleaning_plans').insert(payload).select('*').single();
    if(error) throw new Error('Crear plan: '+error.message);
    return data;
  },
  async recordExecution(payload){
    const {data,error}=await getSupabase().from('cleaning_records').insert(payload).select('*').single();
    if(error) throw new Error('Registrar limpieza: '+error.message);
    return data;
  },
  async verifyRecord(id,verifierId){
    const {data,error}=await getSupabase().from('cleaning_records')
      .update({verified_by:verifierId,verified_at:new Date().toISOString()})
      .eq('id',id).select('*').single();
    if(error) throw new Error('Verificar: '+error.message);
    return data;
  },
  async people(branchId){
    const {data,error}=await getSupabase().from('profiles').select('id,full_name').eq('active',true).order('full_name').limit(200);
    if(error) throw new Error('Personal: '+error.message);
    return (data||[]).filter(p=>p.id);
  }
};
