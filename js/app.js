import { initApp } from '../hemocura-core/bootstrap.js';
window.addEventListener('DOMContentLoaded',()=>initApp().catch(error=>{
  console.error('[HEMOCURA_BOOT_ERROR_UNHANDLED]',error);
}));
