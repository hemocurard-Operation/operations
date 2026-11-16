import {getSupabase} from './supabase.js';
import {allPages} from './data-pages.js';
export function readUnitSales({from,to,branch=''}={}){
 let q=getSupabase().from('vw_sales_unit_report').select('sale_id,sale_code,sale_date,branch_id,customer_id,center_name,shift,status,line_id,component_name,abo,rh,quantity');
 if(from)q=q.gte('sale_date',from);if(to)q=q.lte('sale_date',to);if(branch)q=q.eq('branch_id',branch);
 return allPages('Unidades vendidas',q.order('sale_date',{ascending:false}).order('sale_id').order('line_id'));
}
export function readPerformedSessions({from,to,branch=''}={}){
 let q=getSupabase().from('vw_performed_session_report').select('id,branch_id,operational_date,shift,status,customer_id');
 if(from)q=q.gte('operational_date',from);if(to)q=q.lte('operational_date',to);if(branch)q=q.eq('branch_id',branch);
 return allPages('Sesiones realizadas',q.order('operational_date').order('id'));
}
