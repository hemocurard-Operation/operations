function showStartupFailure(){
  const app=document.getElementById('app');
  if(!app?.querySelector('[data-boot-status]'))return;
  const main=document.createElement('main');main.className='boot';
  const title=document.createElement('h1');title.textContent='HemoCura Operations';
  const status=document.createElement('p');status.className='status bad';status.setAttribute('role','alert');
  status.textContent='No se pudo iniciar HemoCura. Reintenta o abre el diagnóstico de carga.';
  const retry=document.createElement('button');retry.textContent='Reintentar';retry.onclick=()=>location.reload();
  const diagnostic=document.createElement('a');diagnostic.href='./deployment-check.html';diagnostic.textContent='Abrir diagnóstico';
  const login=document.createElement('a');login.href='./login.html';login.textContent='Ir al inicio de sesión';
  const actions=document.createElement('p');actions.append(diagnostic,document.createTextNode(' · '),login);
  main.append(title,status,retry,actions);app.replaceChildren(main);
}

async function start(){
  const timeout=setTimeout(showStartupFailure,15000);
  try{
    const {initApp}=await import('../hemocura-core/bootstrap.js');
    await initApp();
  }catch(error){
    console.error('[HEMOCURA_BOOT_ERROR_UNHANDLED]',error);
    showStartupFailure();
  }finally{clearTimeout(timeout)}
}

if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});
else start();
