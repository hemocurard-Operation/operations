import { filterRoutes,loadAccess } from './access-control.js';
import { routeList,navigate } from './router.js';
const AREA_TASKS={ASISTENTE_OPERACIONES:['donors','suppliers','commercial','dailyinventory','requisitions','customers'],LABORATORIO:['laboratory','dailyinventory','donors','screening','bloodinventory','bloodquality'],ENCARGADA_LABORATORIO:['laboratory','dailyinventory','donors','screening','bloodinventory','bloodquality','suppliers'],INVENTARIO:['inventory','supplycatalog','suppliers','requisitions','bloodinventory'],FINANZAS:['collections','sales','economics','suppliers','customers'],CALIDAD:['bloodquality','quality','actions','approvals','internalaudits'],TI:['releasegate','training']};
const PRIORITY={
  laboratory:{label:'Gestionar el turno del laboratorio',hint:'Unidades, controles, equipos, lotes y tareas pendientes.',priority:-2},
  areaagenda:{label:'Abrir mi jornada y agenda por área',hint:'Responsables, vencimientos, bloqueos y revisión de evidencias.',priority:-1},
  donors:{label:'Gestionar donantes y citas',hint:'Buscar fichas, contactar y coordinar próximas visitas.',priority:1.1},
  screening:{label:'Registrar tamizaje',hint:'Pruebas y resultados del laboratorio.',priority:1.2},
  inventory:{label:'Revisar insumos',hint:'Disponibilidad de reactivos y materiales.',priority:1.3},
  supplycatalog:{label:'Gestionar suministros',hint:'Catálogo aprobado, unidades y mínimos.',priority:1.4},
  suppliers:{label:'Gestionar pedidos y recepciones',hint:'Órdenes de compra, entregas y lotes recibidos.',priority:1.5},
  requisitions:{label:'Preparar requisición',hint:'Solicitar insumos aprobados del catálogo.',priority:1.6},
  releasegate:{label:'Revisar diagnóstico técnico',hint:'Controles y estado de despliegue autorizados.',priority:30},
  workflow:{label:'Seguir ruta operativa',hint:'Abrir las ocho etapas por sucursal y sus registros.',priority:0},
  commercial:{label:'Gestionar visitas y compromisos',hint:'Cartera, agenda, oportunidades y ciclo de 12 semanas.',priority:3.1},
  hyperbaric:{label:'Gestionar cámara hiperbárica',hint:'Asignar citas y seguir sesiones, facturas y cobros.',priority:3.2},
  bloodquality:{label:'Completar calidad diaria',hint:'Tareas del turno con evidencia y revisión independiente.',priority:3.3},
  quickcapture:{label:'Capturar ahora',hint:'Registrar la operación con el mínimo de campos y completar después.',priority:1},
  orchestration:{label:'Orquestar prioridades y escenarios',hint:'Comparar resiliencia, calidad de datos y escenarios antes de decidir.',priority:2},
  predictive:{label:'Revisar prioridades predictivas',hint:'Anticipar riesgo de stock, cobranza, clientes y acciones de calidad/compliance.',priority:3},
  decisioncenter:{label:'Resolver señales prioritarias',hint:'Convertir atrasos, cobranza, merma y feedback en acciones trazables.',priority:4},
  dailyinventory:{label:'Completar reporte diario',hint:'Cerrar inventario, despachos y novedades del día.',priority:5},
  serviceperformance:{label:'Revisar SLA y demanda',hint:'Vincular demanda con despacho y detectar atención fuera de tiempo.',priority:6},
  valuechain:{label:'Revisar cadena de valor',hint:'Ver necesidades abiertas, inventario, despachos, ingreso y cuellos de botella.',priority:7},
  collections:{label:'Gestionar cobranza',hint:'Atender cuentas vencidas y registrar cobros.',priority:8},
  economics:{label:'Revisar rentabilidad y merma',hint:'Ver contribución por sucursal, pérdidas y economía de campañas.',priority:9},
  actions:{label:'Resolver acciones pendientes',hint:'Atender acciones vencidas, críticas o pendientes de eficacia.',priority:10},
  medicalnetwork:{label:'Activar red médica',hint:'Gestionar referidores, referencias y conversión a demanda.',priority:11},
  approvals:{label:'Revisar aprobaciones',hint:'Resolver decisiones pendientes sin entrar a cada módulo.',priority:12},
  donoroutreach:{label:'Gestionar captación de donantes',hint:'Activar campañas según la brecha de demanda e inventario.',priority:13},
  customers:{label:'Gestionar clientes y SLA',hint:'Revisar acuerdos, valor, cobro y retroalimentación.',priority:14},
  quality:{label:'Gestionar calidad',hint:'Incidencias, no conformidades y CAPA que requieren acción.',priority:15},
  training:{label:'Continuar capacitación',hint:'Aprendizaje y evaluación según tu puesto activo.',priority:16},
  dispatches:{label:'Procesar despachos',hint:'Preparar, registrar y conciliar salidas físicas.',priority:17},
  bloodinventory:{label:'Revisar inventario de sangre',hint:'Disponibilidad por componente, ABO y Rh.',priority:18},
  command:{label:'Ver centro de mando',hint:'Excepciones, cierre diario y señales operativas.',priority:19},
  dashboard:{label:'Ver resumen ejecutivo',hint:'Indicadores priorizados según tu acceso.',priority:20}
};
function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot',"'":'&#039;'}[c]))}
export async function mountMyWork(root){const allowed=await filterRoutes(routeList()),a=await loadAccess(),rawRoles=a.context?.roles||[],roleCodes=Array.isArray(rawRoles)?rawRoles.map(r=>typeof r==='string'?r:r.code||r.role_code):[],preferred=roleCodes.includes('SUPER_USUARIO')?[]:[...new Set(roleCodes.flatMap(r=>AREA_TASKS[r]||[]))];const tasks=allowed.filter(([key])=>PRIORITY[key]).map(([key,meta])=>({key,meta,...PRIORITY[key]})).sort((a,b)=>{const ai=preferred.indexOf(a.key),bi=preferred.indexOf(b.key);return (ai<0?100+a.priority:ai)-(bi<0?100+b.priority:bi)}).slice(0,8);const primary=tasks.slice(0,4),secondary=tasks.slice(4);root.innerHTML=`<div data-daily-workspace></div><section class="card"><div class="section-head"><div><h2>Mi trabajo</h2><p class="muted">Accesos y tareas disponibles según tu área, tus roles y los módulos habilitados.</p></div></div>${primary.length?`<div class="work-grid">${primary.map((t,i)=>`<button class="work-card ${i===0?'primary-work':''}" data-work-route="${esc(t.key)}"><span class="work-kicker">${i===0?'Siguiente acción':'Tarea disponible'}</span><strong>${esc(t.label)}</strong><small>${esc(t.hint)}</small><span class="work-open">Abrir →</span></button>`).join('')}</div>`:'<div class="status warn">No hay tareas operativas disponibles para los permisos actuales.</div>'}</section>${secondary.length?`<section class="card"><h3>También puedes continuar con</h3><div class="quick-links">${secondary.map(t=>`<button class="secondary" data-work-route="${esc(t.key)}">${esc(t.label)}</button>`).join('')}</div></section>`:''}<section class="card"><div class="status ok"><strong>Gobierno human-in-the-loop:</strong> dato → señal → escenario → decisión humana → acción → evidencia → eficacia. Ningún score autoriza decisiones clínicas.</div></section>`;if(allowed.some(([k])=>k==='areaagenda'))await (await import('./area-agenda.js')).mountDailyWorkspace(root.querySelector('[data-daily-workspace]'));root.querySelectorAll('[data-work-route]').forEach(btn=>btn.addEventListener('click',()=>navigate(btn.dataset.workRoute)))}
