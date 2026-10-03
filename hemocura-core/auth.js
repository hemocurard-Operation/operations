import { getSupabase } from './supabase.js';

export async function getSession() {
  const supabase = getSupabase();
  const { data, error } = await supabase.auth.getSession();
  if (error) throw error;
  return data.session;
}

export async function signIn(email, password) {
  const supabase = getSupabase();
  console.info('[HEMOCURA_AUTH] signIn');
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) {
    console.error('[HEMOCURA_AUTH_ERROR]', error);
    throw error;
  }
  console.info('[HEMOCURA_AUTH] login OK', data.user?.id);
  return data;
}

export async function signOut() {
  const supabase = getSupabase();
  const { error } = await supabase.auth.signOut();
  if (error) throw error;
  console.info('[HEMOCURA_AUTH] logout OK');
}

export function onAuthChange(callback) {
  const supabase = getSupabase();
  return supabase.auth.onAuthStateChange((event, session) => {
    console.info('[HEMOCURA_AUTH]', event);
    callback(event, session);
  });
}
