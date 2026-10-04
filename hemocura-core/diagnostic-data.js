import { getSupabase, testSupabaseConnection } from './supabase.js';
import { maskConfig, normalizeConfigValidation, classifyError, diagnosticFromCode } from './diagnostic-engine.js';

const sb=()=>getSupabase();

async function safe(label,fn){
  try{return {ok:true,data:await fn()}}
  catch(error){return {ok:false,diagnostic:classifyError(error,{subsystem:label})}}
}

export const diagnosticData={
  config(){
    const v=normalizeConfigValidation();
    return {...v,masked:maskConfig()};
  },
  connection:()=>testSupabaseConnection(),

  async session(){
    try{
      const {data,error}=await sb().auth.getSession();
      if(error) throw error;
      if(!data.session) return diagnosticFromCode('SESSION_MISSING','No hay una sesión autenticada.',{subsystem:'AUTH'});
      return diagnosticFromCode('CONFIG_OK',`Sesión activa: ${data.session.user?.email||data.session.user?.id}`,{subsystem:'AUTH'});
    }catch(error){return classifyError(error,{subsystem:'AUTH'})}
  },

  async userHealth(){
    try{
      const {data,error}=await sb().from('vw_current_user_health').select('*').single();
      if(error) throw error;
      if(!data.profile_exists) return diagnosticFromCode('PROFILE_MISSING','El usuario Auth no tiene registro en profiles.',{subsystem:'ACCESS'});
      if(!data.role_exists) return diagnosticFromCode('ROLE_MISSING','El perfil no tiene roles asignados.',{subsystem:'ACCESS'});
      if(!data.permission_exists) return diagnosticFromCode('PERMISSION_MISSING','El usuario no tiene permisos efectivos.',{subsystem:'ACCESS'});
      return diagnosticFromCode('CONFIG_OK',`Perfil/rol/permisos OK · ${data.branch_code||'sin sucursal'}`,{subsystem:'ACCESS',metadata:data});
    }catch(error){return classifyError(error,{subsystem:'ACCESS'})}
  },

  async migrations(){
    try{
      const {data,error}=await sb().from('vw_app_migration_readiness').select('*').order('version');
      if(error) throw error;
      const missing=(data||[]).filter(x=>!x.applied);
      if(missing.length) return {
        ...diagnosticFromCode('MIGRATION_MISSING',`Faltan ${missing.length} migraciones.`,{subsystem:'DATABASE',metadata:{missing}}),
        rows:data||[]
      };
      return {...diagnosticFromCode('CONFIG_OK','Migraciones registradas OK.',{subsystem:'DATABASE'}),rows:data||[]};
    }catch(error){return classifyError(error,{subsystem:'DATABASE',objectType:'VIEW'})}
  },

  async schema(){
    try{
      const {data,error}=await sb().from('vw_app_schema_readiness').select('*').order('object_type').order('object_name');
      if(error) throw error;
      const missing=(data||[]).filter(x=>!x.object_exists);
      if(missing.length) return {
        ...diagnosticFromCode(missing.some(x=>x.object_type==='VIEW')?'VIEW_MISSING':'TABLE_MISSING',
          `Faltan ${missing.length} objetos requeridos.`,
          {subsystem:'DATABASE',metadata:{missing}}),
        rows:data||[]
      };
      return {...diagnosticFromCode('CONFIG_OK','Objetos requeridos OK.',{subsystem:'DATABASE'}),rows:data||[]};
    }catch(error){return classifyError(error,{subsystem:'DATABASE',objectType:'VIEW'})}
  },

  events:async()=>{
    const {data,error}=await sb().from('diagnostic_events').select('*').order('event_time',{ascending:false}).limit(100);
    if(error) throw error;
    return data||[];
  },

  log:async(d)=>{
    try{
      const {error}=await sb().rpc('log_diagnostic_event',{
        p_diagnostic_code:d.code,
        p_severity:d.severity==='OK'?'INFO':d.severity,
        p_subsystem:d.subsystem,
        p_message:d.message,
        p_route:d.route||null,
        p_technical_detail:d.technical||null,
        p_recovery_action:d.action||null,
        p_branch_id:null,
        p_metadata:d.metadata||null
      });
      if(error) console.warn('[HEMOCURA_DIAGNOSTIC_LOG]',error);
    }catch{}
  }
};
