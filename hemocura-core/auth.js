import { getSupabase } from './supabase.js';
import { classifyError, diagnosticFromCode } from './diagnostic-engine.js';

function throwDiagnostic(error,context){
  const d=classifyError(error,context);
  const e=new Error(`[${d.code}] ${d.message} · ${d.action}`);
  e.diagnostic=d;
  throw e;
}

export async function getSession(){
  try{
    const {data,error}=await getSupabase().auth.getSession();
    if(error) throw error;
    return data.session;
  }catch(error){throwDiagnostic(error,{subsystem:'AUTH',route:'session'})}
}

export async function signIn(email,password){
  console.info('[HEMOCURA_AUTH] signIn');
  try{
    const {data,error}=await getSupabase().auth.signInWithPassword({email,password});
    if(error) throw error;
    console.info('[HEMOCURA_AUTH] login OK',data.user?.id);
    return data;
  }catch(error){
    console.error('[HEMOCURA_AUTH_ERROR]',error);
    throwDiagnostic(error,{subsystem:'AUTH',route:'login'});
  }
}

export async function signOut(){
  try{
    const {error}=await getSupabase().auth.signOut();
    if(error) throw error;
    console.info('[HEMOCURA_AUTH] logout OK');
  }catch(error){throwDiagnostic(error,{subsystem:'AUTH',route:'logout'})}
}

export function onAuthChange(cb){
  return getSupabase().auth.onAuthStateChange((event,session)=>{
    console.info('[HEMOCURA_AUTH]',event);
    cb(event,session);
  });
}
