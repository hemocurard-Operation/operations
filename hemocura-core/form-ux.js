/* HemoCura form UX utilities v0.45.9
   Cross-cutting improvements for all capture forms:
   - Toast notifications (floating success/error feedback)
   - Auto-save draft (localStorage persistence every 5s)
   - Inline validation on blur (validate fields when user leaves them)
   - Progress indicator for multi-section forms
*/

const esc=(v='')=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));

/* ── Toast notifications ── */
let toastEl=null,toastTimer=null;
function ensureToast(){
  if(toastEl)return toastEl;
  toastEl=document.createElement('div');
  toastEl.id='hc-toast';
  toastEl.setAttribute('role','status');
  toastEl.setAttribute('aria-live','polite');
  toastEl.setAttribute('aria-atomic','true');
  document.body.appendChild(toastEl);
  return toastEl;
}

export function showToast(message,type='ok',duration=3000){
  const el=ensureToast();
  el.textContent=type==='ok'?`✓ ${message}`:`✗ ${message}`;
  el.className=`hc-toast hc-toast-${type} hc-toast-show`;
  clearTimeout(toastTimer);
  toastTimer=setTimeout(()=>el.classList.remove('hc-toast-show'),duration);
}

/* ── Auto-save draft ── */
const DRAFT_PREFIX='hemocura_draft_';
const draftTimers=new Map();

export function enableDraftSave(formId,fields,intervalMs=5000){
  const key=DRAFT_PREFIX+formId;
  const save=()=>{
    try{
      const data={};
      for(const fid of fields){
        const el=document.getElementById(fid);
        if(!el)continue;
        if(el.type==='checkbox')data[fid]=el.checked;
        else data[fid]=el.value;
      }
      data._ts=Date.now();
      localStorage.setItem(key,JSON.stringify(data));
    }catch{/* storage full or unavailable */}
  };
  // Save periodically
  const timer=setInterval(save,intervalMs);
  draftTimers.set(formId,timer);
  // Show badge if draft exists
  showDraftBadge(formId);
  return {save,clear:()=>clearDraft(formId)};
}

export function restoreDraft(formId,fields){
  const key=DRAFT_PREFIX+formId;
  try{
    const raw=localStorage.getItem(key);
    if(!raw)return false;
    const data=JSON.parse(raw);
    if(!data._ts)return false;
    // Only restore if draft is less than 24h old
    if(Date.now()-data._ts>86400000){localStorage.removeItem(key);return false}
    for(const fid of fields){
      const el=document.getElementById(fid);
      if(!el||data[fid]===undefined)continue;
      if(el.type==='checkbox')el.checked=!!data[fid];
      else el.value=data[fid];
    }
    return true;
  }catch{return false}
}

export function clearDraft(formId){
  const key=DRAFT_PREFIX+formId;
  try{localStorage.removeItem(key)}catch{}
  const timer=draftTimers.get(formId);
  if(timer){clearInterval(timer);draftTimers.delete(formId)}
  hideDraftBadge(formId);
}

function showDraftBadge(formId){
  const key=DRAFT_PREFIX+formId;
  try{
    const raw=localStorage.getItem(key);
    if(!raw)return;
    const data=JSON.parse(raw);
    if(!data._ts||Date.now()-data._ts>86400000)return;
    const form=document.getElementById(formId);
    if(!form)return;
    const summary=form.closest('details')?.querySelector('summary');
    if(!summary)return;
    if(summary.querySelector('.hc-draft-badge'))return;
    const badge=document.createElement('span');
    badge.className='hc-draft-badge';
    badge.textContent='Borrador guardado';
    summary.appendChild(badge);
  }catch{}
}

function hideDraftBadge(formId){
  const form=document.getElementById(formId);
  if(!form)return;
  const badge=form.closest('details')?.querySelector('.hc-draft-badge');
  if(badge)badge.remove();
}

/* ── Inline validation on blur ── */
export function enableBlurValidation(formOrRoot){
  const container=typeof formOrRoot==='string'?document.getElementById(formOrRoot):formOrRoot;
  if(!container)return;
  container.addEventListener('blur',e=>{
    const el=e.target;
    if(!el.matches('input,select,textarea'))return;
    validateField(el);
  },true); // capture phase for blur
  // Clear error on input
  container.addEventListener('input',e=>{
    const el=e.target;
    if(el.getAttribute('aria-invalid')==='true'){
      clearFieldError(el);
    }
  });
}

function validateField(el){
  // Skip if not required and empty
  if(!el.required&&!el.getAttribute('aria-required')&&!el.value)return;
  // Required check
  if((el.required||el.getAttribute('aria-required')==='true')&&!el.value.trim()){
    setFieldError(el,'Este campo es requerido.');
    return;
  }
  // Pattern check
  if(el.pattern&&el.value){
    try{
      if(!new RegExp(el.pattern).test(el.value)){
        setFieldError(el,el.title||'Formato inválido.');
        return;
      }
    }catch{}
  }
  // Min/max for numbers
  if(el.type==='number'&&el.value){
    const v=Number(el.value);
    if(el.min!==''&&v<Number(el.min)){setFieldError(el,`Mínimo: ${el.min}`);return}
    if(el.max!==''&&v>Number(el.max)){setFieldError(el,`Máximo: ${el.max}`);return}
  }
  // Clear if valid
  clearFieldError(el);
}

function setFieldError(el,message){
  el.classList.add('qc-field-error');
  el.setAttribute('aria-invalid','true');
  // Remove existing error msg
  const existing=el.parentElement?.querySelector('.qc-field-error-msg');
  if(existing)existing.remove();
  const msg=document.createElement('span');
  msg.className='qc-field-error-msg';
  msg.id=(el.id||el.name||'field')+'-blur-error';
  msg.textContent=message;
  el.setAttribute('aria-describedby',msg.id);
  el.parentElement?.appendChild(msg);
}

function clearFieldError(el){
  el.classList.remove('qc-field-error');
  el.removeAttribute('aria-invalid');
  el.removeAttribute('aria-describedby');
  const msg=el.parentElement?.querySelector('.qc-field-error-msg');
  if(msg)msg.remove();
}

/* ── Progress indicator for multi-section forms ── */
export function mountProgressBar(containerId,sectionSelectors){
  const container=document.getElementById(containerId);
  if(!container)return null;
  const bar=document.createElement('div');
  bar.className='hc-progress-bar';
  bar.setAttribute('role','progressbar');
  bar.setAttribute('aria-valuemin','0');
  bar.setAttribute('aria-valuemax','100');
  bar.innerHTML='<div class="hc-progress-fill"></div><span class="hc-progress-label"></span>';
  container.prepend(bar);

  const update=()=>{
    let total=0,filled=0;
    for(const sel of sectionSelectors){
      const fields=container.querySelectorAll(`${sel} input[required],${sel} select[required],${sel} textarea[required],${sel} [aria-required="true"]`);
      for(const f of fields){
        total++;
        if(f.type==='checkbox'?f.checked:f.value.trim())filled++;
      }
    }
    const pct=total?Math.round((filled/total)*100):0;
    const fill=bar.querySelector('.hc-progress-fill');
    const label=bar.querySelector('.hc-progress-label');
    fill.style.width=pct+'%';
    bar.setAttribute('aria-valuenow',String(pct));
    label.textContent=`${filled}/${total} campos completados`;
  };

  container.addEventListener('input',update);
  container.addEventListener('change',update);
  update();
  return {update};
}
