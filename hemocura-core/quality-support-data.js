import {getSupabase} from './supabase.js';
import {qualityRows} from './quality-data.js';
export async function qualitySupport(f,allowed){const definitions=[
 ['documents','documents','vw_document_control_status','id,document_code,title,area,version,status,review_status,review_date,review_overdue,approval_status',null],
 ['changes','documents','document_changes','id,document_id,change_date,change_reason,impact_assessment,previous_version,new_version,status,revision',null],
 ['audits','internalaudits','vw_audit_findings_open','id,finding_code,audit_code,branch_id,severity,title,status,due_date,overdue,nonconformity_id,capa_id','branch_id'],
 ['competencies','competencies','vw_staff_competency_gaps','user_id,branch_id,job_role_id,competency_id,competency_code,competency_title,mandatory,valid_until,competency_status','branch_id'],
 ['suppliers','suppliers','supplier_incidents','id,incident_code,supplier_id,branch_id,incident_date,severity,description,nonconformity_id,capa_id,status','branch_id']
 ];const result={};await Promise.all(definitions.map(async([key,route,table,columns,branchColumn])=>{if(!allowed.has(route)){result[key]={available:false,reason:'Módulo no habilitado para su rol',rows:[]};return}try{const rows=await qualityRows(key,()=>{let q=getSupabase().from(table).select(columns);q=key==='competencies'?q.order('user_id').order('branch_id').order('job_role_id').order('competency_id'):q.order('id');if(branchColumn&&f.branchId)q=q.eq(branchColumn,f.branchId);return q});result[key]={available:true,rows,corporate:!branchColumn}}catch(e){result[key]={available:false,rows:[],reason:e.message}}}));return result}
