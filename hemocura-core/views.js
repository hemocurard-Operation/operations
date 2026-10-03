export function renderView(route){
  console.info('[HEMOCURA_VIEW]',route);
  if(route === 'dashboard') return `<div id="dashboard-root"></div>`;
  if(route === 'sales') return `<div id="sales-root"></div>`;
  if(route === 'dispatches') return `<div id="dispatch-root"></div>`;
  if(route === 'inventory') return `<div id="inventory-root"></div>`;
  if(route === 'costs') return `<div id="costs-root"></div>`;
  if(route === 'quality') return `<div id="quality-root"></div>`;
  if(route === 'planning') return `<div id="planning-root"></div>`;

  switch(route){
    case 'settings': return placeholder('Configuración','Parámetros del sistema.');
    default: return placeholder('Módulo','Ruta no reconocida.');
  }
}
function placeholder(title,text){
  return `<section class="card module-placeholder"><h3>${title}</h3><p>${text}</p><div class="status info">Módulo visible · lógica pendiente de conexión.</div></section>`;
}
