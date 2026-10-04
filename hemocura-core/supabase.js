import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';
import { CONFIG } from '../js/config.js';
import { normalizeConfigValidation, diagnosticFromCode, formatDiagnostic } from './diagnostic-engine.js';

let client=null;

export function getSupabase(){
  if(client) return client;

  const validation=normalizeConfigValidation();
  if(!validation.ok){
    const d=diagnosticFromCode('CONFIG_URL_INVALID',
      validation.problems.join(' · '),
      {subsystem:'CONFIG'});
    console.error('[HEMOCURA_CONFIG]',d);
    const e=new Error(formatDiagnostic(d));
    e.diagnostic=d;
    throw e;
  }

  console.info('[HEMOCURA_SUPABASE] creando cliente');
  client=createClient(CONFIG.SUPABASE_URL,CONFIG.SUPABASE_PUBLISHABLE_KEY,{
    auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}
  });
  console.info('[HEMOCURA_SUPABASE] cliente OK');
  return client;
}

export async function testSupabaseConnection(){
  try{
    const {error}=await getSupabase().from('branches').select('id').limit(1);
    if(error) throw error;
    return diagnosticFromCode('CONFIG_OK','Supabase respondió correctamente.',{subsystem:'SUPABASE'});
  }catch(error){
    const msg=String(error?.message||error);
    const code=msg.toLowerCase().includes('failed to fetch')?'SUPABASE_UNREACHABLE':
      (msg.toLowerCase().includes('permission denied')?'RLS_DENIED':'APP_ERROR');
    const d=diagnosticFromCode(code,msg,{subsystem:'SUPABASE',technical:error?.details||error?.hint||null});
    d.ok=false;
    return d;
  }
}
