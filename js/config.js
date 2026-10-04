// Completar con datos públicos de Supabase.
export const CONFIG = {
  SUPABASE_URL: 'https://https://tiothqiljipdamgudvcb.supabase.co',
  SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_OO9fniHIjPS6iueOWPSIHg_p1W-iWn0',
  APP_BASE: '/operations/'
};

export function validateConfig() {
  const problems = [];
  if (!CONFIG.SUPABASE_URL || CONFIG.SUPABASE_URL.includes('tiothqiljipdamgudvcb')) problems.push('https://https://tiothqiljipdamgudvcb.supabase.co no configurada');
  if (!CONFIG.SUPABASE_PUBLISHABLE_KEY || CONFIG.SUPABASE_PUBLISHABLE_KEY.includes('sb_publishable_OO9fniHIjPS6iueOWPSIHg_p1W-iWn0')) problems.push('sb_publishable_OO9fniHIjPS6iueOWPSIHg_p1W-iWn0 no configurada');
  return problems;
}
