export async function runFrontendHealth() {
  const checks = [];

  async function check(label, fn) {
    const started = performance.now();
    try {
      const detail = await fn();
      checks.push({
        label,
        ok: true,
        ms: Math.round(performance.now() - started),
        detail
      });
    } catch (error) {
      checks.push({
        label,
        ok: false,
        ms: Math.round(performance.now() - started),
        detail: error?.message || String(error)
      });
    }
  }

  await check('VERSION.json', async () => {
    const r = await fetch('./VERSION.json', {cache:'no-store'});
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    const data = await r.json();
    return `v${data.version} · ${data.release_channel}`;
  });

  await check('index.html', async () => {
    const r = await fetch('./index.html', {cache:'no-store'});
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    return 'Accesible';
  });

  await check('login.html', async () => {
    const r = await fetch('./login.html', {cache:'no-store'});
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    return 'Accesible';
  });

  await check('css/app.css', async () => {
    const r = await fetch('./css/app.css', {cache:'no-store'});
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    return `${(await r.text()).length} bytes`;
  });

  await check('js/app.js', async () => {
    const r = await fetch('./js/app.js', {cache:'no-store'});
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    return 'Accesible';
  });

  await check('bootstrap.js', async () => {
    const r = await fetch('./hemocura-core/bootstrap.js', {cache:'no-store'});
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    return 'Accesible';
  });

  await check('layout.js', async () => {
    const r = await fetch('./hemocura-core/layout.js', {cache:'no-store'});
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    return 'Accesible';
  });

  await check('Manifest', async () => {
    const r = await fetch('./RELEASE_MANIFEST.json', {cache:'no-store'});
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    const data = await r.json();
    return `${data.files?.length || 0} archivos`;
  });

  console.info('[HEMOCURA_FRONTEND_HEALTH]', checks);
  return checks;
}

export async function getRuntimeVersion() {
  const response = await fetch('./VERSION.json', {cache:'no-store'});
  if (!response.ok) throw new Error(`VERSION.json HTTP ${response.status}`);
  return response.json();
}

export async function inspectCacheState() {
  const result = {
    serviceWorkerSupported: 'serviceWorker' in navigator,
    controller: !!navigator.serviceWorker?.controller,
    cacheNames: []
  };

  if ('caches' in window) {
    result.cacheNames = await caches.keys();
  }

  console.info('[HEMOCURA_CACHE_DIAGNOSTICS]', result);
  return result;
}

export async function clearAppCaches() {
  if ('caches' in window) {
    const keys = await caches.keys();
    await Promise.all(keys.map(k => caches.delete(k)));
  }

  if ('serviceWorker' in navigator) {
    const regs = await navigator.serviceWorker.getRegistrations();
    await Promise.all(regs.map(r => r.unregister()));
  }

  console.info('[HEMOCURA_CACHE_DIAGNOSTICS] caches cleared');
}
