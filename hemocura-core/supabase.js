import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';
import { CONFIG, validateConfig } from '../js/config.js';

let client = null;

export function getSupabase() {
  if (client) return client;

  const problems = validateConfig();
  if (problems.length) {
    console.error('[HEMOCURA_CONFIG]', problems);
    throw new Error(problems.join(' · '));
  }

  console.info('[HEMOCURA_SUPABASE] creando cliente');
  client = createClient(
    CONFIG.SUPABASE_URL,
    CONFIG.SUPABASE_PUBLISHABLE_KEY,
    {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true
      }
    }
  );
  console.info('[HEMOCURA_SUPABASE] cliente OK');
  return client;
}
