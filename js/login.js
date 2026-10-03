import { validateConfig } from './config.js';
import { getSession, signIn, signOut, onAuthChange } from '../hemocura-core/auth.js';

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
  const signed=!!session;form.classList.toggle('hidden',signed);logoutButton.classList.toggle('hidden',!signed);
  if(signed)setStatus(`Sesión activa: ${session.user?.email || session.user?.id}`,'ok');
}
async function boot(){
  console.info('[HEMOCURA_LOGIN] iniciando v0.3.0');
  const p=validateConfig();
  if(p.length){setStatus('Configuración pendiente: '+p.join(' · '),'warn');loginButton.disabled=true;log('[HEMOCURA_CONFIG]',p);return}
  try{
    const session=await getSession();setSignedIn(session);
    if(!session)setStatus('Supabase conectado. Ingrese sus credenciales.','info');
    onAuthChange((event,s)=>{log('[HEMOCURA_AUTH] '+event);setSignedIn(s)});
  }catch(e){setStatus('Error conectando con Supabase: '+e.message,'bad');log('[HEMOCURA_AUTH_ERROR]',{message:e.message})}
}
form.addEventListener('submit',async e=>{
  e.preventDefault();loginButton.disabled=true;setStatus('Validando…','info');
  try{await signIn(email.value.trim(),password.value);setStatus('Acceso correcto. Entrando…','ok');setTimeout(()=>location.replace('./'),250)}
  catch(err){setStatus('No fue posible iniciar sesión: '+err.message,'bad')}
  finally{loginButton.disabled=false}
});
logoutButton.addEventListener('click',async()=>{await signOut();setSignedIn(null);setStatus('Sesión cerrada.','info')});
boot();
