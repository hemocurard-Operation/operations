export function renderView(route){
  console.info('[HEMOCURA_VIEW]',route);
  if(route === 'dashboard') return `<div id="dashboard-root"></div>`;
  if(route === 'sales') return `<div id="sales-root"></div>`;
  if(route === 'dispatches') return `<div id="dispatch-root"></div>`;

  switch(route){
    case 'inventory': return placeholder('Inventario','Existencias, stock mínimo y alertas.');
    case 'costs': return placeholder('Costos','Costeo mensual, precios y margen.');
    case 'quality': return placeholder('Calidad','Indicadores, no conformidades y CAPA.');
    case 'planning': return placeholder('Planificación','Plan vs Real y forecast.');
    case 'settings': return placeholder('Configuración','Parámetros del sistema.');
    default: return placeholder('Módulo','Ruta no reconocida.');
  }
}
function placeholder(title,text){
  return `<section class="card module-placeholder"><h3>${title}</h3><p>${text}</p><div class="status info">Módulo visible · lógica pendiente de conexión.</div></section>`;
}
