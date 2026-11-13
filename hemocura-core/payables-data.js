import { getSupabase } from './supabase.js';

export const payablesData = {
  async aging(branchId){
    let q=getSupabase().from('vw_accounts_payable_aging').select('*').order('days_past_due',{ascending:false}).limit(500);
    if(branchId) q=q.eq('branch_id',branchId);
    const {data,error}=await q;
    if(error) throw new Error('Aging CxP: '+error.message);
    return data||[];
  },
  async suppliers(){
    const {data,error}=await getSupabase().from('suppliers').select('id,name').eq('active',true).order('name');
    if(error) throw new Error('Suplidores: '+error.message);
    return data||[];
  },
  async createPayable(payload){
    const {data,error}=await getSupabase().from('supplier_payables').insert(payload).select('*').single();
    if(error) throw new Error('Crear factura: '+error.message);
    return data;
  },
  async recordPayment(payload){
    const {data,error}=await getSupabase().from('supplier_payments').insert(payload).select('*').single();
    if(error) throw new Error('Registrar pago: '+error.message);
    return data;
  },
  async cashFlow(){
    const {data,error}=await getSupabase().from('vw_cash_flow_summary').select('*');
    if(error) return [];
    return data||[];
  }
};
