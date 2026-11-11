import { getSupabase } from './supabase.js';
import { loadAccess } from './access-control.js';

function esc(v=''){return String(v ?? '').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
async function safeRows(label,fn){try{const r=await fn();if(r?.error)throw r.error;return {label,ok:true,data:r?.data||[]}}catch(e){return {label,ok:false,data:[],error:e?.message||String(e)}}}
async function safeCount(label,fn){try{const r=await fn();if(r?.error)throw r.error;return {label,ok:true,count:Number(r?.count||0)}}catch(e){return {label,ok:false,count:0,error:e?.message||String(e)}}}
async function loadVersion(){try{const url=new URL('../VERSION.json',import.meta.url);const r=await fetch(url,{cache:'no-store'});if(!r.ok)throw new Error(`VERSION.json HTTP ${r.status}`);return await r.json()}catch(e){return {version:'desconocida',stage:'No disponible',clinical_core:'NO DECLARADO'}}}
function localDateISO(date=new Date()){return `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}`}
function openCount(rows=[]){const closed=new Set(['CERRADO','CERRADA','CLOSED','CANCELADO','CANCELADA','COMPLETADO','COMPLETADA']);return rows.filter(r=>!closed.has(String(r.status||'').trim().toUpperCase())).length}
function kpi(label,value,detail=''){return `<section class="card ops-kpi-card"><div class="muted">${esc(label)}</div><div class="kpi">${esc(value)}</div>${detail?`<small class="muted">${esc(detail)}</small>`:''}</section>`}
function action(route,title,detail){return `<a class="ops-action" href="#${esc(route)}"><strong>${esc(title)}</strong><span>${esc(detail)}</span></a>`}
function coreItem(label,status,tone='warn'){return `<div class="ops-core-item"><span>${esc(label)}</span><strong class="state-pill state-${tone}">${esc(status)}</strong></div>`}
function rolesOf(context={}){const raw=context.roles||[];if(Array.isArray(raw))return raw.map(x=>typeof x==='string'?x:(x?.code||x?.role_code||'')).filter(Boolean);if(typeof raw==='string'){try{const p=JSON.parse(raw);return Array.isArray(p)?p.map(x=>typeof x==='string'?x:(x?.code||'')).filter(Boolean):[raw]}catch{return raw.split(',').map(x=>x.trim()).filter(Boolean)}}return []}

function shiftLabel(){const h=new Date().getHours();return h>=6&&h<14?'Turno mañana':h>=14&&h<22?'Turno tarde':'Turno noche'}

const ROLE_KPIS={
  LABORATORIO:['Despachos de hoy','Tamizaje pendiente','NC activas','Cadena de frío'],
  ENCARGADA_LABORATORIO:['Despachos de hoy','Tamizaje pendiente','NC activas','CAPA activas'],
  ASISTENTE_OPERACIONES:['Despachos de hoy','Requisiciones abiertas','NC activas','CAPA activas'],
  LOGISTICA:['Despachos de hoy','Entregas pendientes','Cadena de frío','Viajes extra'],
  LOGISTICA_CONDUCTOR:['Despachos de hoy','Entregas pendientes','Cadena de frío','Viajes extra'],
  LOGISTICA_SUPERVISOR:['Despachos de hoy','Entregas pendientes','NC activas','Viajes extra'],
  LOGISTICA_CONSULTA:['Despachos de hoy','Entregas pendientes','Cadena de frío','Viajes extra'],
  CALIDAD:['NC activas','CAPA activas','Incidencias con seguimiento','Auditorías pendientes'],
  CAMARISTA_HIPERBARICA:['Despachos de hoy','Sesiones cámara','NC activas','CAPA activas'],
  ASISTENTE_COMERCIAL:['Despachos de hoy','Visitas programadas','NC activas','CAPA activas'],
  MEDICO_GERENTE_TECNICO:['Despachos de hoy','Tamizaje pendiente','NC activas','CAPA activas'],
  SUPER_USUARIO:['Despachos de hoy','Incidencias con seguimiento','NC activas','CAPA activas'],
  ADMIN:['Despachos de hoy','Incidencias con seguimiento','NC activas','CAPA activas'],
};
function roleKpiLabels(primary){return ROLE_KPIS[primary]||['Despachos de hoy','Incidencias con seguimiento','NC activas','CAPA activas']}
function roleKpiValues(labels,counts){return labels.map(l=>{const m={'Despachos de hoy':counts.dispatches,'Incidencias con seguimiento':counts.incidents,'NC activas':counts.ncOpen,'CAPA activas':counts.capaOpen,'Tamizaje pendiente':counts.incidents,'Cadena de frío':counts.dispatches,'Requisiciones abiertas':counts.incidents,'Entregas pendientes':counts.dispatches,'Viajes extra':counts.dispatches,'Auditorías pendientes':counts.incidents,'Sesiones cámara':counts.dispatches,'Visitas programadas':counts.incidents};return {label:l,value:m[l]??0}}).map(k=>kpi(k.label,k.value))}

const EXPERIENCES={
  SUPER_USUARIO:{title:'Panel de Super Usuario',subtitle:'Gobierno, seguridad, calidad y operación completa',actions:[['security','Seguridad y Acceso','Roles, permisos y RLS'],['audit','Auditoría del Sistema','Trazabilidad y revisión'],['diagnostics','Diagnóstico','Dependencias y salud técnica'],['releasegate','Release Gate','Preparación de liberación'],['quality','SGC','NC, CAPA e incidencias'],['command','Centro de Mando','Operación diaria']]},
  ADMIN:{title:'Panel de Administración',subtitle:'Gobierno técnico y operación',actions:[['security','Seguridad y Acceso','Roles, permisos y RLS'],['settings','Configuración','Usuarios, roles y catálogos'],['diagnostics','Diagnóstico','Salud técnica'],['audit','Auditoría del Sistema','Trazabilidad'],['releasegate','Release Gate','Liberaciones']]},
  ENCARGADA_LABORATORIO:{title:'Panel de Encargada de Laboratorio',subtitle:'Donantes, tamizaje, producción, calidad y cadena de frío',actions:[['donors','Donantes','Captura y revisión humana'],['screening','Tamizaje','Pruebas y resultados'],['production','Producción','Componentes y rendimiento'],['bloodinventory','Inventario de Sangre','Disponibilidad por componente'],['analyticalqc','Calidad Analítica','IQC y EQA/PT'],['coldchain','Cadena de Frío','Temperaturas y excursiones'],['transport','Transporte','Reporte de traslados'],['environmental','Control Ambiental','Registro diario y hoja mensual']]},
  LABORATORIO:{title:'Panel de Laboratorio',subtitle:'Trabajo técnico priorizado',actions:[['donors','Donantes','Captura y revisión humana'],['screening','Tamizaje','Pruebas y resultados'],['production','Producción','Componentes'],['bloodinventory','Inventario de Sangre','Disponibilidad'],['coldchain','Cadena de Frío','Temperaturas'],['transport','Transporte','Reporte de traslados'],['environmental','Control Ambiental','Registro diario y hoja mensual']]},
  MEDICO_GERENTE_TECNICO:{title:'Panel Médico / Gerente Técnico',subtitle:'Supervisión técnica, hemovigilancia y liberación humana',actions:[['bloodflow','Flujo Sanguíneo','Trazabilidad integral'],['analyticalqc','Calidad Analítica','Métodos e IQC'],['hemovigilance','Hemovigilancia','Eventos y retiros'],['quality','SGC','NC y CAPA'],['coldchain','Cadena de Frío','Control térmico'],['management','Revisión Dirección','Seguimiento técnico']]},
  ASISTENTE_OPERACIONES:{title:'Panel de Asistente de Operaciones',subtitle:'Captura, despacho, inventario y seguimiento diario',actions:[['dispatches','Despachos','Registro y conciliación'],['requisitions','Requisiciones','Solicitudes de insumos'],['inventory','Insumos','Existencias operativas'],['donors','Donantes','Captura asistida'],['sales','Salidas de inventario','Entregas y trazabilidad'],['supply','Abastecimiento','Cobertura y necesidades'],['transport','Transporte','Reporte de traslados']]},
  SOCIO:{title:'Panel de Socio',subtitle:'Visión ejecutiva de desempeño y riesgos',actions:[['command','Centro de Mando','Indicadores y excepciones'],['bi','Inteligencia de Negocios','Tendencias y desempeño'],['projects','Proyectos','Portafolio y avance'],['management','Revisión Dirección','Objetivos y riesgos'],['quality','SGC','Estado de calidad'],['sales','Salidas de inventario','Unidades y centros atendidos']]},
  GERENCIA_GENERAL:{title:'Panel de Gerencia General',subtitle:'Desempeño, riesgos y decisiones',actions:[['command','Centro de Mando','Indicadores y excepciones'],['bi','Inteligencia de Negocios','Análisis ejecutivo'],['management','Revisión Dirección','Objetivos y riesgos'],['projects','Proyectos','Portafolio'],['quality','SGC','Estado de calidad']]},
  GERENCIA_OPERATIVA:{title:'Panel de Gerencia Operativa',subtitle:'Operación, calidad y seguimiento',actions:[['command','Centro de Mando','Cierre diario'],['dispatches','Despachos','Flujo operativo'],['quality','SGC','Incidencias y CAPA'],['supply','Abastecimiento','Cobertura'],['commercialcalendar','Agenda Comercial','Visitas, lanzamientos y especialistas'],['bi','Inteligencia de Negocios','Indicadores']]},
  CALIDAD:{title:'Panel de Calidad',subtitle:'No conformidades, CAPA, auditorías internas y mejora continua',actions:[['quality','SGC','Incidencias, NC y CAPA'],['actions','Acciones','Cartera y eficacia'],['approvals','Aprobaciones','Decisiones pendientes'],['internalaudits','Auditorías Internas','Hallazgos y evidencia'],['bloodquality','Calidad Analítica','IQC y controles'],['coldchain','Cadena de Frío','Temperaturas']]},
  LOGISTICA:{title:'Panel de Logística',subtitle:'Entregas, rutas, cadena de frío en tránsito',actions:[['teamdeliveries','Entregas del Equipo','Asignaciones y relevos'],['extratrips','Viajes Extra','Registro e incentivos'],['transport','Transporte','Cadena de frío en ruta'],['coldchain','Cadena de Frío','Temperaturas']]},
  LOGISTICA_CONDUCTOR:{title:'Panel de Conductor',subtitle:'Entregas del día, cadena de frío y viajes extra',actions:[['teamdeliveries','Mis Entregas','Rutas y relevos del día'],['extratrips','Viajes Extra','Registro desde el celular'],['transport','Transporte','Cadena de frío en ruta'],['coldchain','Cadena de Frío','Temperaturas']]},
  LOGISTICA_SUPERVISOR:{title:'Panel de Supervisor de Logística',subtitle:'Equipo, entregas y desempeño logístico',actions:[['teamdeliveries','Entregas del Equipo','Asignaciones y relevos'],['extratrips','Viajes Extra','Revisión e incentivos'],['transport','Transporte','Cadena de frío'],['dispatches','Despachos','Flujo operativo'],['coldchain','Cadena de Frío','Temperaturas']]},
  LOGISTICA_CONSULTA:{title:'Panel de Consulta Logística',subtitle:'Consulta de entregas y rutas',actions:[['teamdeliveries','Entregas del Equipo','Estado de asignaciones'],['extratrips','Viajes Extra','Consultar viajes'],['transport','Transporte','Cadena de frío en ruta']]},
  CAMARISTA_HIPERBARICA:{title:'Panel de Cámara Hiperbárica',subtitle:'Sesiones, citas y agenda diaria',actions:[['hyperbaric','Cámara Hiperbárica','Citas y sesiones'],['areaagenda','Agenda de Área','Jornada y evidencias'],['training','Capacitación','Aprendizaje por puesto']]},
  ASISTENTE_COMERCIAL:{title:'Panel Comercial',subtitle:'Visitas, clientes y agenda comercial',actions:[['commercial','Gestión Comercial','Cartera y oportunidades'],['commercialcalendar','Agenda Comercial','Visitas y lanzamientos'],['customers','Clientes','SLA y retroalimentación'],['medicalnetwork','Red Médica','Referidores y conversión'],['areaagenda','Agenda de Área','Jornada y evidencias'],['training','Capacitación','Aprendizaje por puesto']]}
};

export async function mountOpsDashboard(root){
  if(!root) throw new Error('ops-dashboard-root no disponible');
  const sb=getSupabase();root.innerHTML='<section class="card"><div class="status info">Cargando experiencia por rol…</div></section>';
  const today=localDateISO();
  const [version,access,dispatches,incidents,nc,capa]=await Promise.all([
    loadVersion(),loadAccess(),
    safeCount('Despachos',()=>sb.from('dispatches').select('id',{count:'exact',head:true}).eq('dispatch_date',today)),
    safeCount('Incidencias',()=>sb.from('incidents').select('id',{count:'exact',head:true}).eq('requires_quality_followup',true)),
    safeRows('No conformidades',()=>sb.from('nonconformities').select('id,status').limit(200)),
    safeRows('CAPA',()=>sb.from('capa').select('id,status').limit(200))
  ]);
  const roles=rolesOf(access.context),primary=roles.find(r=>EXPERIENCES[r])||'GERENCIA_OPERATIVA',xp=EXPERIENCES[primary]||EXPERIENCES.GERENCIA_OPERATIVA;
  // Merge actions from secondary roles (hallazgo #4: multi-role support)
  const secondaryRoles=roles.filter(r=>r!==primary&&EXPERIENCES[r]);
  const primaryRoutes=new Set(xp.actions.map(([r])=>r));
  const mergedActions=[...xp.actions];
  for(const sr of secondaryRoles){const sx=EXPERIENCES[sr];if(sx)for(const a of sx.actions){if(!primaryRoutes.has(a[0])){mergedActions.push(a);primaryRoutes.add(a[0])}}}
  const permittedActions=mergedActions.filter(([route])=>{
    const need={security:'ACCESS_ADMIN',settings:'ADMIN_VIEW',audit:'AUDIT_VIEW',diagnostics:'RELEASE_GATE_VIEW',releasegate:'RELEASE_GATE_VIEW',quality:'QUALITY_VIEW',command:'COMMAND_VIEW',donors:'DONORS_VIEW',screening:'SCREENING_VIEW',production:'BLOOD_INVENTORY_WRITE',bloodinventory:'BLOOD_INVENTORY_VIEW',analyticalqc:'ANALYTICAL_QC_VIEW',coldchain:'COLD_CHAIN_VIEW',transport:'COLD_CHAIN_VIEW',environmental:'RESOURCES_VIEW',bloodflow:'BLOOD_INVENTORY_VIEW',hemovigilance:'HEMOVIGILANCE_VIEW',management:'MANAGEMENT_REVIEW_VIEW',dispatches:'DISPATCH_VIEW',requisitions:'DISPATCH_VIEW',inventory:'BLOOD_INVENTORY_VIEW',sales:'SALES_VIEW',supply:'SUPPLY_VIEW',bi:'BI_VIEW',projects:'PROJECTS_VIEW',commercialcalendar:'COMMERCIAL_VIEW'}[route];
    return !need||access.permissions.has(need);
  });
  const failures=[dispatches,incidents,nc,capa].filter(x=>!x.ok);
  const counts={dispatches:dispatches.count,incidents:incidents.count,ncOpen:openCount(nc.data),capaOpen:openCount(capa.data)};
  const kpiLabels=roleKpiLabels(primary);
  const kpiHtml=roleKpiValues(kpiLabels,counts).join('');
  const shift=shiftLabel();
  const rolesExtra=secondaryRoles.length?` + ${secondaryRoles.map(r=>{const x=EXPERIENCES[r];return x?x.title.replace('Panel de ','').replace('Panel ',''):r}).join(', ')}`:'';
  root.innerHTML=`
    <section class="ops-hero role-hero"><div><div class="eyebrow">HemoCura · experiencia por rol · ${esc(shift)}</div><h2 class="section-heading">${esc(xp.title)}${esc(rolesExtra)}</h2><div class="muted">${esc(xp.subtitle)}</div></div><div class="ops-version"><span>Versión</span><strong>${esc(version.version||'desconocida')}</strong></div></section>
    ${failures.length?`<div class="status warn"><strong>Carga parcial.</strong> ${esc(failures.map(x=>`${x.label}: ${x.error}`).join(' · '))}</div>`:''}
    <section class="ops-section"><div class="ops-section-head"><div><div class="eyebrow">Hoy · ${esc(today)}</div><h3>Indicadores de ${esc(xp.title.replace('Panel de ','').replace('Panel ',''))}</h3></div></div><div class="ops-kpi-grid">${kpiHtml}</div></section>
    <section class="ops-section"><div class="ops-section-head"><div><div class="eyebrow">Trabajo priorizado</div><h3>Accesos rápidos para tu rol</h3></div></div><div class="ops-actions">${permittedActions.map(x=>action(...x)).join('')||'<div class="status info">No hay acciones rápidas adicionales para este rol.</div>'}</div></section>
    <section class="card ops-core"><div class="ops-section-head"><div><div class="eyebrow">Guardrail clínico</div><h3>Clinical Core</h3></div><strong class="state-pill state-info">${esc(version.clinical_core||'NO DECLARADO')}</strong></div><div class="ops-core-grid">${coreItem('FEFO por unidad','SHADOW / BLOCKED')}${coreItem('Bloqueo térmico','SHADOW / BLOCKED')}${coreItem('Trazabilidad donante → receptor','SHADOW / BLOCKED')}${coreItem('Decisión clínica automática','NO PERMITIDA','ok')}</div><p class="muted ops-note">Las recomendaciones del sistema no sustituyen revisión clínica, autorización humana, UAT ni controles de calidad.</p></section>`;
}
