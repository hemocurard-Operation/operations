// Completar con datos públicos de Supabase.
export const CONFIG = {
  SUPABASE_URL: 'https://TU-PROYECTO.supabase.co',
  SUPABASE_PUBLISHABLE_KEY: 'TU_CLAVE_PUBLICABLE',
  APP_BASE: '/operations/'
};

export function validateConfig() {
  const problems = [];
  if (!CONFIG.SUPABASE_URL || CONFIG.SUPABASE_URL.includes('TU-PROYECTO')) problems.push('SUPABASE_URL no configurada');
  if (!CONFIG.SUPABASE_PUBLISHABLE_KEY || CONFIG.SUPABASE_PUBLISHABLE_KEY.includes('TU_CLAVE')) problems.push('SUPABASE_PUBLISHABLE_KEY no configurada');
  return problems;
}
