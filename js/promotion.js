function placeholderDetected(text) {
  return text.includes('TU-PROYECTO') || text.includes('TU_CLAVE_PUBLICABLE');
}

async function inspectConfig() {
  const box = document.getElementById('promotion-config');
  try {
    const response = await fetch(`./js/config.js?_hc=${Date.now()}`, {cache:'no-store'});
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const text = await response.text();

    if (placeholderDetected(text)) {
      box.className = 'status bad';
      box.textContent = 'CONFIG PLACEHOLDER DETECTADO · NO PROMOVER';
      return false;
    }

    box.className = 'status ok';
    box.textContent = 'Configuración personalizada detectada.';
    return true;
  } catch(error) {
    box.className = 'status bad';
    box.textContent = `No se pudo validar config.js: ${error.message}`;
    return false;
  }
}

const checks = [...document.querySelectorAll('[data-promotion]')];
const saved = JSON.parse(localStorage.getItem('hemocura-promotion-gate') || '{}');

for (const c of checks) {
  c.checked = !!saved[c.dataset.promotion];
  c.addEventListener('change', () => {
    saved[c.dataset.promotion] = c.checked;
    localStorage.setItem('hemocura-promotion-gate', JSON.stringify(saved));
    update();
  });
}

function update() {
  const complete = checks.every(c => c.checked);
  const box = document.getElementById('promotion-result');

  if (complete) {
    box.className = 'status ok';
    box.textContent = 'CONTROLES COMPLETOS · candidata a promoción v1.0.0. La aprobación final sigue siendo operativa.';
  } else {
    const done = checks.filter(c=>c.checked).length;
    box.className = 'status warn';
    box.textContent = `${done}/${checks.length} controles completados · promoción bloqueada.`;
  }
}

const configOk = await inspectConfig();
if (configOk) {
  const c = checks.find(x => x.dataset.promotion === 'config');
  if (c && !c.checked) {
    c.checked = true;
    saved.config = true;
    localStorage.setItem('hemocura-promotion-gate', JSON.stringify(saved));
  }
}
update();
