import { validateConfig } from './config.js';
import { getSession, signIn, signOut, onAuthChange } from '../hemocura-core/auth.js';

const form = document.getElementById('login-form');
const email = document.getElementById('email');
const password = document.getElementById('password');
const loginButton = document.getElementById('login-button');
const logoutButton = document.getElementById('logout-button');
const statusBox = document.getElementById('login-status');
const debug = document.getElementById('debug-output');

function log(message, data='') {
  const line = `[${new Date().toLocaleTimeString()}] ${message}${data ? ' ' + JSON.stringify(data, null, 2) : ''}`;
  console.info(message, data);
  debug.textContent = line + '\n' + debug.textContent;
}

function setStatus(text, type='info') {
  statusBox.className = `status ${type}`;
  statusBox.textContent = text;
}

function setSignedIn(session) {
  const signed = !!session;
  form.classList.toggle('hidden', signed);
  logoutButton.classList.toggle('hidden', !signed);
  if (signed) {
    setStatus(`Sesión activa: ${session.user?.email || session.user?.id}`, 'ok');
  }
}

async function bootLogin() {
  console.info('[HEMOCURA_LOGIN] iniciando');

  const problems = validateConfig();
  if (problems.length) {
    setStatus('Configuración pendiente: ' + problems.join(' · '), 'warn');
    log('[HEMOCURA_CONFIG]', problems);
    loginButton.disabled = true;
    return;
  }

  try {
    const session = await getSession();
    setSignedIn(session);
    if (!session) setStatus('Supabase conectado. Ingrese sus credenciales.', 'info');
    log('[HEMOCURA_LOGIN] módulo OK');

    onAuthChange((event, newSession) => {
      log('[HEMOCURA_AUTH] ' + event);
      setSignedIn(newSession);
    });
  } catch (error) {
    console.error('[HEMOCURA_AUTH_ERROR]', error);
    setStatus('Error conectando con Supabase: ' + error.message, 'bad');
    log('[HEMOCURA_AUTH_ERROR]', {message:error.message});
  }
}

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  loginButton.disabled = true;
  setStatus('Validando credenciales…', 'info');

  try {
    const result = await signIn(email.value.trim(), password.value);
    setStatus('Acceso correcto. Entrando…', 'ok');
    log('[HEMOCURA_AUTH] login OK', {user: result.user?.email});
    setTimeout(() => location.replace('./'), 350);
  } catch (error) {
    setStatus('No fue posible iniciar sesión: ' + error.message, 'bad');
    log('[HEMOCURA_AUTH_ERROR]', {message:error.message});
  } finally {
    loginButton.disabled = false;
  }
});

logoutButton.addEventListener('click', async () => {
  try {
    await signOut();
    setSignedIn(null);
    setStatus('Sesión cerrada.', 'info');
  } catch (error) {
    setStatus('Error al cerrar sesión: ' + error.message, 'bad');
  }
});

bootLogin();
