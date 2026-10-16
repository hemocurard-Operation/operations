import {localDay} from './workflow-domain.js';
import {getSupabase} from './supabase.js';
export async function agendaRows(label,make){const rows=[];for(let n=0;;n+=500){const {data,error}=await make().range(n,n+499);if(error)throw Error(label+': '+error.message);rows.push(...(data||[]));if((data||[]).length<500)return rows}}
async function call(name,args){const {data,error}=await getSupabase().rpc(name,args);if(error)throw Error(error.message);return data}
export const areaAgendaData={
 branches:()=>agendaRows('Sucursales de agenda',()=>getSupabase().from('vw_work_agenda_branches').select('*').order('name').order('id')),
 areas:()=>agendaRows('Áreas',()=>getSupabase().from('vw_my_work_areas').select('*').order('name')),
 tasks:branch=>agendaRows('Tareas',()=>getSupabase().from('work_tasks').select('*').eq('branch_id',branch).order('due_at').order('id')),
 history:id=>agendaRows('Historial',()=>getSupabase().from('work_task_history').select('*').eq('task_id',id).order('changed_at',{ascending:false}).order('id')),
 people:(branch,area)=>call('work_agenda_people',{p_branch:branch,p_area:area}),
 action:(action,data)=>call('work_task_action',{p_action:action,p_data:data})
};
export async function sourceSignals(branch,allowed){const definitions=[
 ['Pedidos operativos','workflow','operations_orders','id,branch_id,status,due_at','due_at',r=>!['COMPLETADO','CANCELADO'].includes(r.status)],
 ['Compras y recepción','suppliers','purchase_orders','id,branch_id,status,required_date','required_date',r=>!['RECIBIDA','CANCELADA'].includes(r.status)],
 ['Calidad diaria','bloodquality','blood_quality_tasks','id,branch_id,status,due_at','due_at',r=>!['COMPLETADA','CANCELADA'].includes(r.status)],
 ['No conformidades','quality','nonconformities','id,branch_id,status,due_date','due_date',r=>!['CERRADA','CANCELADA'].includes(r.status)],
 ['Acciones integradas','actions','integrated_actions','id,branch_id,status,due_date','due_date',r=>!['CERRADA','CANCELADA'].includes(r.status)],
 ['Citas de donación','donors','donor_visits','id,branch_id,status,starts_at','starts_at',r=>['CONFIRMADA','POR_CONFIRMAR'].includes(r.status)]
 ];return Promise.all(definitions.map(async([label,route,table,columns,date,open])=>{if(!allowed.has(route))return {label,route,unavailable:'Módulo no habilitado para este rol'};try{const rows=await agendaRows(label,()=>getSupabase().from(table).select(columns).eq('branch_id',branch).order('id')),pending=rows.filter(open);const today=localDay();return {label,route,pending:pending.length,overdue:pending.filter(r=>r[date]&&(r[date].length===10?r[date]<today:Date.parse(r[date])<Date.now())).length}}catch(e){return {label,route,unavailable:e.message}}}))}
