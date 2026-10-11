import {navigate} from './router.js';
import {trainingEvents,TRAINING_EVENT} from './training-events.js';

const CONTEXT_ROUTES=new Set(['dailyinventory','quickcapture','donors','screening','bloodflow','coldchain','quality','internalaudits','competencies','security','diagnostics','releasegate','hemovigilance']);

export function attachTrainingContext(root,route){
  if(!root||!CONTEXT_ROUTES.has(route)||root.querySelector('[data-training-context]'))return;
  const wrap=document.createElement('div');wrap.className='dialog-actions';wrap.dataset.trainingContext='1';
  const btn=document.createElement('button');btn.className='secondary';btn.type='button';btn.textContent='🎓 Aprender este proceso';
  btn.onclick=()=>{localStorage.setItem('hc_training_context_route',route);trainingEvents.emit(TRAINING_EVENT.CONTEXT_OPENED,{route});navigate('training')};
  wrap.appendChild(btn);root.prepend(wrap);
}

export function consumeTrainingContext(){const route=localStorage.getItem('hc_training_context_route')||'';localStorage.removeItem('hc_training_context_route');return route}
