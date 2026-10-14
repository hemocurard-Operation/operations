import { getSupabase } from '../hemocura-core/supabase.js';
const form=document.querySelector('#activation-form'),status=document.querySelector('#activation-status');
function message(text,bad=false){status.textContent=text;status.className=`status ${bad?'bad':'info'}`}
async function boot(){
 try{
  const client=getSupabase();
  const url=new URL(location.href);
  const hash=new URLSearchParams(location.hash.slice(1));
  if(url.searchParams.has('error')||hash.has('error'))throw Error('El enlace no es válido o ha vencido. Solicita una nueva invitación.');
  if(url.searchParams.has('code')){const {error}=await client.auth.exchangeCodeForSession(url.searchParams.get('code'));if(error)throw error}
  const {data,error}=await client.auth.getSession();if(error)throw error;
  // Remove tokens/codes from the visible URL after session initialization.
  history.replaceState(null,'',location.pathname);
  if(!data.session)throw Error('El enlace no está activo. Solicita una nueva invitación.');
  form.hidden=false;message('Enlace validado. Ingresa una clave de 12 a 128 caracteres.');
 }catch{history.replaceState(null,'',location.pathname);form.hidden=true;message('El enlace no es válido o ha vencido. Solicita una nueva invitación.',true)}
}
form.addEventListener('submit',async e=>{
 e.preventDefault();const key=form.elements.password.value;
 if(key!==form.elements.confirmation.value){message('Las claves no coinciden.',true);return}
 if(key.length<12||key.length>128){message('La clave debe tener entre 12 y 128 caracteres.',true);return}
 const button=form.querySelector('button');button.disabled=true;
 try{const {error}=await getSupabase().auth.updateUser({password:key});if(error)throw error;message('Clave guardada. Entrando…');location.replace('./')}
 catch{message('No se pudo guardar la clave. Comprueba que el enlace siga vigente y vuelve a intentarlo.',true)}
 finally{form.elements.password.value='';form.elements.confirmation.value='';button.disabled=false}
});
boot();
