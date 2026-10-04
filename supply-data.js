import { getSupabase } from './supabase.js';
const sb=()=>getSupabase();
async function q(label,p){const {data,error}=await p;if(error)throw new Error(`${label}: ${error.message}`);return data||[]}
export const supplyData={
  branches:()=>q('Sucursales',sb().from('branches').select('id,code,name').eq('active',true).order('name')),
  production:()=>q('Producción',sb().from('production_batches').select('*').order('production_date',{ascending:false}).limit(300)),
  createProduction:async p=>{const {data,error}=await sb().from('production_batches').insert(p).select('*').single();if(error)throw new Error(`Producción: ${error.message}`);return data},
  targets:()=>q('Objetivos',sb().from('blood_stock_targets').select('*').order('component_name')),
  upsertTarget:async p=>{const {data,error}=await sb().from('blood_stock_targets').upsert(p,{onConflict:'branch_id,component_name,abo,rh'}).select('*').single();if(error)throw new Error(`Objetivo stock: ${error.message}`);return data},
  yields:()=>q('Rendimientos',sb().from('production_yield_rules').select('*').order('component_name')),
  upsertYield:async p=>{const {data,error}=await sb().from('production_yield_rules').upsert(p,{onConflict:'component_name'}).select('*').single();if(error)throw new Error(`Rendimiento: ${error.message}`);return data},
  plan:()=>q('Plan abastecimiento',sb().from('vw_blood_supply_plan').select('*').order('stock_status').order('component_name')),
  donorsRequired:()=>q('Donantes requeridos',sb().from('vw_donors_required_plan').select('*').order('stock_status').order('component_name')),
  productionSummary:()=>q('Resumen producción',sb().from('vw_production_summary_30d').select('*')),
  alerts:()=>q('Alertas abastecimiento',sb().from('vw_supply_alerts').select('*').limit(300))
};
