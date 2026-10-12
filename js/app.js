function showStartupFailure(error){
  const app=document.getElementById('app');
  if(!app?.querySelector('[data-boot-status]'))return;
  const main=document.createElement('main');main.className='boot';
  const title=document.createElement('h1');title.textContent='HemoCura Operations';
  const status=document.createElement('p');status.className='status bad';status.setAttribute('role','alert');
  status.textContent='No se pudo iniciar HemoCura. Reintenta o abre el diagnóstico de carga.';
  const detail=document.createElement('p');detail.setAttribute('data-boot-error','');
  detail.textContent=error?.name==='Error'&&error.message==='BOOT_TIMEOUT'?'El inicio tardó más de 15 segundos.':'Falló la carga de un módulo: '+String(error?.message||'causa desconocida').replace(/sb_(?:publishable|secret)_[A-Za-z0-9_-]+/g,'[clave omitida]');
  const retry=document.createElement('button');retry.textContent='Reintentar';retry.onclick=()=>location.reload();
  const diagnostic=document.createElement('a');diagnostic.href='./deployment-check.html';diagnostic.textContent='Abrir diagnóstico';
  const login=document.createElement('a');login.href='./login.html';login.textContent='Ir al inicio de sesión';
  const actions=document.createElement('p');actions.append(diagnostic,document.createTextNode(' · '),login);
  main.append(title,status,detail,retry,actions);app.replaceChildren(main);
}

async function start(){
  const timeout=setTimeout(()=>showStartupFailure(new Error('BOOT_TIMEOUT')),15000);
  try{
    const {initApp}=await import('../hemocura-core/bootstrap.js');
    await initApp();
  }catch(error){
    console.error('[HEMOCURA_BOOT_ERROR_UNHANDLED]',error);
    showStartupFailure(error);
  }finally{clearTimeout(timeout)}
}

if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});
else start();
