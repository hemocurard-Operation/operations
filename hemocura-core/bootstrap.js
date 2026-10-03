import { getSession } from './auth.js';
import { mountLayout } from './layout.js';

export async function initApp(){
  console.info('[HEMOCURA_BOOT] iniciando v0.3.0');
  const app=document.getElementById('app');
  if(!app) throw new Error('No existe #app');
  try{
    const session=await getSession();
    if(!session){
      console.info('[HEMOCURA_AUTH] sin sesión → login');
      location.replace('./login.html'); return;
    }
    mountLayout(session);
    console.info('[HEMOCURA_BOOT] OK');
  }catch(error){
    console.error('[HEMOCURA_BOOT_ERROR]',error);
    app.innerHTML=`<main class="boot"><h1>Error de inicio</h1><div class="status bad">${error.message}</div><p>Abra F12 → Console.</p></main>`;
  }
}
