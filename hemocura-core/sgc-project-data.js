import {getSupabase} from './supabase.js';
export async function sgcRows(label,make){const rows=[];let start=0;for(;;){const{data,error}=await make().range(start,start+499);if(error)throw Error(label+': '+error.message);if(!(data||[]).length)return rows;rows.push(...data);start+=data.length}}
export const sgcApi={
 projects:()=>sgcRows('Proyectos SGC',()=>getSupabase().from('sgc_projects').select('*').order('created_at',{ascending:false}).order('id')),
 members:id=>sgcRows('Equipo',()=>getSupabase().from('sgc_members').select('*').eq('project_id',id).order('user_id')),
 steps:id=>sgcRows('Pasos',()=>getSupabase().from('sgc_steps').select('*').eq('project_id',id).order('step_code')),
 gates:id=>sgcRows('Puertas',()=>getSupabase().from('sgc_gates').select('*').eq('project_id',id).order('gate_code')),
 history:id=>sgcRows('Historial',()=>getSupabase().from('sgc_history').select('id,record_type,record_id,action,actor_id,changed_at,before_data,after_data').eq('project_id',id).order('changed_at',{ascending:false}).order('id')),
 documents:()=>sgcRows('Documentos del SGC',()=>getSupabase().from('document_register').select('id,document_code,title,version,status,source_path,area,approval_request_id,approved_at,approver_user_id').order('document_code').order('id')),
 people:branch=>getSupabase().rpc('work_agenda_people',{p_branch:branch,p_area:'CALIDAD'}).then(({data,error})=>{if(error)throw Error(error.message);return data||[]}),
 action:async(action,data)=>{const{data:result,error}=await getSupabase().rpc('sgc_project_action',{p_action:action,p_data:data});if(error)throw Error(error.message);return result}
};
