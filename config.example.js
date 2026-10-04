// HemoCura — EJEMPLO DE CONFIGURACIÓN
// Copiar como js/config.js SOLO durante la configuración inicial.
// NO incluir js/config.js real en actualizaciones o paquetes SAFE PATCH.

export const CONFIG = {
  SUPABASE_URL: 'https://TU-PROJECT-REF.supabase.co',
  SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_TU_CLAVE_PUBLICA',
  APP_BASE: '/operations/'
};

export function validateConfig() {
  const problems = [];

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

  if (
    !CONFIG.SUPABASE_PUBLISHABLE_KEY ||
    (!CONFIG.SUPABASE_PUBLISHABLE_KEY.startsWith('sb_publishable_') &&
     CONFIG.SUPABASE_PUBLISHABLE_KEY.split('.').length !== 3)
  ) {
    problems.push('SUPABASE_PUBLISHABLE_KEY inválida o no configurada');
  }

  if (CONFIG.APP_BASE !== '/operations/') {
    problems.push('APP_BASE debe ser /operations/');
  }

  return problems;
}
