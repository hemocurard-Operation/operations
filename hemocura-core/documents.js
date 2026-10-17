import {filterRoutes} from './access-control.js';
import {routeList} from './router.js';
import { listDocumentRegister } from './integrated-qms-data.js';
const RESOURCES=[
['HC-SGC-IMP-001','Guía de implementación por etapas','./docs/recursos/HC-SGC-IMP-001_Guia_Implementacion_SGC.html','BORRADOR PARA APROBACIÓN'],
['HC-SGC-MC-01','Documento Maestro: adaptación v3','./docs/recursos/HC-SGC-MC-01_Documento_Maestro_v3_Borrador.html','BORRADOR · v2 CONSERVADO COMO ANTECEDENTE'],
['HC-SGC-ARQ','Arquitectura documental conectada v2','./docs/recursos/HC-SGC-ARQ_Arquitectura_v2_Borrador.html','BORRADOR'],
['HC-TRN-SUITE-001','Programa de Capacitación: correspondencia con el proyecto','./docs/recursos/HC-SGC-IMP-001_Guia_Implementacion_SGC.html#capacitacion','CONSULTAR VERSIÓN Y ESTADO EN REGISTRO'],
['HC-CMP-AUD-001','Auditoría Penal + SGC: antecedente y anexo','./docs/recursos/HC-CMP-Auditoria-Penal-SGC-V2.html','REQUIERE VALIDACIÓN JURÍDICA'],
['HC-CMP-MC-001','Manual de Compliance Penal','./docs/recursos/HC-CMP-MC-001_Manual_Compliance_Penal.md','BORRADOR · REQUIERE VALIDACIÓN JURÍDICA']
];
function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
export async function mountDocuments(root){
  let implementationAllowed=false;try{implementationAllowed=(await filterRoutes(routeList())).some(([key])=>key==='sgcimplementation')}catch{}
  root.innerHTML=`<div class="sales-toolbar"><div><h2 class="section-heading">Control Documental</h2>
  <div class="muted">Consulte código, versión y aprobación. Las guías del proyecto no sustituyen documentos vigentes.</div></div></div>
  <div id="doc-status"></div><section class="card"><h3>Proyecto de implementación del SGC</h3><p>Organice alcance, responsables, entregables y evidencia siguiendo seis fases y doce puertas.</p>${implementationAllowed?'<a href="#sgcimplementation">Abrir proyecto guiado →</a>':''}</section>
  <section class="card"><h3>Registro vivo en Supabase</h3><div class="table-wrap"><table class="data-table">
  <thead><tr><th>Código</th><th>Título</th><th>Área</th><th>Tipo</th><th>Versión</th><th>Estado</th></tr></thead><tbody id="doc-db"></tbody></table></div></section>
  <section class="card"><h3>Recursos integrados</h3><div class="table-wrap"><table class="data-table">
  <thead><tr><th>Código</th><th>Documento</th><th>Estado</th><th></th></tr></thead><tbody>
  ${RESOURCES.map(x=>`<tr><td><code>${esc(x[0])}</code></td><td>${esc(x[1])}</td><td>${esc(x[3])}</td><td><a class="secondary compact" href="${x[2]}" target="_blank" rel="noopener">Abrir</a></td></tr>`).join('')}
  </tbody></table></div></section>`;
  try{
    const rows=await listDocumentRegister();
    document.getElementById('doc-db').innerHTML=rows.length?rows.map(r=>`<tr><td><code>${esc(r.document_code)}</code></td>
    <td>${esc(r.title)}</td><td>${esc(r.area)}</td><td>${esc(r.document_type)}</td><td>${esc(r.version)}</td><td>${esc(r.status)}</td></tr>`).join(''):
    `<tr><td colspan="6" class="muted">Registro documental vacío. La estructura ya está disponible para cargar la Lista Maestra.</td></tr>`;
  }catch(e){document.getElementById('doc-status').innerHTML=`<div class="status warn">${esc(e.message)} · Reintente actualizar la información.</div>`}
}
