import {getSupabase} from './supabase.js';
const sb=()=>getSupabase();

async function many(label,p){const {data,error}=await p;if(error)throw new Error(`${label}: ${error.message}`);return data||[]}
async function one(label,p){const {data,error}=await p;if(error)throw new Error(`${label}: ${error.message}`);return data}

export const trainingData={
  async currentUser(){const {data:{user},error}=await sb().auth.getUser();if(error)throw error;return user},
  myCatalog:()=>many('Plan de capacitación',sb().from('vw_my_training_catalog').select('*').order('primary_role',{ascending:false})),
  assignment:id=>one('Asignación',sb().from('vw_training_assignment_detail').select('*').eq('assignment_id',id).single()),
  nextAction:id=>one('Siguiente acción',sb().from('vw_training_next_action').select('*').eq('assignment_id',id).single()),
  async ensureAssignment(item,userId){
    if(item.assignment_id)return item.assignment_id;
    const payload={user_id:userId,program_id:item.program_id,job_role_id:item.job_role_id,branch_id:item.branch_id||null,status:'ASIGNADO',source:'AUTO_ROLE'};
    const row=await one('Crear asignación',sb().from('training_assignments').upsert(payload,{onConflict:'user_id,program_id,job_role_id'}).select('id').single());
    return row.id;
  },
  startAssignment:id=>one('Iniciar capacitación',sb().from('training_assignments').update({status:'EN_CURSO',started_at:new Date().toISOString(),updated_at:new Date().toISOString()}).eq('id',id).select('*').single()),
  moduleProgress:assignmentId=>many('Progreso',sb().from('training_module_progress').select('*').eq('assignment_id',assignmentId)),
  completeModule:(assignmentId,userId,moduleCode)=>one('Completar módulo',sb().from('training_module_progress').upsert({assignment_id:assignmentId,user_id:userId,module_code:moduleCode},{onConflict:'assignment_id,module_code'}).select('*').single()),
  reopenModule:(assignmentId,moduleCode)=>one('Reabrir módulo',sb().from('training_module_progress').delete().eq('assignment_id',assignmentId).eq('module_code',moduleCode)),
  questions:programId=>many('Preguntas',sb().from('vw_training_questions').select('*').eq('program_id',programId).order('difficulty').order('question_code')),
  submitQuiz:(assignmentId,answers,startedAt)=>one('Evaluación',sb().rpc('training_submit_quiz',{p_assignment_id:assignmentId,p_answers:answers,p_started_at:startedAt})),
  tutor:(action,role,question)=>one('Tutor',sb().functions.invoke('training-tutor',{body:{action,role,question}})),
  instructorQueue:()=>many('Cola del instructor',sb().from('vw_training_instructor_queue').select('*').order('due_date',{ascending:true,nullsFirst:false})),
  profiles:()=>many('Personal',sb().from('profiles').select('id,full_name,branch_id').order('full_name')),
  branches:()=>many('Sucursales',sb().from('branches').select('id,name,code').eq('active',true).order('name')),
  jobRoles:()=>many('Puestos',sb().from('job_roles').select('id,role_code,title').eq('active',true).order('title')),
  assignJobRole:(userId,jobRoleId,branchId,primaryRole=true,startDate=null)=>one('Asignar puesto',sb().rpc('training_assign_job_role',{p_user_id:userId,p_job_role_id:jobRoleId,p_branch_id:branchId,p_primary_role:primaryRole,p_start_date:startDate||new Date().toISOString().slice(0,10)})),
  async observePractice(assignmentId,taskCode,result,evidenceReference,notes){
    const a=await this.assignment(assignmentId);const u=await this.currentUser();
    const task=(a.practices||[]).find(x=>x.code===taskCode);if(!task)throw new Error('Práctica no pertenece al programa.');
    const payload={assignment_id:assignmentId,training_id:a.training_id,user_id:a.user_id,competency_id:a.competency_id,branch_id:a.branch_id,role_code:a.job_role_code,task_code:taskCode,task_label:task.label,result,observed_by:u.id,evidence_reference:evidenceReference||null,notes:notes||null};
    const existing=await many('Evidencia existente',sb().from('training_practical_evidence').select('id').eq('assignment_id',assignmentId).eq('task_code',taskCode).limit(1));
    if(existing[0])return one('Actualizar práctica',sb().from('training_practical_evidence').update(payload).eq('id',existing[0].id).select('*').single());
    return one('Registrar práctica',sb().from('training_practical_evidence').insert(payload).select('*').single());
  },
  finalize:(assignmentId,notes)=>one('Certificar competencia',sb().rpc('training_finalize_competency',{p_assignment_id:assignmentId,p_notes:notes||null})),
  authorizeUse:(assignmentId,scopeCode,description)=>one('Autorizar uso',sb().rpc('training_authorize_system_use',{p_assignment_id:assignmentId,p_scope_code:scopeCode,p_scope_description:description})),
  revokeCertificate:(code,reason)=>one('Revocar certificado',sb().rpc('training_revoke_certificate',{p_cert_code:code,p_reason:reason})),
  verifyCertificate:code=>one('Verificar certificado',sb().rpc('verify_training_certificate',{p_code:code})),
  myCertificates:userId=>many('Certificados',sb().from('vw_training_certificate_status').select('*').eq('user_id',userId).order('issued_at',{ascending:false})),
  recertification:()=>many('Recertificación',sb().from('vw_training_recertification_alerts').select('*').order('days_remaining')),
  analytics:()=>many('Analítica',sb().from('vw_training_analytics').select('*').order('training_title')),
  managementInput:()=>one('Entrada de dirección',sb().from('vw_training_management_review_input').select('*').single()),
  jobRoleCompliance:()=>many('Cumplimiento por puesto',sb().from('vw_training_compliance_by_job_role').select('*').order('compliance_pct')),
  competencyCompliance:()=>many('Cumplimiento por competencia',sb().from('vw_training_compliance_by_competency').select('*').order('compliance_pct')),
  criticalRisk:()=>many('Riesgo crítico',sb().from('vw_training_critical_process_risk').select('*').order('people_with_gap',{ascending:false})),
  contentVersion:()=>one('Versión formativa',sb().from('training_content_versions').select('id,version_code,title,status,change_summary,effective_from,controlled_document_id').eq('version_code','TRN-1.0-RC').single()),
  controlledDocument:()=>one('Documento controlado',sb().from('document_register').select('id,document_code,title,version,status,effective_date,review_date').eq('document_code','HC-TRN-SUITE-001').single()),
  programs:()=>many('Programas',sb().from('training_programs').select('*').order('program_code'))
};
