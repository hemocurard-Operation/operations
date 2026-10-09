import { getSupabase } from './supabase.js';

const sb=()=>getSupabase();

async function currentUserId(){
  const {data,error}=await sb().auth.getUser();
  if(error) throw new Error(`Usuario: ${error.message}`);
  return data?.user?.id||null;
}

export async function loadDailyInventoryCapture({captureDate,shift,branchId}){
  const {data,error}=await sb().from('daily_inventory_captures')
    .select('*')
    .eq('capture_date',captureDate)
    .eq('shift',shift)
    .eq('branch_id',branchId)
    .maybeSingle();
  if(error) throw new Error(`Captura diaria: ${error.message}`);
  return data||null;
}

export async function saveDailyInventoryCapture(payload){
  const userId=await currentUserId();
  const row={
    ...payload,
    created_by:payload.created_by||userId,
    updated_at:new Date().toISOString()
  };
  const {data,error}=await sb().from('daily_inventory_captures')
    .upsert(row,{onConflict:'capture_date,shift,branch_id'})
    .select('*')
    .single();
  if(error) throw new Error(`Guardar captura: ${error.message}`);
  return data;
}

export async function recentDailyInventoryCaptures(limit=20){
  const {data,error}=await sb().from('daily_inventory_captures')
    .select('id,capture_date,shift,branch_id,responsible_name,status,updated_at')
    .order('capture_date',{ascending:false})
    .order('updated_at',{ascending:false})
    .limit(limit);
  if(error) throw new Error(`Histórico diario: ${error.message}`);
  return data||[];
}
