import { initApp } from '../hemocura-core/bootstrap.js';
window.addEventListener('DOMContentLoaded', async () => {
  try { await initApp(); }
  catch (error) {
    console.error('[HEMOCURA_BOOT_ERROR]', error);
    document.getElementById('app').innerHTML =
      '<main style="padding:24px"><h1>Error de inicio</h1><p>Abra F12 → Console y reporte HEMOCURA_BOOT_ERROR.</p></main>';
  }
});
