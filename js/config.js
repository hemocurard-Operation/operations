// HemoCura v0.2.0 — configuración pública del frontend.
// EDITAR este archivo en GitHub.com antes de probar el login.
// La publishable/anon key puede estar en el frontend; la seguridad depende de RLS.
// NUNCA coloque service_role ni secret keys aquí.

export const CONFIG = {
  SUPABASE_URL: 'https://TU-PROYECTO.supabase.co',
  SUPABASE_PUBLISHABLE_KEY: 'TU_CLAVE_PUBLICABLE',
  APP_BASE: '/operations/'
};

export function validateConfig() {
  const problems = [];
  if (!CONFIG.SUPABASE_URL || CONFIG.SUPABASE_URL.includes('TU-PROYECTO')) {
    problems.push('SUPABASE_URL no configurada');
  }
  if (!CONFIG.SUPABASE_PUBLISHABLE_KEY || CONFIG.SUPABASE_PUBLISHABLE_KEY.includes('TU_CLAVE')) {
    problems.push('SUPABASE_PUBLISHABLE_KEY no configurada');
  }
  return problems;
}
