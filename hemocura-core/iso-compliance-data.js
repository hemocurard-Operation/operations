import {allPages} from './data-pages.js';
import {getSupabase} from './supabase.js';
const sb=()=>getSupabase();
export const isoFrameworks=['ISO 9001','ISO 15189'];
export const isoStatuses=['CUMPLE','PARCIAL','NO_CUMPLE','NO_APLICA','PENDIENTE'];

export const isoComplianceData={
  catalog:()=>allPages('Catálogo de cláusulas',sb().from('audit_criteria_catalog').select('*').in('framework',isoFrameworks).eq('active',true).order('framework').order('clause_reference')),

  assessments:(branchId)=>allPages('Autoevaluación ISO',
    branchId
      ? sb().from('iso_clause_assessments').select('*').eq('branch_id',branchId)
      : sb().from('iso_clause_assessments').select('*').is('branch_id',null)
  ),

  evidence:assessmentId=>allPages('Evidencia de cumplimiento',sb().from('iso_clause_evidence').select('*').eq('assessment_id',assessmentId).order('captured_at',{ascending:false})),

  summary:()=>allPages('Resumen de cumplimiento ISO',sb().from('vw_iso_compliance_summary').select('*')),

  upsertAssessment:async({criterionId,branchId,status,responsibleUserId,notes,nextReviewDate})=>{
    const {data,error}=await sb().rpc('iso_clause_assessment_upsert',{
      p_criterion_id:criterionId,
      p_branch_id:branchId||null,
      p_status:status,
      p_responsible_user_id:responsibleUserId||null,
      p_notes:notes||null,
      p_next_review_date:nextReviewDate||null
    });
    if(error)throw new Error(error.message);
    return data;
  },

  addEvidence:async(assessmentId,{evidenceType,title,description,sourceReference,sourceUrl})=>{
    const {data,error}=await sb().from('iso_clause_evidence').insert({
      assessment_id:assessmentId,
      evidence_type:evidenceType||'DOCUMENTO',
      title,
      description:description||null,
      source_reference:sourceReference||null,
      source_url:sourceUrl||null
    }).select('*').single();
    if(error)throw new Error(error.message);
    return data;
  },

  createNonconformity:async(assessmentId,{ownerUserId,dueDate,description})=>{
    const {data,error}=await sb().rpc('iso_clause_assessment_create_nc',{
      p_assessment_id:assessmentId,
      p_owner_user_id:ownerUserId,
      p_due_date:dueDate,
      p_description:description||null
    });
    if(error)throw new Error(error.message);
    return data;
  }
};
