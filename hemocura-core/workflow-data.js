import { getSupabase } from './supabase.js';
import { localDay } from './workflow-domain.js';
const sb=()=>getSupabase();
async function rows(label,q){
 const result=[];const pageSize=500;let offset=0;
 while(true){
  const {data,error}=await q.range(offset,offset+pageSize-1);
  if(error){const missing=['42P01','PGRST205','PGRST202'].includes(error.code);throw new Error(missing?'El módulo requiere la migración de ruta operativa del 13/10/2026.':`${label}: ${error.message}`)}
  const page=data||[];result.push(...page);if(page.length<pageSize)return result;offset+=pageSize;
 }
}
async function call(name,args){const {data,error}=await sb().rpc(name,args);if(error)throw new Error(`${error.code==='PGRST202'?'Migración de ruta operativa pendiente':error.message}`);return data}
export const workflowData={
 branches:()=>rows('Sucursales',sb().from('branches').select('id,code,name').eq('active',true).order('name')),
 customers:()=>rows('Clientes',sb().from('customers').select('id,name,active').eq('active',true).order('name')),
 referrers:branch=>rows('Médicos',sb().from('medical_referrers').select('id,branch_id,full_name').or(`branch_id.eq.${branch},branch_id.is.null`).order('full_name')),
 daily:async(branch,date)=>{const r=await rows('Captación y marcadores',sb().from('workflow_daily_sections').select('*').eq('branch_id',branch).eq('report_date',date));return r[0]||null},
 saveDaily:(id,data)=>call('wf_save_daily_sections',{p_report_id:id,p_data:data}),
 visits:branch=>rows('Visitas',sb().from('commercial_visits').select('*').eq('branch_id',branch).order('scheduled_at').order('id')),
 locations:branch=>rows('Ubicaciones',sb().from('commercial_locations').select('*').eq('branch_id',branch)),
 plans:branch=>rows('Planes comerciales',sb().from('commercial_plans').select('*').eq('branch_id',branch).order('cycle_start',{ascending:false})),
 opportunities:branch=>rows('Oportunidades',sb().from('commercial_opportunities').select('*').eq('branch_id',branch).order('created_at',{ascending:false})),
 closeCommitment:(branch,id,evidence)=>call('wf_close_commitment',{p_branch:branch,p_visit:id,p_evidence:evidence}),
 catalog:()=>rows('Catálogo de insumos',sb().from('workflow_supply_catalog').select('*').order('code')),
 createCatalogRequisition:(header,lines)=>call('wf_create_catalog_requisition',{p_header:header,p_lines:lines}),
 mapSupply:(branch,id,data)=>call('wf_map_supply_item',{p_branch:branch,p_item:id,p_data:data}),
 products:()=>rows('Productos',sb().from('products').select('id,code,name,unit_of_measure').eq('active',true).order('name')),
 saveLocation:(branch,customer,data)=>call('wf_save_location',{p_branch:branch,p_customer:customer,p_data:data}),
 createPlan:(branch,data)=>call('wf_create_plan',{p_branch:branch,p_data:data}),
 saveVisit:(branch,id,data)=>call('wf_save_visit',{p_branch:branch,p_id:id,p_data:data}),
 saveOpportunity:(branch,id,data)=>call('wf_save_opportunity',{p_branch:branch,p_id:id,p_data:data}),
 resources:branch=>rows('Cámaras',sb().from('hyperbaric_resources').select('*').eq('branch_id',branch).eq('active',true).order('name')),
 createResource:(branch,data)=>call('wf_create_resource',{p_branch:branch,p_data:data}),
 appointments:branch=>rows('Agenda hiperbárica',sb().from('hyperbaric_appointments').select('*').eq('branch_id',branch).order('starts_at',{ascending:false}).order('id')),
 sessions:branch=>rows('Sesiones',sb().from('hyperbaric_sessions').select('*').eq('branch_id',branch).order('performed_at',{ascending:false}).order('id')),
 finances:branch=>rows('Facturas hiperbáricas',sb().from('vw_hyperbaric_finance').select('*').eq('branch_id',branch).order('invoice_date',{ascending:false})),
 saveAppointment:(branch,id,data)=>call('wf_save_appointment',{p_branch:branch,p_id:id,p_data:data}),
 recordSession:(id,data)=>call('wf_record_session',{p_appointment:id,p_data:data}),
 invoiceSession:(id,invoice,date)=>call('wf_invoice_session',{p_session:id,p_invoice:invoice,p_date:date}),
 paySession:(id,request,data)=>call('wf_pay_session',{p_charge:id,p_request:request,p_data:data}),
 serviceEvents:(branch,date,shift)=>rows('Sesiones para ventas',sb().from('workflow_service_events').select('*').eq('branch_id',branch).eq('service_date',date).eq('shift',shift)),
 receipts:(branch,date)=>rows('Cobros del día',sb().from('vw_workflow_receipts').select('*').eq('branch_id',branch).eq('payment_date',date)),
 shiftSales:(branch,date)=>rows('Ventas por turno',sb().from('vw_workflow_shift_sales').select('*').eq('branch_id',branch).eq('operational_date',date).order('source_type').order('source_id')),
 templates:branch=>rows('Plantillas de calidad',sb().from('blood_quality_templates').select('*').eq('branch_id',branch).order('title')),
 createQualityTemplate:(branch,data)=>call('wf_create_quality_template',{p_branch:branch,p_data:data}),
 reviewQualityTemplate:(branch,id,note)=>call('wf_review_quality_template',{p_branch:branch,p_template:id,p_note:note}),
 generateQualityTasks:(branch,date,shift)=>call('wf_generate_quality_tasks',{p_branch:branch,p_date:date,p_shift:shift}),
 qualityAlerts:branch=>rows('Alertas de calidad',sb().from('vw_open_management_alerts').select('id,branch_id,title,severity,status,description').eq('branch_id',branch).order('id')),
 nonconformities:branch=>rows('No conformidades',sb().from('nonconformities').select('id,code,branch_id,description,status,due_date').eq('branch_id',branch).order('id')),
 tasksPeriod:(branch,start,end,shift)=>{let q=sb().from('blood_quality_tasks').select('*').eq('branch_id',branch).gte('task_date',start).lte('task_date',end);if(shift)q=q.eq('shift',shift);return rows('Calidad por período',q.order('task_date').order('id'))},
 tasks:(branch,date,shift)=>rows('Calidad diaria',sb().from('blood_quality_tasks').select('*').eq('branch_id',branch).eq('task_date',date).eq('shift',shift).order('due_at')),
 qualityTask:(branch,id,data)=>call('wf_quality_task',{p_branch:branch,p_id:id,p_data:data}),
 transfers:branch=>rows('Transferencias',sb().from('blood_transfers').select('*').or(`branch_id.eq.${branch},destination_branch_id.eq.${branch}`).order('sent_at',{ascending:false}).order('id')),
 transferLines:branch=>rows('Unidades transferidas',sb().from('vw_workflow_transfer_lines').select('*').or(`branch_id.eq.${branch},destination_branch_id.eq.${branch}`).order('id')),
 availableUnits:branch=>rows('Unidades disponibles',sb().from('blood_inventory_units').select('id,unit_code,branch_id,component_name,abo,rh,expiry_date,quantity').eq('branch_id',branch).eq('screening_status','APTO').eq('inventory_status','DISPONIBLE').gte('expiry_date',localDay()).order('expiry_date')),
 sendTransfer:(branch,destination,batch,units,evidence)=>call('wf_send_transfer',{p_branch:branch,p_destination:destination,p_batch:batch,p_units:units,p_evidence:evidence}),
 receiveTransfer:(id,units,evidence,condition)=>call('wf_receive_transfer',{p_transfer:id,p_units:units,p_evidence:evidence,p_condition:condition}),
 reviewReceipt:(id,unit,accept,evidence)=>call('wf_review_transfer_receipt',{p_transfer:id,p_unit:unit,p_accept:accept,p_evidence:evidence})
};
