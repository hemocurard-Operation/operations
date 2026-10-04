import { getSupabase } from './supabase.js';
const sb=()=>getSupabase();

async function one(label,p){
  const {data,error}=await p;
  if(error) throw new Error(`${label}: ${error.message}`);
  return data;
}
async function many(label,p){
  const {data,error}=await p;
  if(error) throw new Error(`${label}: ${error.message}`);
  return data||[];
}

export const accessData={
  context:()=>one('Contexto de seguridad',sb().from('vw_my_security_context').select('*').single()),
  permissions:()=>many('Permisos',sb().from('vw_my_access').select('*').order('module').order('permission_code')),
  readiness:()=>one('Security readiness',sb().from('vw_security_readiness').select('*').single()),
  accessEvents:()=>many('Eventos de acceso',sb().from('access_events').select('*').order('event_time',{ascending:false}).limit(200)),
  log:async(route,permissionCode,allowed,reason=null,branchId=null,metadata=null)=>{
    const {error}=await sb().rpc('log_access_event',{
      p_route:route,
      p_permission_code:permissionCode,
      p_allowed:allowed,
      p_reason:reason,
      p_branch_id:branchId,
      p_metadata:metadata
    });
    if(error) console.warn('[HEMOCURA_ACCESS_LOG]',error);
  }
};
