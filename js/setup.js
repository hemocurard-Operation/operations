async function inspectConfig() {
  const box=document.getElementById('setup-config');
  try {
    const r=await fetch(`./js/config.js?_hc=${Date.now()}`,{cache:'no-store'});
    if(!r.ok) throw new Error(`HTTP ${r.status}`);
    const text=await r.text();

    const urlOk=/https:\/\/[a-zA-Z0-9-]+\.supabase\.co/.test(text) && !text.includes('TU-PROYECTO');
    const keyOk=/sb_publishable_[A-Za-z0-9_-]+/.test(text) && !text.includes('TU_CLAVE');

    if(urlOk && keyOk){
      box.className='status ok';
      box.textContent='SUPABASE_URL y Publishable Key parecen configuradas.';
      return true;
    }

    box.className='status bad';
    box.textContent='Configuración incompleta: revise SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY.';
    return false;
  } catch(error) {
    box.className='status bad';
    box.textContent=`No se pudo inspeccionar config.js: ${error.message}`;
    return false;
  }
}

const checks=[...document.querySelectorAll('[data-setup]')];
const saved=JSON.parse(localStorage.getItem('hemocura-supabase-setup')||'{}');

for(const c of checks){
  c.checked=!!saved[c.dataset.setup];
  c.addEventListener('change',()=>{
    saved[c.dataset.setup]=c.checked;
    localStorage.setItem('hemocura-supabase-setup',JSON.stringify(saved));
    update();
  });
}

function update(){
  const done=checks.filter(c=>c.checked).length;
  const box=document.getElementById('setup-progress');
  box.textContent=`${done}/${checks.length} pasos confirmados.`;
  box.className=`status ${done===checks.length?'ok':'info'}`;
}

const configOk=await inspectConfig();
if(configOk){
  const c=checks.find(x=>x.dataset.setup==='config');
  if(c && !c.checked){
    c.checked=true;
    saved.config=true;
    localStorage.setItem('hemocura-supabase-setup',JSON.stringify(saved));
  }
}
update();
