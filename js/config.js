// Configuración pública del frontend HemoCura.
export const CONFIG = {
  SUPABASE_URL: 'https://tiothqiljipdamgudvcb.supabase.co',
  SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_OO9fniHIjPS6iueOWPSIHg_p1W-iWn0',
  APP_BASE: '/operations/'
};

export function validateConfig() {
  const problems = [];

  if (
    !CONFIG.SUPABASE_URL ||
    CONFIG.SUPABASE_URL.includes('TU-PROYECTO') ||
    CONFIG.SUPABASE_URL.includes('TU_PROJECT_REF_REAL')
  ) {
    problems.push('SUPABASE_URL no configurada');
  }

  if (
    !CONFIG.SUPABASE_PUBLISHABLE_KEY ||
    CONFIG.SUPABASE_PUBLISHABLE_KEY.includes('TU_CLAVE')
  ) {
    problems.push('SUPABASE_PUBLISHABLE_KEY no configurada');
  }

  return problems;
}
