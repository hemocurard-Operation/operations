export function renderView(route){
  console.info('[HEMOCURA_VIEW]',route);
  if(route === 'dashboard') return `<div id="dashboard-root"></div>`;
  if(route === 'sales') return `<div id="sales-root"></div>`;
  if(route === 'dispatches') return `<div id="dispatch-root"></div>`;
  if(route === 'inventory') return `<div id="inventory-root"></div>`;
  if(route === 'costs') return `<div id="costs-root"></div>`;
  if(route === 'quality') return `<div id="quality-root"></div>`;
  if(route === 'planning') return `<div id="planning-root"></div>`;
  if(route === 'settings') return `<div id="settings-root"></div>`;
  if(route === 'qa') return `<div id="qa-root"></div>`;
  if(route === 'release') return `<div id="release-root"></div>`;
  if(route === 'freeze') return `<div id="freeze-root"></div>`;
  if(route === 'evidence') return `<div id="evidence-root"></div>`;
  if(route === 'acceptance') return `<div id="acceptance-root"></div>`;

  return `<section class="card module-placeholder"><h3>Módulo</h3><div class="status warn">Ruta no reconocida.</div></section>`;
}
