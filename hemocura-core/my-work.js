import { filterRoutes } from './access-control.js';
import { routeList,navigate } from './router.js';
const PRIORITY={
  quickcapture:{label:'Capturar ahora',hint:'Registrar la operación con el mínimo de campos y completar después.',priority:1},
  predictive:{label:'Revisar prioridades predictivas',hint:'Anticipar riesgo de stock, cobranza, clientes y acciones de calidad/compliance.',priority:2},
  decisioncenter:{label:'Resolver señales prioritarias',hint:'Convertir atrasos, cobranza, merma y feedback en acciones trazables.',priority:3},
  dailyinventory:{label:'Completar reporte diario',hint:'Cerrar inventario, despachos y novedades del día.',priority:4},
  serviceperformance:{label:'Revisar SLA y demanda',hint:'Vincular demanda con despacho y detectar atención fuera de tiempo.',priority:5},
  valuechain:{label:'Revisar cadena de valor',hint:'Ver necesidades abiertas, inventario, despachos, ingreso y cuellos de botella.',priority:6},
  collections:{label:'Gestionar cobranza',hint:'Atender cuentas vencidas y registrar cobros.',priority:7},
  economics:{label:'Revisar rentabilidad y merma',hint:'Ver contribución por sucursal, pérdidas y economía de campañas.',priority:8},
  actions:{label:'Resolver acciones pendientes',hint:'Atender acciones vencidas, críticas o pendientes de eficacia.',priority:9},
  medicalnetwork:{label:'Activar red médica',hint:'Gestionar referidores, referencias y conversión a demanda.',priority:10},
  approvals:{label:'Revisar aprobaciones',hint:'Resolver decisiones pendientes sin entrar a cada módulo.',priority:11},
  donoroutreach:{label:'Gestionar captación de donantes',hint:'Activar campañas según la brecha de demanda e inventario.',priority:12},
  customers:{label:'Gestionar clientes y SLA',hint:'Revisar acuerdos, valor, cobro y retroalimentación.',priority:13},
  quality:{label:'Gestionar calidad',hint:'Incidencias, no conformidades y CAPA que requieren acción.',priority:14},
  training:{label:'Continuar capacitación',hint:'Aprendizaje y evaluación según tu puesto activo.',priority:15},
  dispatches:{label:'Procesar despachos',hint:'Preparar, registrar y conciliar salidas físicas.',priority:16},
  bloodinventory:{label:'Revisar inventario de sangre',hint:'Disponibilidad por componente, ABO y Rh.',priority:17},
  command:{label:'Ver centro de mando',hint:'Excepciones, cierre diario y señales operativas.',priority:18},
  dashboard:{label:'Ver resumen ejecutivo',hint:'Indicadores priorizados según tu acceso.',priority:19}
};
function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot',"'":'&#039;'}[c]))}
export async function mountMyWork(root){const allowed=await filterRoutes(routeList());const tasks=allowed.filter(([key])=>PRIORITY[key]).map(([key,meta])=>({key,meta,...PRIORITY[key]})).sort((a,b)=>a.priority-b.priority).slice(0,8);const primary=tasks.slice(0,4),secondary=tasks.slice(4);root.innerHTML=`<section class="card"><div class="section-head"><div><h2>Mi trabajo</h2><p class="muted">Primero anticipar, después decidir y ejecutar. Las prioridades respetan tus permisos y la autoridad clínica.</p></div></div>${primary.length?`<div class="work-grid">${primary.map((t,i)=>`<button class="work-card ${i===0?'primary-work':''}" data-work-route="${esc(t.key)}"><span class="work-kicker">${i===0?'Siguiente acción':'Tarea disponible'}</span><strong>${esc(t.label)}</strong><small>${esc(t.hint)}</small><span class="work-open">Abrir →</span></button>`).join('')}</div>`:'<div class="status warn">No hay tareas operativas disponibles para los permisos actuales.</div>'}</section>${secondary.length?`<section class="card"><h3>También puedes continuar con</h3><div class="quick-links">${secondary.map(t=>`<button class="secondary" data-work-route="${esc(t.key)}">${esc(t.label)}</button>`).join('')}</div></section>`:''}<section class="card"><div class="status ok"><strong>Diseño predictivo con control humano:</strong> detectar → proyectar → recomendar → decidir → actuar → verificar eficacia. Ninguna recomendación automatiza autoridad clínica.</div></section>`;root.querySelectorAll('[data-work-route]').forEach(btn=>btn.addEventListener('click',()=>navigate(btn.dataset.workRoute)))}
