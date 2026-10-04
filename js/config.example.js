// HemoCura — EJEMPLO DE CONFIGURACIÓN v0.30.0
// Copiar como js/config.js SOLO durante configuración inicial.
// El archivo js/config.js productivo es PROTEGIDO y no se incluye en actualizaciones.

export const CONFIG = {
  SUPABASE_URL: 'https://TU-PROJECT-REF.supabase.co',
  SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_TU_CLAVE_PUBLICA',
  APP_BASE: '/operations/'
};

export function maskKey(key='') {
  if (!key) return '(vacía)';
  if (key.length <= 12) return '********';
  return `${key.slice(0,14)}…${key.slice(-4)}`;
}

export function diagnoseConfig() {
  const notes = [];

  const add=(code,level,field,problem,expected,current,action,technical=null)=>{
    notes.push({code,level,field,problem,expected,current,action,technical});
  };

  if (!CONFIG.SUPABASE_URL) {
    add('CONFIG_URL_EMPTY','ERROR','SUPABASE_URL',
      'SUPABASE_URL está vacía.',
      'https://<project-ref>.supabase.co',
      '(vacío)',
      'Copie el Project URL exacto desde Supabase.');
  } else if (
    CONFIG.SUPABASE_URL.includes('TU-PROYECTO') ||
    CONFIG.SUPABASE_URL.includes('TU_PROJECT_REF_REAL') ||
    CONFIG.SUPABASE_URL.includes('TU-PROJECT-REF')
  ) {
    add('CONFIG_URL_PLACEHOLDER','ERROR','SUPABASE_URL',
      'SUPABASE_URL todavía contiene un valor de ejemplo.',
      'https://<project-ref>.supabase.co',
      CONFIG.SUPABASE_URL,
      'Sustituya el placeholder por el Project URL real.');
  }

  if (CONFIG.SUPABASE_URL) {
    try {
      const url=new URL(CONFIG.SUPABASE_URL);

      if (url.protocol !== 'https:') {
        add('CONFIG_URL_PROTOCOL','ERROR','SUPABASE_URL',
          'El Project URL no usa HTTPS.',
          'https:',
          url.protocol,
          'Use el Project URL HTTPS proporcionado por Supabase.');
      }

      if (!url.hostname.endsWith('.supabase.co')) {
        add('CONFIG_URL_HOST','ERROR','SUPABASE_URL',
          'El hostname no corresponde a un proyecto Supabase.',
          '<project-ref>.supabase.co',
          url.hostname,
          'No use la URL de GitHub Pages; copie el Project URL desde Supabase.');
      }

      if (url.pathname !== '/') {
        add('CONFIG_URL_PATH','ERROR','SUPABASE_URL',
          'SUPABASE_URL contiene una ruta adicional.',
          '/',
          url.pathname,
          'Elimine rutas como /operations/. La URL debe terminar en .supabase.co.');
      }

      if (url.search || url.hash) {
        add('CONFIG_URL_EXTRA','ERROR','SUPABASE_URL',
          'SUPABASE_URL contiene parámetros o fragmentos.',
          'URL base sin ?query ni #fragment',
          `${url.search}${url.hash}`,
          'Use únicamente el Project URL base.');
      }
    } catch(error) {
      add('CONFIG_URL_INVALID','ERROR','SUPABASE_URL',
        'SUPABASE_URL no puede interpretarse como URL.',
        'https://<project-ref>.supabase.co',
        CONFIG.SUPABASE_URL,
        'Revise espacios, comillas o caracteres adicionales.',
        error?.message || null);
    }
  }

  if (!CONFIG.SUPABASE_PUBLISHABLE_KEY) {
    add('CONFIG_KEY_EMPTY','ERROR','SUPABASE_PUBLISHABLE_KEY',
      'La Publishable Key está vacía.',
      'sb_publishable_...',
      '(vacío)',
      'Copie la Publishable Key pública desde Supabase.');
  } else {
    if (CONFIG.SUPABASE_PUBLISHABLE_KEY.includes('TU_CLAVE')) {
      add('CONFIG_KEY_PLACEHOLDER','ERROR','SUPABASE_PUBLISHABLE_KEY',
        'La clave contiene un placeholder.',
        'sb_publishable_...',
        maskKey(CONFIG.SUPABASE_PUBLISHABLE_KEY),
        'Sustituya el placeholder por la Publishable Key real.');
    }

    if (CONFIG.SUPABASE_PUBLISHABLE_KEY.startsWith('sb_secret_')) {
      add('CONFIG_SECRET_KEY','CRITICAL','SUPABASE_PUBLISHABLE_KEY',
        'Se detectó una Secret Key en el frontend.',
        'sb_publishable_...',
        maskKey(CONFIG.SUPABASE_PUBLISHABLE_KEY),
        'Retire la Secret Key inmediatamente y use solo una Publishable Key.');
    } else if (!CONFIG.SUPABASE_PUBLISHABLE_KEY.startsWith('sb_publishable_')) {
      add('CONFIG_KEY_FORMAT','ERROR','SUPABASE_PUBLISHABLE_KEY',
        'La clave tiene un formato inesperado.',
        'sb_publishable_...',
        maskKey(CONFIG.SUPABASE_PUBLISHABLE_KEY),
        'Confirme que está usando la Publishable Key pública.');
    }
  }

  if (!CONFIG.APP_BASE) {
    add('CONFIG_APP_BASE_EMPTY','ERROR','APP_BASE',
      'APP_BASE está vacío.',
      '/operations/',
      '(vacío)',
      'Configure APP_BASE exactamente como /operations/.');
  } else if (CONFIG.APP_BASE !== '/operations/') {
    add('CONFIG_APP_BASE_INVALID','ERROR','APP_BASE',
      'APP_BASE no coincide con la ruta GitHub Pages del sistema.',
      '/operations/',
      CONFIG.APP_BASE,
      'Cambie APP_BASE exactamente a /operations/.');
  }

  if (!notes.some(n=>n.level==='ERROR'||n.level==='CRITICAL')) {
    notes.push({
      code:'CONFIG_OK',
      level:'OK',
      field:'CONFIG',
      problem:null,
      expected:null,
      current:{
        supabaseHost:(()=>{try{return new URL(CONFIG.SUPABASE_URL).hostname}catch{return '(URL inválida)'}})(),
        publishableKey:maskKey(CONFIG.SUPABASE_PUBLISHABLE_KEY),
        appBase:CONFIG.APP_BASE
      },
      action:'La configuración tiene formato válido. Continúe con prueba de red, Auth, perfil, rol y RLS.',
      technical:null
    });
  }

  return {
    ok:!notes.some(n=>n.level==='ERROR'||n.level==='CRITICAL'),
    problems:[...new Set(notes.filter(n=>n.level==='ERROR'||n.level==='CRITICAL').map(n=>n.problem))],
    notes
  };
}

// Compatibilidad con v0.29 y anteriores:
// los módulos antiguos esperan un ARRAY de problemas.
export function validateConfig() {
  return diagnoseConfig().problems;
}
