import { initApp } from '../hemocura-core/bootstrap.js';

window.addEventListener('DOMContentLoaded', () => {
  initApp().catch(error => {
    console.error('[HEMOCURA_BOOT_ERROR_UNHANDLED]', error);
    const app = document.getElementById('app');
    if (app) {
      app.innerHTML = '<main class="boot"><h1>Error crítico</h1><p>Abra F12 → Console.</p></main>';
    }
  });
});
