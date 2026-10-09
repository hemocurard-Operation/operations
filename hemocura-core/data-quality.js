import { analyzeCsv, templateOptions, issuesToCsv } from './data-quality-engine.js';

function esc(v=''){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
function badge(label,value,tone='info'){return `<section class="card ops-kpi-card"><div class="muted">${esc(label)}</div><div class="kpi">${esc(value)}</div><span class="state-pill state-${tone}">${esc(tone==='ok'?'PASS':tone==='bad'?'BLOQUEADO':'INFO')}</span></section>`}
function saveText(name,text,type='text/csv;charset=utf-8'){const blob=new Blob([text],{type}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000)}

export async function mountDataQuality(root){
  const options=templateOptions().map(x=>`<option value="${esc(x.value)}">${esc(x.label)}</option>`).join('');
  root.innerHTML=`
    <div class="sales-toolbar"><div><h2 class="section-heading">Calidad de Datos</h2><div class="muted">Preflight local para archivos heredados antes de migrar o copiar información a HemoCura.</div></div><span class="role-chip">v0.45.3 · SHADOW</span></div>
    <section class="card">
      <div class="status info"><strong>No importa ni modifica datos.</strong> El archivo se analiza únicamente en este navegador. Este módulo no determina elegibilidad, compatibilidad ni liberación clínica.</div>
      <div class="quick-form-grid">
        <label>Archivo CSV<input id="dq-file" type="file" accept=".csv,text/csv,text/plain"></label>
        <label>Plantilla<select id="dq-template"><option value="auto">Detectar automáticamente</option>${options}<option value="generic">Genérica</option></select></label>
      </div>
      <div class="dialog-actions"><button id="dq-analyze" disabled>Analizar archivo</button></div>
      <small class="muted">Para libros `.xlsx`, exporte únicamente la hoja que desea revisar como CSV. Esta versión no ejecuta fórmulas de Excel ni interpreta macros.</small>
    </section>
    <div id="dq-result"><section class="card"><div class="muted">Seleccione un CSV para iniciar el preflight.</div></section></div>`;

  const input=document.getElementById('dq-file'),button=document.getElementById('dq-analyze'),template=document.getElementById('dq-template'),out=document.getElementById('dq-result');
  let current=null;
  input.addEventListener('change',()=>{button.disabled=!input.files?.length;current=null});

  function renderResult(result,fileName){
    const tone=result.status==='PASS'?'ok':'bad';
    const issues=result.issues.slice(0,100);
    const previewHeaders=result.headers.slice(0,12);
    const previewRows=result.preview.slice(0,8);
    out.innerHTML=`
      <section class="ops-section"><div class="ops-section-head"><div><div class="eyebrow">Resultado</div><h3>${esc(fileName)}</h3><div class="muted">Plantilla: ${esc(result.templateLabel)} · encabezado detectado en fila ${result.headerRow+1}</div></div><strong class="state-pill state-${tone}">${esc(result.status)}</strong></div>
        <div class="ops-kpi-grid">${badge('Filas',result.rowCount,'info')}${badge('Columnas',result.columnCount,'info')}${badge('Errores',result.errors,result.errors?'bad':'ok')}${badge('Advertencias',result.warnings,result.warnings?'warn':'ok')}</div>
      </section>
      <section class="card">
        <div class="card-head"><div><h3>Incidencias</h3><div class="muted">El archivo queda BLOQUEADO mientras exista al menos un error.</div></div><button id="dq-download" class="secondary" ${result.issues.length?'':'disabled'}>Descargar reporte CSV</button></div>
        ${issues.length?`<div class="table-wrap"><table class="data-table"><thead><tr><th>Nivel</th><th>Código</th><th>Fila</th><th>Columna</th><th>Detalle</th></tr></thead><tbody>${issues.map(i=>`<tr><td><span class="state-pill state-${i.severity==='error'?'bad':'warn'}">${esc(i.severity.toUpperCase())}</span></td><td><code>${esc(i.code)}</code></td><td>${esc(i.row)}</td><td>${esc(i.column)}</td><td>${esc(i.message)}</td></tr>`).join('')}</tbody></table></div>${result.issues.length>100?`<div class="status warn">Se muestran las primeras 100 de ${esc(result.issues.length)} incidencias. El reporte descargable contiene todas.</div>`:''}`:'<div class="status ok">No se detectaron incidencias bloqueantes en las reglas de esta plantilla.</div>'}
      </section>
      <section class="card"><h3>Vista previa</h3><div class="muted">Máximo 8 filas y 12 columnas. No se guarda en HemoCura.</div>${previewHeaders.length?`<div class="table-wrap"><table class="data-table"><thead><tr>${previewHeaders.map(h=>`<th>${esc(h||'Sin encabezado')}</th>`).join('')}</tr></thead><tbody>${previewRows.map(row=>`<tr>${previewHeaders.map(h=>`<td>${esc(row[h]??'')}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`:'<div class="status bad">No fue posible identificar encabezados.</div>'}</section>
      <section class="card"><h3>Regla de uso</h3><p class="muted">PASS significa que el archivo superó este preflight estructural; no significa validación clínica, regulatoria ni autorización de importación. La carga a Supabase permanece fuera de alcance en esta versión.</p></section>`;
    document.getElementById('dq-download')?.addEventListener('click',()=>saveText(`hemocura-calidad-datos-${Date.now()}.csv`,issuesToCsv(result)));
  }

  button.addEventListener('click',async()=>{
    const file=input.files?.[0];if(!file)return;
    if(!/\.csv$/i.test(file.name)){out.innerHTML='<section class="card"><div class="status bad"><strong>Formato no permitido.</strong> Exporte la hoja requerida como CSV antes de analizarla.</div></section>';return}
    button.disabled=true;button.textContent='Analizando…';
    try{
      const text=await file.text();
      current=analyzeCsv(text,template.value);
      renderResult(current,file.name);
    }catch(error){out.innerHTML=`<section class="card"><div class="status bad"><strong>No se pudo analizar el archivo.</strong><br>${esc(error?.message||String(error))}</div></section>`}
    finally{button.disabled=false;button.textContent='Analizar archivo'}
  });
}
