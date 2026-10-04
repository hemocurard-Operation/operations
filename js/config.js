// Configuración pública del frontend HemoCura.
// ARCHIVO PROTEGIDO: no sustituir durante actualizaciones.

export const CONFIG = {
  SUPABASE_URL: 'https://tiothqiljipdamgudvcb.supabase.co',
  SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_OO9fniHIjPS6iueOWPSIHg_p1W-iWn0',
  APP_BASE: '/operations/'
};

export function validateConfig() {
  const problems = [];
  const notes = [];

  // =========================================================
  // 1. VALIDAR SUPABASE_URL
  // =========================================================

  if (!CONFIG.SUPABASE_URL) {
    problems.push('SUPABASE_URL no configurada');

    notes.push({
      code: 'CONFIG_URL_EMPTY',
      field: 'SUPABASE_URL',
      level: 'ERROR',
      problem: 'El campo SUPABASE_URL está vacío.',
      expected: 'https://<project-ref>.supabase.co',
      current: CONFIG.SUPABASE_URL || '(vacío)',
      action:
        'Copie el Project URL exacto desde Supabase y péguelo en SUPABASE_URL.'
    });
  }

  if (
    CONFIG.SUPABASE_URL &&
    (
      CONFIG.SUPABASE_URL.includes('TU-PROYECTO') ||
      CONFIG.SUPABASE_URL.includes('TU_PROJECT_REF_REAL')
    )
  ) {
    problems.push('SUPABASE_URL no configurada');

    notes.push({
      code: 'CONFIG_URL_PLACEHOLDER',
      field: 'SUPABASE_URL',
      level: 'ERROR',
      problem: 'SUPABASE_URL todavía contiene un texto de ejemplo.',
      expected: 'https://<project-ref>.supabase.co',
      current: CONFIG.SUPABASE_URL,
      action:
        'Sustituya el texto de ejemplo por el Project URL real de Supabase.'
    });
  }

  try {
    const url = new URL(CONFIG.SUPABASE_URL);

    if (url.protocol !== 'https:') {
      problems.push('SUPABASE_URL debe usar HTTPS');

      notes.push({
        code: 'CONFIG_URL_PROTOCOL',
        field: 'SUPABASE_URL',
        level: 'ERROR',
        problem: `El protocolo actual es "${url.protocol}".`,
        expected: 'https:',
        current: url.protocol,
        action:
          'Cambie la URL para que comience con https://.'
      });
    }

    if (!url.hostname.endsWith('.supabase.co')) {
      problems.push('SUPABASE_URL no apunta a Supabase');

      notes.push({
        code: 'CONFIG_URL_HOST',
        field: 'SUPABASE_URL',
        level: 'ERROR',
        problem:
          'El hostname no termina en .supabase.co.',
        expected: '<project-ref>.supabase.co',
        current: url.hostname,
        action:
          'Copie nuevamente el Project URL desde Supabase. No use la URL de GitHub Pages.'
      });
    }

    if (url.pathname !== '/') {
      problems.push('SUPABASE_URL contiene una ruta adicional');

      notes.push({
        code: 'CONFIG_URL_PATH',
        field: 'SUPABASE_URL',
        level: 'ERROR',
        problem:
          `La URL contiene la ruta "${url.pathname}".`,
        expected: '/',
        current: url.pathname,
        action:
          'Elimine rutas como /operations/. La URL de Supabase debe terminar en .supabase.co.'
      });
    }

    if (url.search || url.hash) {
      problems.push('SUPABASE_URL contiene parámetros no permitidos');

      notes.push({
        code: 'CONFIG_URL_EXTRA',
        field: 'SUPABASE_URL',
        level: 'ERROR',
        problem:
          'La URL contiene query string o fragmentos.',
        expected: 'https://<project-ref>.supabase.co',
        current: CONFIG.SUPABASE_URL,
        action:
          'Use únicamente el Project URL base de Supabase.'
      });
    }
  } catch (error) {
    problems.push('SUPABASE_URL no es una URL válida');

    notes.push({
      code: 'CONFIG_URL_INVALID',
      field: 'SUPABASE_URL',
      level: 'ERROR',
      problem:
        'JavaScript no pudo interpretar SUPABASE_URL como una URL.',
      expected: 'https://<project-ref>.supabase.co',
      current: CONFIG.SUPABASE_URL || '(vacío)',
      action:
        'Revise errores de escritura, espacios, comillas o caracteres adicionales.',
      technical:
        error?.message || 'URL inválida'
    });
  }

  // =========================================================
  // 2. VALIDAR SUPABASE_PUBLISHABLE_KEY
  // =========================================================

  if (!CONFIG.SUPABASE_PUBLISHABLE_KEY) {
    problems.push('SUPABASE_PUBLISHABLE_KEY no configurada');

    notes.push({
      code: 'CONFIG_KEY_EMPTY',
      field: 'SUPABASE_PUBLISHABLE_KEY',
      level: 'ERROR',
      problem:
        'La Publishable Key está vacía.',
      expected: 'sb_publishable_...',
      current: '(vacío)',
      action:
        'Copie la Publishable Key pública desde Supabase.'
    });
  }

  if (
    CONFIG.SUPABASE_PUBLISHABLE_KEY &&
    CONFIG.SUPABASE_PUBLISHABLE_KEY.includes('TU_CLAVE')
  ) {
    problems.push('SUPABASE_PUBLISHABLE_KEY no configurada');

    notes.push({
      code: 'CONFIG_KEY_PLACEHOLDER',
      field: 'SUPABASE_PUBLISHABLE_KEY',
      level: 'ERROR',
      problem:
        'La clave todavía contiene un texto de ejemplo.',
      expected: 'sb_publishable_...',
      current: 'Placeholder detectado',
      action:
        'Sustituya TU_CLAVE por la Publishable Key real.'
    });
  }

  if (
    CONFIG.SUPABASE_PUBLISHABLE_KEY &&
    !CONFIG.SUPABASE_PUBLISHABLE_KEY.startsWith('sb_publishable_')
  ) {
    problems.push(
      'SUPABASE_PUBLISHABLE_KEY tiene un formato inesperado'
    );

    notes.push({
      code: 'CONFIG_KEY_FORMAT',
      field: 'SUPABASE_PUBLISHABLE_KEY',
      level: 'ERROR',
      problem:
        'La clave no comienza con sb_publishable_.',
      expected: 'sb_publishable_...',
      current:
        maskKey(CONFIG.SUPABASE_PUBLISHABLE_KEY),
      action:
        'Confirme que está usando la Publishable Key pública y no una Secret Key o service_role.'
    });
  }

  if (
    CONFIG.SUPABASE_PUBLISHABLE_KEY?.startsWith('sb_secret_')
  ) {
    problems.push(
      'Se detectó una Secret Key en el frontend'
    );

    notes.push({
      code: 'CONFIG_SECRET_KEY',
      field: 'SUPABASE_PUBLISHABLE_KEY',
      level: 'CRITICAL',
      problem:
        'Una clave secreta no debe estar en código público de GitHub Pages.',
      expected: 'sb_publishable_...',
      current: maskKey(CONFIG.SUPABASE_PUBLISHABLE_KEY),
      action:
        'Retire inmediatamente la Secret Key y use únicamente una Publishable Key.'
    });
  }

  // =========================================================
  // 3. VALIDAR APP_BASE
  // =========================================================

  if (!CONFIG.APP_BASE) {
    problems.push('APP_BASE no configurado');

    notes.push({
      code: 'CONFIG_APP_BASE_EMPTY',
      field: 'APP_BASE',
      level: 'ERROR',
      problem:
        'APP_BASE está vacío.',
      expected: '/operations/',
      current: CONFIG.APP_BASE || '(vacío)',
      action:
        'Defina APP_BASE como /operations/.'
    });
  }

  if (CONFIG.APP_BASE !== '/operations/') {
    problems.push('APP_BASE debe ser /operations/');

    notes.push({
      code: 'CONFIG_APP_BASE_INVALID',
      field: 'APP_BASE',
      level: 'ERROR',
      problem:
        'La ruta base no coincide con la ubicación de GitHub Pages.',
      expected: '/operations/',
      current: CONFIG.APP_BASE,
      action:
        'Cambie APP_BASE exactamente a /operations/.'
    });
  }

  // =========================================================
  // 4. RESULTADO POSITIVO
  // =========================================================

  if (problems.length === 0) {
    notes.push({
      code: 'CONFIG_OK',
      field: 'CONFIG',
      level: 'OK',
      problem: null,
      expected: null,
      current: {
        supabaseHost: getSupabaseHost(),
        publishableKey: maskKey(
          CONFIG.SUPABASE_PUBLISHABLE_KEY
        ),
        appBase: CONFIG.APP_BASE
      },
      action:
        'La configuración local tiene formato válido. El siguiente paso es probar conectividad y autenticación real contra Supabase.'
    });
  }

  return {
    ok: problems.length === 0,
    problems: [...new Set(problems)],
    notes
  };
}


// =========================================================
// HELPERS DE DIAGNÓSTICO
// =========================================================

export function maskKey(key = '') {
  if (!key) return '(vacía)';

  if (key.length <= 12) {
    return '********';
  }

  return `${key.slice(0, 14)}…${key.slice(-4)}`;
}


export function getSupabaseHost() {
  try {
    return new URL(CONFIG.SUPABASE_URL).hostname;
  } catch {
    return '(URL inválida)';
  }
}
