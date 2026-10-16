import {getSupabase} from './supabase.js';
async function rows(label,query){const out=[];for(let n=0;;n+=500){const {data,error}=await query().range(n,n+499);if(error)throw Error(label+': '+error.message);out.push(...(data||[]));if((data||[]).length<500)return out}}
export const procurementData={
 suppliers:()=>rows('Proveedores',()=>getSupabase().from('suppliers').select('*').order('legal_name').order('id')),
 orders:branch=>rows('Órdenes',()=>getSupabase().from('purchase_orders').select('*').eq('branch_id',branch).order('order_date',{ascending:false}).order('id')),
 lines:id=>rows('Artículos',()=>getSupabase().from('purchase_order_lines').select('*').eq('purchase_order_id',id).order('id')),
 receipts:id=>rows('Recepciones',()=>getSupabase().from('purchase_receipts').select('*,purchase_receipt_lines(*)').eq('purchase_order_id',id).order('recorded_at',{ascending:false}).order('id')),
 action:async(action,payload)=>{const {data,error}=await getSupabase().rpc('procurement_action',{p_action:action,p_payload:payload});if(error)throw Error(error.message);return data}
};
