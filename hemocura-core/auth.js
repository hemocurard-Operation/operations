import { getSupabase } from './supabase.js';
export async function getSession(){
  const {data,error}=await getSupabase().auth.getSession(); if(error) throw error; return data.session;
}
export async function signIn(email,password){
  console.info('[HEMOCURA_AUTH] signIn');
  const {data,error}=await getSupabase().auth.signInWithPassword({email,password});
  if(error){console.error('[HEMOCURA_AUTH_ERROR]',error);throw error}
  console.info('[HEMOCURA_AUTH] login OK',data.user?.id); return data;
}
export async function signOut(){ const {error}=await getSupabase().auth.signOut(); if(error) throw error; console.info('[HEMOCURA_AUTH] logout OK'); }
export function onAuthChange(cb){ return getSupabase().auth.onAuthStateChange((event,session)=>{console.info('[HEMOCURA_AUTH]',event);cb(event,session)}); }
