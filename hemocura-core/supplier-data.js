import {getSupabase} from './supabase.js';const sb=()=>getSupabase();
async function many(l,p){const {data,error}=await p;if(error)throw new Error(`${l}: ${error.message}`);return data||[]}
export const supplierData={
 suppliers:()=>many('Proveedores',sb().from('vw_supplier_performance').select('*').order('legal_name')),
 orders:()=>many('Compras',sb().from('purchase_orders').select('*,suppliers(legal_name)').order('order_date',{ascending:false}).limit(300)),
 incidents:()=>many('Incidencias',sb().from('supplier_incidents').select('*,suppliers(legal_name)').order('incident_date',{ascending:false}).limit(300)),
 createSupplier:async p=>{const {data,error}=await sb().from('suppliers').insert(p).select('*').single();if(error)throw new Error(error.message);return data}
};