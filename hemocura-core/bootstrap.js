export async function initApp(){
  console.info('[HEMOCURA_BOOT] iniciando');
  const app=document.getElementById('app');
  if(!app) throw new Error('No existe #app');
  app.innerHTML='<main style="padding:24px"><h1>HemoCura Operations</h1><p>Shell cargado correctamente.</p></main>';
  console.info('[HEMOCURA_BOOT] OK');
}
