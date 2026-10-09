import { getSupabase } from './supabase.js';
import { loadAccess } from './access-control.js';

function esc(v=''){return String(v ?? '').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot',"'":'&#039;'}[c]))}
async function safeRows(label,fn){try{const r=await fn();if(r?.error)throw r.error;return {label,ok:true,data:r?.data||[]}}catch(e){return {label,ok:false,data:[],error:e?.message||String(e)}}}
async function safeCount(label,fn){try{const r=await fn();if(r?.error)throw r.error;return {label,ok:true,count:Number(r?.count||0)}}catch(e){return {label,ok:false,count:0,error:e?.message||String(e)}}}
async function loadVersion(){try{const url=new URL('../VERSION.json',import.meta.url);const r=await fetch(url,{cache:'no-store'});if(!r.ok)throw new Error(`VERSION.json HTTP ${r.status}`);return await r.json()}catch(e){console.warn('[HEMOCURA_VERSION]',e);return {version:'desconocida',stage:'No disponible',clinical_core:'NO DECLARADO'}}}
function localDateISO(date=new Date()){const y=date.getFullYear(),m=String(date.getMonth()+1).padStart(2,'0'),d=String(date.getDate()).padStart(2,'0');return `${y}-${m}-${d}`}
function openCount(rows=[]){const closed=new Set(['CERRADO','CERRADA','CLOSED','CANCELADO','CANCELADA','COMPLETADO','COMPLETADA']);return rows.filter(r=>!closed.has(String(r.status||'').trim().toUpperCase())).length}
function kpi(label,value,detail=''){return `<section class="card ops-kpi-card"><div class="muted">${esc(label)}</div><div class="kpi">${esc(value)}</div>${detail?`<small class="muted">${esc(detail)}</small>`:''}</section>`}
function task(route,title,detail,tag='Abrir',count=null){return `<a class="ops-action ops-task" href="#${esc(route)}"><div class="ops-task-top"><strong>${esc(title)}</strong><span class="state-pill ${count>0?'state-warn':'state-info'}">${count!=null?esc(count):esc(tag)}</span></div><span>${esc(detail)}</span></a>`}
function action(route,title,detail){return `<a class="ops-action" href="#${esc(route)}"><strong>${esc(title)}</strong><span>${esc(detail)}</span></a>`}
function coreItem(label,status,tone='warn'){return `<div class="ops-core-item"><span>${esc(label)}</span><strong class="state-pill state-${tone}">${esc(status)}</strong></div>`}

export async function mountOpsDashboard(root){
  if(!root) throw new Error('ops-dashboard-root no disponible');
  const sb=getSupabase();root.innerHTML='<section class="card"><div class="status info">Cargando tu trabajo…</div></section>';
  const today=localDateISO();
  const [version,access,dispatches,incidents,nc,capa,requisitions,coldExc,equipmentAlerts]=await Promise.all([
    loadVersion(),loadAccess(),
    safeCount('Despachos',()=>sb.from('dispatches').select('id',{count:'exact',head:true}).eq('dispatch_date',today)),
    safeCount('Incidencias',()=>sb.from('incidents').select('id',{count:'exact',head:true}).eq('requires_quality_followup',true)),
    safeRows('No conformidades',()=>sb.from('nonconformities').select('id,status').limit(200)),
    safeRows('CAPA',()=>sb.from('capa').select('id,status').limit(200)),
    safeCount('Requisiciones',()=>sb.from('requisitions').select('id',{count:'exact',head:true}).in('status',['PENDIENTE','APROBADA','PARCIAL'])),
    safeCount('Excursiones',()=>sb.from('vw_cold_chain_excursions').select('reading_id',{count:'exact',head:true})),
    safeCount('Alertas equipos',()=>sb.from('vw_equipment_alerts').select('equipment_id',{count:'exact',head:true}).in('severity',['ALTA','CRITICA']))
  ]);
  const failures=[dispatches,incidents,nc,capa,requisitions,coldExc,equipmentAlerts].filter(x=>!x.ok),p=access?.permissions||new Set(),show=(perm,html)=>p.has(perm)?html:'',displayName=access?.context?.full_name||access?.context?.email||'Usuario';
  root.innerHTML=`
    <section class="ops-hero"><div><div class="eyebrow">HemoCura</div><h2 class="section-heading">Mi trabajo</h2><div class="muted">${esc(displayName)}, aquí aparecen primero las tareas permitidas por tu perfil y los pendientes que requieren atención.</div></div><div class="ops-version"><span>Versión</span><strong>${esc(version.version||'desconocida')}</strong></div></section>
    ${failures.length?`<div class="status warn"><strong>Carga parcial.</strong> ${esc(failures.map(x=>`${x.label}: ${x.error}`).join(' · '))}</div>`:''}
    <section class="ops-section ops-priority-section"><div class="ops-section-head"><div><div class="eyebrow">Acciones rápidas</div><h3>¿Qué necesitas hacer?</h3></div></div><div class="ops-actions ops-task-grid">
      ${show('DONORS_VIEW',task('donors','Buscar o registrar donante','Encuentra un donante existente antes de crear uno nuevo','Frecuente'))}
      ${show('BLOOD_INVENTORY_VIEW',task('bloodflow','Registrar donación','Continúa el flujo sin repetir datos ya capturados','Frecuente'))}
      ${show('SCREENING_VIEW',task('screening','Registrar tamizaje','Unidad, prueba y resultado; detalles técnicos bajo demanda','Frecuente'))}
      ${show('BLOOD_INVENTORY_VIEW',task('bloodinventory','Consultar inventario de sangre','Busca por componente y grupo antes de registrar movimientos','Consulta'))}
      ${show('BLOOD_INVENTORY_WRITE',task('dailyinventory','Captura diaria de inventario','Registra en una sola pantalla donantes, movimiento, disponibilidad y equipos','Diario'))}
      ${show('DISPATCH_VIEW',task('dispatches','Revisar despachos','Consulta diferencias antes que el listado completo','Consulta',dispatches.ok?dispatches.count:null))}
      ${show('QUALITY_VIEW',task('incidents','Reportar incidencia','Describe qué ocurrió; Calidad clasifica y da seguimiento','Rápido',incidents.ok?incidents.count:null))}
      ${show('DISPATCH_VIEW',task('requisitions','Solicitar insumos','Crea una requisición con cuatro datos esenciales','Rápido',requisitions.ok?requisitions.count:null))}
      ${show('COLD_CHAIN_VIEW',task('coldchain','Registrar temperatura','Dos datos: dispositivo y temperatura','Control',coldExc.ok?coldExc.count:null))}
      ${show('RESOURCES_VIEW',task('resources','Equipos y ambiente','Busca equipo, registra intervención o lectura ambiental','Control',equipmentAlerts.ok?equipmentAlerts.count:null))}
    </div></section>
    <div class="sales-toolbar"><span class="muted">Actualizado: ${esc(new Date().toLocaleString('es-DO',{timeZone:'America/Santo_Domingo'}))} · Vista ajustada a permisos</span><button id="ops-retry" class="secondary">Actualizar</button></div>
    <section class="ops-section"><div class="ops-section-head"><div><div class="eyebrow">Pendientes</div><h3>Lo que requiere atención</h3></div></div><div class="ops-kpi-grid">
      ${kpi('Despachos de hoy',dispatches.ok?dispatches.count:'No disponible',today)}${kpi('Incidencias con seguimiento',incidents.ok?incidents.count:'No disponible','Revisión de Calidad')}${kpi('Requisiciones activas',requisitions.ok?requisitions.count:'No disponible','Pendiente / aprobada / parcial')}${kpi('Alertas críticas de equipos',equipmentAlerts.ok?equipmentAlerts.count:'No disponible','Alta o crítica')}${kpi('Excursiones térmicas',coldExc.ok?coldExc.count:'No disponible','Registros fuera de rango visibles')}${kpi('NC activas',nc.ok?openCount(nc.data):'No disponible',nc.ok?'Hasta 200 registros visibles':'Consulta fallida')}${kpi('CAPA activas',capa.ok?openCount(capa.data):'No disponible',capa.ok?'Hasta 200 registros visibles':'Consulta fallida')}
    </div></section>
    <details class="card ops-more"><summary><strong>Herramientas de supervisión y administración</strong><span class="muted"> Abrir solo cuando sean necesarias</span></summary><div class="ops-actions ops-secondary-actions">
      ${show('QUALITY_VIEW',action('quality','SGC completo','Indicadores, incidencias, NC, CAPA y alertas'))}${show('COMMAND_VIEW',action('command','Centro de Mando','Cierre diario y gestión por excepciones'))}${show('BI_VIEW',action('bi','Inteligencia de Negocios','Indicadores y análisis operativo'))}${show('RELEASE_GATE_VIEW',action('diagnostics','Diagnóstico','Configuración, Auth, RLS y dependencias'))}${show('RELEASE_GATE_VIEW',action('releasegate','Release Gate','Validación antes de promover'))}
    </div></details>
    <section class="card ops-core"><div class="ops-section-head"><div><div class="eyebrow">Guardrail clínico</div><h3>Clinical Core</h3></div><strong class="state-pill state-info">${esc(version.clinical_core||'NO DECLARADO')}</strong></div><div class="ops-core-grid">${coreItem('FEFO por unidad','SHADOW / BLOCKED')}${coreItem('Bloqueo térmico','SHADOW / BLOCKED')}${coreItem('Trazabilidad donante → receptor','SHADOW / BLOCKED')}${coreItem('Decisión clínica automática','NO PERMITIDA','ok')}</div><p class="muted ops-note">La interfaz reduce captura, pero no sustituye verificación clínica, UAT, RLS ni liberación humana autorizada.</p></section>`;
  root.querySelector('#ops-retry').onclick=()=>mountOpsDashboard(root);
}
