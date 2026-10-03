function card(label,value,note=''){
  return `<section class="card"><div class="muted">${label}</div><div class="kpi">${value}</div><small>${note}</small></section>`;
}

export function renderView(route){
  console.info('[HEMOCURA_VIEW]',route);
  switch(route){
    case 'dashboard':
      return `
        <div class="grid">
          ${card('Ventas hoy','—','Se conecta en v0.4+')}
          ${card('Despachos','—','Pendiente datos reales')}
          ${card('Inventario crítico','—','Pendiente datos reales')}
          ${card('Alertas','—','Pendiente datos reales')}
        </div>
        <section class="card module-placeholder">
          <h3>Command Center</h3>
          <p>El layout y la navegación están activos. Los KPI reales se conectarán en la siguiente iteración.</p>
        </section>`;
    case 'sales': return placeholder('Ventas','Registro y consulta de ventas diarias.');
    case 'dispatches': return placeholder('Despachos','Gestión y conciliación de despachos.');
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
