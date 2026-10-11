import { filterRoutes } from './access-control.js';
import { routeList, navigate } from './router.js';

const PRIORITY={
  quickcapture:{label:'Capturar ahora',hint:'Registrar la operación con el mínimo de campos y completar después.',priority:1},
  dailyinventory:{label:'Completar reporte diario',hint:'Cerrar inventario, despachos y novedades del día.',priority:2},
  approvals:{label:'Revisar aprobaciones',hint:'Resolver decisiones pendientes sin entrar a cada módulo.',priority:3},
  quality:{label:'Gestionar calidad',hint:'Incidencias, no conformidades y CAPA que requieren acción.',priority:4},
  training:{label:'Continuar capacitación',hint:'Aprendizaje y evaluación según tu puesto activo.',priority:5},
  requisitions:{label:'Gestionar requisiciones',hint:'Solicitudes de insumos pendientes de procesamiento.',priority:6},
  dispatches:{label:'Procesar despachos',hint:'Preparar, registrar y conciliar salidas físicas.',priority:7},
  screening:{label:'Procesar tamizaje',hint:'Registrar pruebas, lotes y resultados.',priority:8},
  donors:{label:'Gestionar donantes',hint:'Captura y revisión de donantes.',priority:9},
  bloodinventory:{label:'Revisar inventario de sangre',hint:'Disponibilidad por componente, ABO y Rh.',priority:10},
  documents:{label:'Controlar documentos',hint:'Revisar documentos y cambios del SGC.',priority:11},
  competencies:{label:'Revisar competencias',hint:'Brechas, vigencias y asignaciones por puesto.',priority:12},
  command:{label:'Ver centro de mando',hint:'Excepciones, cierre diario y señales operativas.',priority:13},
  dashboard:{label:'Ver resumen ejecutivo',hint:'Indicadores priorizados según tu acceso.',priority:14}
};

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot',"'":'&#039;'}[c]))}

export async function mountMyWork(root){
  const allowed=await filterRoutes(routeList());
  const tasks=allowed
    .filter(([key])=>PRIORITY[key])
    .map(([key,meta])=>({key,meta,...PRIORITY[key]}))
    .sort((a,b)=>a.priority-b.priority)
    .slice(0,8);

  const primary=tasks.slice(0,4);
  const secondary=tasks.slice(4);

  root.innerHTML=`
    <section class="card">
      <div class="section-head"><div><h2>Mi trabajo</h2><p class="muted">Una entrada simple a lo que puedes hacer hoy según tus permisos. Los módulos técnicos permanecen disponibles en el menú.</p></div></div>
      ${primary.length?`<div class="work-grid">${primary.map((t,i)=>`
        <button class="work-card ${i===0?'primary-work':''}" data-work-route="${esc(t.key)}">
          <span class="work-kicker">${i===0?'Siguiente acción':'Tarea disponible'}</span>
          <strong>${esc(t.label)}</strong>
          <small>${esc(t.hint)}</small>
          <span class="work-open">Abrir →</span>
        </button>`).join('')}</div>`:'<div class="status warn">No hay tareas operativas disponibles para los permisos actuales.</div>'}
    </section>
    ${secondary.length?`<section class="card"><h3>También puedes continuar con</h3><div class="quick-links">${secondary.map(t=>`<button class="secondary" data-work-route="${esc(t.key)}">${esc(t.label)}</button>`).join('')}</div></section>`:''}
    <section class="card"><div class="status ok"><strong>Diseño simplificado:</strong> primero la tarea, después el módulo. La navegación avanzada sigue disponible para supervisión, calidad y administración.</div></section>`;

  root.querySelectorAll('[data-work-route]').forEach(btn=>btn.addEventListener('click',()=>navigate(btn.dataset.workRoute)));
}
