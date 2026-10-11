const bus=new EventTarget();

export const trainingEvents={
  emit(name,detail={}){bus.dispatchEvent(new CustomEvent(name,{detail}))},
  on(name,handler){const fn=e=>handler(e.detail);bus.addEventListener(name,fn);return()=>bus.removeEventListener(name,fn)}
};

export const TRAINING_EVENT={
  CONTEXT_OPENED:'TRAINING_CONTEXT_OPENED',
  MODULE_COMPLETED:'TRAINING_MODULE_COMPLETED',
  QUIZ_SUBMITTED:'TRAINING_QUIZ_SUBMITTED',
  PRACTICE_OBSERVED:'TRAINING_PRACTICE_OBSERVED',
  COMPETENCY_CERTIFIED:'TRAINING_COMPETENCY_CERTIFIED',
  AUTHORIZATION_GRANTED:'TRAINING_AUTHORIZATION_GRANTED'
};
