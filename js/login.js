import { validateConfig } from './config.js';
import { getSession, signIn, signOut, onAuthChange } from '../hemocura-core/auth.js';
import { normalizeConfigValidation, classifyError } from '../hemocura-core/diagnostic-engine.js';

const form=document.getElementById('login-form');
const email=document.getElementById('email');
const password=document.getElementById('password');
const loginButton=document.getElementById('login-button');
const logoutButton=document.getElementById('logout-button');
const statusBox=document.getElementById('login-status');
const debug=document.getElementById('debug-output');

function setStatus(text,type='info'){statusBox.className=`status ${type}`;statusBox.textContent=text}
function log(msg,data=''){debug.textContent=`[${new Date().toLocaleTimeString()}] ${msg}${data?' '+JSON.stringify(data):''}\n`+debug.textContent}
function setSignedIn(session){
  const signed=!!session;
  form.classList.toggle('hidden',signed);
  logoutButton.classList.toggle('hidden',!signed);
  if(signed)setStatus(`Sesión activa: ${session.user?.email || session.user?.id}`,'ok');
}

async function boot(){
  console.info('[HEMOCURA_LOGIN] iniciando diagnóstico v0.30.0');
  const v=normalizeConfigValidation();
  if(!v.ok){
    setStatus(`[CONFIG_ERROR] ${v.problems.join(' · ')} · Revise js/config.js.`,'warn');
    loginButton.disabled=true;
    log('[HEMOCURA_CONFIG]',v);
    return;
  }
  try{
    const session=await getSession();
    setSignedIn(session);
    if(!session)setStatus('[CONFIG_OK] Supabase configurado. Ingrese sus credenciales.','info');
    onAuthChange((event,s)=>{log('[HEMOCURA_AUTH] '+event);setSignedIn(s)});
  }catch(e){
    const d=e.diagnostic||classifyError(e,{subsystem:'AUTH'});
    setStatus(`[${d.code}] ${d.message} · ${d.action}`,'bad');
    log('[HEMOCURA_AUTH_ERROR]',d);
  }
}

form.addEventListener('submit',async e=>{
  e.preventDefault();
  loginButton.disabled=true;
  setStatus('Validando credenciales…','info');
  try{
    await signIn(email.value.trim(),password.value);
    setStatus('[AUTH_OK] Acceso correcto. Entrando…','ok');
    setTimeout(()=>location.replace('./'),250);
  }catch(err){
    const d=err.diagnostic||classifyError(err,{subsystem:'AUTH'});
    setStatus(`[${d.code}] ${d.message} · ${d.action}`,'bad');
    log('[HEMOCURA_AUTH_ERROR]',d);
  }finally{
    loginButton.disabled=false;
  }
});

logoutButton.addEventListener('click',async()=>{
  try{
    await signOut();
    setSignedIn(null);
    setStatus('Sesión cerrada.','info');
  }catch(err){
    const d=err.diagnostic||classifyError(err,{subsystem:'AUTH'});
    setStatus(`[${d.code}] ${d.message} · ${d.action}`,'bad');
  }
});

boot();
