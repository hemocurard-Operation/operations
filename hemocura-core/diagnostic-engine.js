import { CONFIG, validateConfig } from '../js/config.js';

export const DIAGNOSTIC_CATALOG={
  CONFIG_OK:{severity:'INFO',subsystem:'CONFIG',action:'Continuar con conectividad y autenticación.'},
  CONFIG_URL_EMPTY:{severity:'ERROR',subsystem:'CONFIG',action:'Configure SUPABASE_URL.'},
  CONFIG_URL_INVALID:{severity:'ERROR',subsystem:'CONFIG',action:'Corrija el Project URL.'},
  CONFIG_URL_HOST:{severity:'ERROR',subsystem:'CONFIG',action:'Use el Project URL de Supabase.'},
  CONFIG_URL_PATH:{severity:'ERROR',subsystem:'CONFIG',action:'Elimine /operations/ de SUPABASE_URL.'},
  CONFIG_KEY_EMPTY:{severity:'ERROR',subsystem:'CONFIG',action:'Configure la Publishable Key.'},
  CONFIG_KEY_FORMAT:{severity:'ERROR',subsystem:'CONFIG',action:'Use una Publishable Key válida.'},
  CONFIG_SECRET_KEY:{severity:'CRITICAL',subsystem:'CONFIG',action:'Retire la Secret Key del frontend.'},
  CONFIG_APP_BASE_INVALID:{severity:'ERROR',subsystem:'CONFIG',action:'Use APP_BASE=/operations/.'},

  NETWORK_FAILED:{severity:'ERROR',subsystem:'NETWORK',action:'Revise conexión, DNS, firewall y Project URL.'},
  SUPABASE_UNREACHABLE:{severity:'ERROR',subsystem:'SUPABASE',action:'Revise Project URL y disponibilidad del proyecto.'},

  AUTH_INVALID_CREDENTIALS:{severity:'WARN',subsystem:'AUTH',action:'Revise correo y contraseña.'},
  AUTH_EMAIL_NOT_CONFIRMED:{severity:'WARN',subsystem:'AUTH',action:'Confirme el correo o revise la política Auth en Supabase.'},
  AUTH_FAILED:{severity:'ERROR',subsystem:'AUTH',action:'Revise Auth logs y configuración del proyecto.'},
  SESSION_MISSING:{severity:'INFO',subsystem:'AUTH',action:'Inicie sesión.'},

  PROFILE_MISSING:{severity:'ERROR',subsystem:'ACCESS',action:'Cree el registro profiles para el usuario Auth.'},
  ROLE_MISSING:{severity:'ERROR',subsystem:'ACCESS',action:'Asigne al menos un rol en user_roles.'},
  PERMISSION_MISSING:{severity:'ERROR',subsystem:'ACCESS',action:'Revise role_permissions y el rol del usuario.'},
  RLS_DENIED:{severity:'ERROR',subsystem:'RLS',action:'Revise sucursal, rol y políticas RLS; no use service_role en el navegador.'},

  TABLE_MISSING:{severity:'ERROR',subsystem:'DATABASE',action:'Ejecute la migración que crea la tabla requerida.'},
  VIEW_MISSING:{severity:'ERROR',subsystem:'DATABASE',action:'Ejecute la migración que crea la vista requerida.'},
  RPC_MISSING:{severity:'ERROR',subsystem:'DATABASE',action:'Ejecute la migración que crea la función RPC.'},
  COLUMN_MISSING:{severity:'ERROR',subsystem:'DATABASE',action:'Revise versión del schema y migraciones pendientes.'},
  MIGRATION_MISSING:{severity:'ERROR',subsystem:'DATABASE',action:'Ejecute las migraciones pendientes en orden.'},

  FRONTEND_FILE_MISSING:{severity:'ERROR',subsystem:'FRONTEND',action:'Suba el archivo faltante preservando su ruta.'},
  FRONTEND_IMPORT_FAILED:{severity:'ERROR',subsystem:'FRONTEND',action:'Revise ruta relativa, nombre del archivo y caché.'},
  APP_ERROR:{severity:'ERROR',subsystem:'APP',action:'Revise detalle técnico, Console y Network.'},
  UNKNOWN:{severity:'ERROR',subsystem:'UNKNOWN',action:'Revise Console/Network y registre el mensaje completo.'}
};

function catalog(code){
  return DIAGNOSTIC_CATALOG[code]||DIAGNOSTIC_CATALOG.UNKNOWN;
}

export function normalizeConfigValidation(){
  const raw=validateConfig();
  const problems=Array.isArray(raw) ? raw : (raw?.problems||[]);
  const ok=problems.length===0;
  return {ok,problems};
}

export function classifyError(error,context={}){
  const message=String(error?.message||error||'Error desconocido');
  const lower=message.toLowerCase();
  let code='UNKNOWN';

  if(lower.includes('invalid login credentials')) code='AUTH_INVALID_CREDENTIALS';
  else if(lower.includes('email not confirmed')) code='AUTH_EMAIL_NOT_CONFIRMED';
  else if(lower.includes('failed to fetch')||lower.includes('networkerror')||lower.includes('network request failed')) code='NETWORK_FAILED';
  else if(lower.includes('permission denied')||lower.includes('row-level security')||lower.includes('rls')) code='RLS_DENIED';
  else if(lower.includes('relation')&&lower.includes('does not exist')) code=context.objectType==='VIEW'?'VIEW_MISSING':'TABLE_MISSING';
  else if(lower.includes('could not find the function')||lower.includes('function')&&lower.includes('does not exist')) code='RPC_MISSING';
  else if(lower.includes('column')&&lower.includes('does not exist')) code='COLUMN_MISSING';
  else if(context.subsystem==='AUTH') code='AUTH_FAILED';
  else if(context.subsystem==='FRONTEND') code='FRONTEND_IMPORT_FAILED';
  else code='APP_ERROR';

  const c=catalog(code);
  return {
    code,
    severity:c.severity,
    subsystem:context.subsystem||c.subsystem,
    route:context.route||location.hash||location.pathname,
    message,
    technical:error?.stack||error?.details||error?.hint||null,
    action:c.action,
    metadata:context.metadata||null
  };
}

export function diagnosticFromCode(code,message,context={}){
  const c=catalog(code);
  return {
    code,
    severity:c.severity,
    subsystem:context.subsystem||c.subsystem,
    route:context.route||location.hash||location.pathname,
    message:message||code,
    technical:context.technical||null,
    action:context.action||c.action,
    metadata:context.metadata||null
  };
}

export function formatDiagnostic(d){
  return `[${d.code}] ${d.message} · Acción: ${d.action}`;
}

export function maskConfig(){
  let host='(inválido)';
  try{host=new URL(CONFIG.SUPABASE_URL).hostname}catch{}
  const key=CONFIG.SUPABASE_PUBLISHABLE_KEY||'';
  return {
    host,
    key:key?`${key.slice(0,14)}…${key.slice(-4)}`:'(vacía)',
    appBase:CONFIG.APP_BASE
  };
}
