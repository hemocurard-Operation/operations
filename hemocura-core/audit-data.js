import { getSupabase } from './supabase.js';
const sb=()=>getSupabase();
async function q(label,p){const {data,error}=await p;if(error)throw new Error(`${label}: ${error.message}`);return data||[]}
export const auditData={
  candidates:()=>q('Candidatos',sb().from('vw_exception_candidates').select('*').limit(300)),
  exceptions:()=>q('Excepciones',sb().from('vw_exception_portfolio').select('*').order('severity').order('exception_date',{ascending:false}).limit(300)),
  audit:()=>q('Auditoría',sb().from('audit_events').select('id,event_time,user_id,branch_id,module,action,entity_table,entity_reference,metadata').order('event_time',{ascending:false}).limit(300)),
  auditSummary:()=>q('Resumen auditoría',sb().from('vw_audit_summary_30d').select('*').order('events',{ascending:false})),
  reviews:()=>q('Revisiones',sb().from('weekly_management_reviews').select('*').order('week_start',{ascending:false}).limit(100)),
  createCandidateException:async r=>{
    const {data,error}=await sb().rpc('create_exception_from_candidate',{
      p_source_type:r.source_type,p_branch_id:r.branch_id||null,p_source_reference:r.source_reference||null,
      p_source_alert_code:r.source_alert_code||null,p_domain:r.domain,p_severity:r.severity,
      p_title:r.title,p_description:r.description
    });
    if(error) throw new Error(`Crear excepción: ${error.message}`); return data;
  },
  createReview:async p=>{const {data,error}=await sb().from('weekly_management_reviews').upsert(p,{onConflict:'week_start,branch_id'}).select('*').single();if(error)throw new Error(`Revisión semanal: ${error.message}`);return data}
};
