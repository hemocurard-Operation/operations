import { getSupabase } from './supabase.js';

const sb=()=>getSupabase();
async function query(label,promise){
  const {data,error}=await promise;
  if(error) throw new Error(`${label}: ${error.message}`);
  return data||[];
}
export const bloodData={
  branches:()=>query('Sucursales',sb().from('branches').select('id,code,name').eq('active',true).order('name')),
  donors:()=>query('Donantes',sb().from('donors').select('*').order('registration_date',{ascending:false}).limit(200)),
  createDonor:async p=>{const {data,error}=await sb().from('donors').insert(p).select('*').single();if(error)throw new Error(`Donante: ${error.message}`);return data},
  donations:()=>query('Donaciones',sb().from('donations').select('*').order('donation_date',{ascending:false}).limit(200)),
  createDonation:async p=>{const {data,error}=await sb().from('donations').insert(p).select('*').single();if(error)throw new Error(`Donación: ${error.message}`);return data},
  screenings:()=>query('Tamizaje',sb().from('screening_tests').select('*').order('screening_date',{ascending:false}).limit(300)),
  createScreening:async p=>{const {data,error}=await sb().from('screening_tests').insert(p).select('*').single();if(error)throw new Error(`Tamizaje: ${error.message}`);return data},
  inventory:()=>query('Inventario sangre',sb().from('vw_blood_inventory_available').select('*').order('component_name')),
  inventoryUnits:()=>query('Unidades',sb().from('blood_inventory_units').select('*').order('production_date',{ascending:false}).limit(300)),
  createInventoryUnit:async p=>{const {data,error}=await sb().from('blood_inventory_units').insert(p).select('*').single();if(error)throw new Error(`Unidad: ${error.message}`);return data},
  sales:()=>query('Ventas/Salidas',sb().from('operational_sales').select('*').order('sale_date',{ascending:false}).limit(200)),
  createSale:async(h,l)=>{const {data:s,error}=await sb().from('operational_sales').insert(h).select('*').single();if(error)throw new Error(`Venta: ${error.message}`);if(l?.length){const {error:le}=await sb().from('operational_sale_lines').insert(l.map(x=>({...x,sale_id:s.id})));if(le)throw new Error(`Detalle venta: ${le.message}`)}return s},
  screeningSummary:()=>query('Reporte tamizaje',sb().from('vw_screening_summary').select('*').order('screening_date',{ascending:false}).limit(300)),
  donorSummary:()=>query('Reporte donantes',sb().from('vw_donor_summary').select('*').order('registration_date',{ascending:false}).limit(300)),
  salesSummary:()=>query('Reporte ventas',sb().from('vw_sales_operational_summary').select('*').order('sale_date',{ascending:false}).limit(300)),
  biToday:()=>query('BI Operaciones',sb().from('vw_bi_operations_today').select('*')),
  projects:()=>query('Portafolio',sb().from('vw_project_portfolio').select('*').order('priority')),
  createProject:async p=>{const {data,error}=await sb().from('projects').insert(p).select('*').single();if(error)throw new Error(`Proyecto: ${error.message}`);return data}
};
