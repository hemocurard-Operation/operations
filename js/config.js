// Configuración pública del frontend HemoCura.
// ARCHIVO PROTEGIDO: no sustituir durante actualizaciones.

export const CONFIG = {
  SUPABASE_URL: 'https://tiothqiljipdamgudvcb.supabase.co',
  SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_OO9fniHIjPS6iueOWPSIHg_p1W-iWn0L',
  APP_BASE: '/operations/'
};

export function validateConfig() {
  const problems = [];

  // Validar URL de Supabase
  try {
    const url = new URL(CONFIG.SUPABASE_URL);

    if (
      url.protocol !== 'https:' ||
      !url.hostname.endsWith('.supabase.co') ||
      url.pathname !== '/'
    ) {
      problems.push('SUPABASE_URL tiene un formato inválido');
    }
  } catch {
    problems.push('SUPABASE_URL no es una URL válida');
  }

  // Detectar placeholders
  if (
    !CONFIG.SUPABASE_URL ||
    CONFIG.SUPABASE_URL.includes('TU-PROYECTO') ||
    CONFIG.SUPABASE_URL.includes('TU_PROJECT_REF_REAL')
  ) {
    problems.push('SUPABASE_URL no configurada');
  }

  // Validar Publishable Key
  if (
    !CONFIG.SUPABASE_PUBLISHABLE_KEY ||
    CONFIG.SUPABASE_PUBLISHABLE_KEY.includes('TU_CLAVE') ||
    !CONFIG.SUPABASE_PUBLISHABLE_KEY.startsWith('sb_publishable_')
  ) {
    problems.push('SUPABASE_PUBLISHABLE_KEY inválida o no configurada');
  }

  // Validar GitHub Pages base path
  if (CONFIG.APP_BASE !== '/operations/') {
    problems.push('APP_BASE debe ser /operations/');
  }

  return [...new Set(problems)];
}
