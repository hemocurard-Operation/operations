const ROUTES = {
  dashboard: {title:'Dashboard', subtitle:'Resumen operativo del día'},
  sales: {title:'Ventas', subtitle:'Ventas diarias por sucursal'},
  dispatches: {title:'Despachos', subtitle:'Despachos y conciliación'},
  inventory: {title:'Inventario', subtitle:'Existencias y alertas'},
  costs: {title:'Costos', subtitle:'Costos, precios y rentabilidad'},
  quality: {title:'Calidad', subtitle:'Indicadores, NC y CAPA'},
  planning: {title:'Planificación', subtitle:'Plan vs Real y forecast'},
  settings: {title:'Configuración', subtitle:'Parámetros del sistema'}
};

export function getRoute(){
  const raw=(location.hash||'#dashboard').replace('#','').trim();
  return ROUTES[raw] ? raw : 'dashboard';
}
export function getRouteMeta(route){ return ROUTES[route] || ROUTES.dashboard; }
export function routeList(){ return Object.entries(ROUTES); }
export function navigate(route){ location.hash=route; }
