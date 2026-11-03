import { getSupabase } from './supabase.js';
import { CONFIG, validateConfig } from '../js/config.js';

const sb=()=>getSupabase();
async function q(label,p){
  const {data,error}=await p;
  if(error) throw new Error(`${label}: ${error.message}`);
  return data||[];
}

export const releaseData = {
  configCheck(){
    const problems=validateConfig();
    let host='';
    try{host=new URL(CONFIG.SUPABASE_URL).hostname}catch{}
    return {
      ok:problems.length===0,
      problems,
      host,
      appBase:CONFIG.APP_BASE,
      keyPreview:CONFIG.SUPABASE_PUBLISHABLE_KEY
        ? `${CONFIG.SUPABASE_PUBLISHABLE_KEY.slice(0,14)}…${CONFIG.SUPABASE_PUBLISHABLE_KEY.slice(-4)}`
        : 'NO CONFIGURADA'
    };
  },
  schema:()=>q('Schema readiness',sb().from('vw_app_schema_readiness').select('*').order('object_type').order('object_name')),
  migrations:()=>q('Migration readiness',sb().from('vw_app_migration_readiness').select('*').order('version')),
  readiness:async()=>{
    const {data,error}=await sb().from('vw_app_release_readiness').select('*').single();
    if(error) throw new Error(`Release readiness: ${error.message}`);
    return data;
  },
  releases:()=>q('Releases',sb().from('app_releases').select('*').order('created_at',{ascending:false}).limit(50)),
  registerRelease:async(payload)=>{
    const {data,error}=await sb().from('app_releases').upsert(payload,{onConflict:'version'}).select('*').single();
    if(error) throw new Error(`Registrar release: ${error.message}`);
    return data;
  }
};
