import { listDocumentRegister } from './integrated-qms-data.js';
const RESOURCES=[
['HC-SGC-MC-01','Documento Maestro Consolidado v2','./docs/recursos/HC-SGC-MC-01_Documento_Maestro_Consolidado_v2.html','GOBIERNA'],
['HC-SGC-ARQ','Arquitectura Documental v1','./docs/recursos/HC-SGC-Arquitectura-Documental-v1.html','REFERENCIA'],
['HC-CMP-AUD-001','Auditoría Penal + SGC V2','./docs/recursos/HC-CMP-Auditoria-Penal-SGC-V2.html','VALIDACIÓN LEGAL'],
['HC-CMP-MC-001','Manual de Compliance Penal','./docs/recursos/HC-CMP-MC-001_Manual_Compliance_Penal.md','BORRADOR']
];
function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
export async function mountDocuments(root){
  root.innerHTML=`<div class="sales-toolbar"><div><h2 class="section-heading">Control Documental</h2>
  <div class="muted">HC-SGC-MC-01 es la fuente única de verdad.</div></div></div>
  <div id="doc-status"></div>
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
  }catch(e){document.getElementById('doc-status').innerHTML=`<div class="status warn">${esc(e.message)} · Instale la migración v0.22.0.</div>`}
}
