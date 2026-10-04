import { getSupabase } from './supabase.js';
const sb=()=>getSupabase();

async function many(label,p){
  const {data,error}=await p;
  if(error) throw new Error(`${label}: ${error.message}`);
  return data||[];
}

export const approvalData={
  inbox:()=>many('Bandeja aprobaciones',sb().from('vw_approval_inbox').select('*').limit(300)),
  history:()=>many('Historial aprobaciones',sb().from('vw_approval_decision_history').select('*').limit(300)),
  branches:()=>many('Sucursales',sb().from('branches').select('id,code,name').eq('active',true).order('name')),

  request:async p=>{
    const {data,error}=await sb().rpc('create_approval_request',{
      p_action_type:p.action_type,
      p_branch_id:p.branch_id||null,
      p_entity_type:p.entity_type||null,
      p_entity_id:p.entity_id||null,
      p_entity_reference:p.entity_reference||null,
      p_title:p.title,
      p_reason:p.reason,
      p_payload:p.payload||{}
    });
    if(error) throw new Error(`Crear solicitud: ${error.message}`);
    return data;
  },

  decide:async(id,decision,comment,acknowledgement)=>{
    const {data,error}=await sb().rpc('decide_approval_request',{
      p_request_id:id,
      p_decision:decision,
      p_comment:comment,
      p_acknowledgement:acknowledgement
    });
    if(error) throw new Error(`Decidir aprobación: ${error.message}`);
    return data;
  },

  execute:async id=>{
    const {data,error}=await sb().rpc('execute_approved_action',{p_request_id:id});
    if(error) throw new Error(`Ejecutar acción: ${error.message}`);
    return data;
  }
};
