import { getSupabase } from './supabase.js';
const sb=()=>getSupabase();
async function q(label,p){const {data,error}=await p;if(error)throw new Error(`${label}: ${error.message}`);return data||[]}
async function rpc(label,name,args){const {data,error}=await sb().rpc(name,args);if(error)throw new Error(`${label}: ${error.message}`);return data}
export const commandData={
  branches:()=>q('Sucursales',sb().from('branches').select('id,code,name').eq('active',true).order('name')),
  today:()=>q('Operación diaria',sb().from('vw_daily_branch_operations').select('*').order('branch_name')),
  reconciliation:()=>q('Conciliación cierre',sb().from('vw_daily_close_reconciliation').select('*').order('branch_name')),
  recentCloses:(limit=30)=>q('Cierres recientes',sb().from('daily_operational_closes').select('id,close_date,branch_id,status,responsible_name,screening_lots,manual_inventory,manual_dispatches,equipment_snapshot,donors_count,effective_donations,screened_units,available_units,dispatched_units,invoiced_amount,notes,report_version,last_modified_by,submitted_by,submitted_at,closed_by,closed_at,reopened_by,reopened_at,reopen_reason,updated_at').order('close_date',{ascending:false}).order('updated_at',{ascending:false}).limit(limit)),
  dailyReport:async(closeDate,branchId)=>{const {data,error}=await sb().from('daily_operational_closes').select('*').eq('close_date',closeDate).eq('branch_id',branchId).maybeSingle();if(error)throw new Error(`Reporte diario: ${error.message}`);return data||null},
  previousDailyReport:async(closeDate,branchId)=>{const {data,error}=await sb().from('daily_operational_closes').select('*').eq('branch_id',branchId).lt('close_date',closeDate).order('close_date',{ascending:false}).limit(1).maybeSingle();if(error)throw new Error(`Reporte previo: ${error.message}`);return data||null},
  reportVersions:(reportId)=>q('Versiones del reporte',sb().from('daily_operational_report_versions').select('id,report_id,report_version,status,changed_by,changed_at,snapshot').eq('report_id',reportId).order('report_version',{ascending:false}).limit(50)),
  saveDailyReport:async p=>rpc('Guardar reporte diario','save_daily_operational_report',{
    p_close_date:p.close_date,
    p_branch_id:p.branch_id,
    p_responsible_name:p.responsible_name||null,
    p_screening_lots:p.screening_lots||[],
    p_manual_inventory:p.manual_inventory||{},
    p_manual_dispatches:p.manual_dispatches||[],
    p_equipment_snapshot:p.equipment_snapshot||[],
    p_notes:p.notes||null,
    p_status:'BORRADOR'
  }),
  submitDailyReport:(reportId)=>rpc('Enviar a revisión','submit_daily_operational_report',{p_report_id:reportId}),
  closeDailyReport:(reportId)=>rpc('Cerrar reporte','close_daily_operational_report',{p_report_id:reportId}),
  reopenDailyReport:(reportId,reason)=>rpc('Reabrir reporte','reopen_daily_operational_report',{p_report_id:reportId,p_reason:reason}),
  scorecard:()=>q('Scorecard',sb().from('vw_management_scorecard').select('*').order('management_score',{ascending:true})),
  exceptions:()=>q('Excepciones',sb().from('operational_exceptions').select('*').order('exception_date',{ascending:false}).limit(300)),
  actions:()=>q('Acciones',sb().from('vw_management_action_portfolio').select('*').limit(300)),
  closeBranch:async(branchId,notes)=>rpc('Cierre','capture_daily_operational_close',{p_branch_id:branchId,p_notes:notes||null}),
  createException:async p=>{const {data,error}=await sb().from('operational_exceptions').insert(p).select('*').single();if(error)throw new Error(`Excepción: ${error.message}`);return data},
  createAction:async p=>{const {data,error}=await sb().from('management_actions').insert(p).select('*').single();if(error)throw new Error(`Acción: ${error.message}`);return data}
};
