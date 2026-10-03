import { getSession } from './auth.js';

function renderError(error) {
  const app = document.getElementById('app');
  app.innerHTML = `
    <main class="app-shell">
      <section class="card">
        <h1>Error de inicio</h1>
        <p>La aplicación no pudo completar el arranque.</p>
        <div class="status bad">${escapeHtml(error.message || String(error))}</div>
        <p>Abra <b>F12 → Console</b> y busque <code>HEMOCURA_BOOT_ERROR</code>.</p>
        <p><a href="./login.html">Abrir diagnóstico de acceso</a></p>
      </section>
    </main>`;
}

function escapeHtml(value='') {
  return value.replace(/[&<>"']/g, c => ({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'
  }[c]));
}

export async function initApp() {
  console.info('[HEMOCURA_BOOT] iniciando v0.2.0');
  const app = document.getElementById('app');
  if (!app) throw new Error('No existe #app');

  try {
    const session = await getSession();

    if (!session) {
      console.info('[HEMOCURA_AUTH] sin sesión → login');
      location.replace('./login.html');
      return;
    }

    app.innerHTML = `
      <header class="topbar">
        <div>
          <strong>HemoCura Operations</strong><br>
          <span class="muted">v0.2.0 · Supabase + Auth</span>
        </div>
        <a href="./login.html">Cuenta</a>
      </header>
      <main class="app-shell">
        <section class="card">
          <h1>Sesión iniciada</h1>
          <p>El shell, Supabase y la autenticación están funcionando.</p>
          <p><strong>Usuario:</strong> ${escapeHtml(session.user?.email || session.user?.id || '')}</p>
          <div class="status ok">[HEMOCURA_BOOT] OK</div>
        </section>
      </main>`;

    console.info('[HEMOCURA_BOOT] OK');
  } catch (error) {
    console.error('[HEMOCURA_BOOT_ERROR]', error);
    renderError(error);
  }
}
