import {hemovigData} from './hemovig-data.js';
import {getBranches} from './sales-data.js';
const e=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
function nowLocal(){return new Date().toISOString().slice(0,16)}

// Post-delivery nonconformity taxonomy (hemocomponent delivered to an
// outside health center). Ported from the paper-replacement form the
// business already uses, so the categories/subtypes match what staff
// expect; nc_subtype is stored as free text, not a DB enum, so adding or
// wording a subtype differently later doesn't need a migration.
const NC_CATEGORIES=[
  ['cadena_frio','Cadena de Frío y Temperatura'],
  ['integridad','Integridad Física del Producto'],
  ['etiquetado','Etiquetado e Identificación'],
  ['documentacion','Documentación y Trazabilidad'],
  ['compatibilidad','Compatibilidad y Seguridad Transfusional'],
  ['aspecto','Aspecto Visual del Hemocomponente'],
  ['transporte','Transporte y Logística'],
  ['volumen','Volumen y Cantidad'],
  ['otro','Otro']
];
const NC_SUBTYPES={
  cadena_frio:['Temperatura superior al rango permitido al momento de la recepción','Temperatura inferior al rango permitido (congelación no esperada)','Ruptura de cadena de frío durante el transporte','Contenedor de transporte sin gel refrigerante o hielo seco','Termómetro o indicador de temperatura ausente o no funcional','Registro de temperatura del transporte incompleto o ausente'],
  integridad:['Bolsa con fuga visible o micro-perforación','Bolsa con rotura del puerto de entrada/salida','Sistema de tubuladura dañado o desconectado','Sello de seguridad roto, ausente o manipulado','Bolsa colapsada o deformada','Contaminación visible en la superficie externa de la bolsa'],
  etiquetado:['Etiqueta ilegible, borrosa o desprendida','Datos del donante incompletos en la etiqueta','Grupo sanguíneo y/o Rh no visible o ilegible','Fecha de extracción o vencimiento ausente','Fecha de vencimiento expirada','Código de barras dañado o no escaneable','Etiqueta no coincide con la documentación adjunta','Falta etiqueta de pruebas serológicas realizadas'],
  documentacion:['Formulario de solicitud transfusional incompleto','Ausencia de consentimiento informado del paciente','Resultados de pruebas de compatibilidad no adjuntos','Discrepancia entre la orden médica y el producto entregado','Falta de registro de liberación del producto por el banco de sangre','Documentación de trazabilidad incompleta (lote, código, origen)','Ausencia de resultados serológicos del donante'],
  compatibilidad:['Grupo ABO del producto no coincide con el del paciente','Factor Rh incompatible con el requerimiento del paciente','Prueba cruzada no realizada o con resultado incompatible','Producto entregado no corresponde al paciente indicado','Anticuerpos irregulares no considerados en la selección','Producto irradiado entregado sin indicación o viceversa'],
  aspecto:['Hemólisis visible (coloración rojiza del plasma/sobrenadante)','Lipemia marcada (aspecto lechoso o turbio)','Presencia de coágulos o agregados visibles','Coloración anormal del hemocomponente (verdoso, oscuro, marrón)','Presencia de burbujas de aire excesivas','Turbidez no esperada sugestiva de contaminación bacteriana','Separación anormal de fases del producto'],
  transporte:['Tiempo de transporte excedió el máximo permitido','Contenedor de transporte inadecuado o no validado','Producto expuesto a luz solar directa durante el traslado','Producto recibido sin acompañamiento del personal autorizado','Vehículo de transporte sin condiciones sanitarias adecuadas','Producto sometido a vibración o golpes excesivos durante el traslado'],
  volumen:['Volumen del producto inferior al rango esperado','Volumen del producto superior al rango esperado','Cantidad de unidades entregadas no coincide con lo solicitado','Producto con volumen residual insuficiente para transfusión'],
  otro:[]
};
const SEVERITY=[['leve','Leve','Sin impacto clínico','BAJA'],['moderada','Moderada','Requiere seguimiento','MEDIA'],['grave','Grave','Impacto clínico potencial','ALTA'],['critica','Crítica','Riesgo vital inmediato','CRITICA']];
const CAT_LABEL=Object.fromEntries(NC_CATEGORIES);

export async function mountHemovigilance(root){
  let branches=[],deliveryByEvent={};
  try{branches=await getBranches()}catch(err){}
  const branchId=branches[0]?.id||'';

  root.innerHTML=`<div class="sales-toolbar"><div><h2>Hemovigilancia</h2><div class="muted">Eventos, casi eventos, reacciones, retiros y no conformidades de entrega.</div></div><div class="quick-links"><button id="hv-new-nc" class="secondary">Registrar NC de entrega</button><button id="hv-new">Registrar evento</button></div></div><div id="hv-msg"></div><section class="card"><div class="table-wrap"><table class="data-table"><thead><tr><th>Fecha</th><th>Código</th><th>Tipo</th><th>Severidad</th><th>Unidad</th><th>Centro / categoría</th><th>Descripción</th><th>Estado</th><th>NC</th><th>CAPA</th></tr></thead><tbody id="hv-body"></tbody></table></div></section>
  <dialog id="hv-dialog" class="sales-dialog"><form id="hv-form"><h3>Evento</h3><label>Código<input id="h-code" required></label><label>Tipo<select id="h-type"><option>ERROR</option><option>CASI_EVENTO</option><option>REACCION_DONANTE</option><option>REACCION_TRANSFUSIONAL</option><option>QUEJA</option><option>RETIRO</option><option>OTRO</option></select></label><label>Severidad<select id="h-sev"><option>MEDIA</option><option>ALTA</option><option>CRITICA</option><option>BAJA</option></select></label><label>Unidad<input id="h-unit"></label><label>Descripción<textarea id="h-desc" required></textarea></label><label>Acción inmediata<textarea id="h-action"></textarea></label><div class="dialog-actions"><button type="button" id="h-cancel">Cancelar</button><button>Guardar</button></div></form></dialog>
  <dialog id="hv-nc-dialog" class="sales-dialog"></dialog>`;

  async function load(){
    try{
      const [rows,details]=await Promise.all([hemovigData.events(),hemovigData.deliveryDetails()]);
      deliveryByEvent=Object.fromEntries(details.map(d=>[d.event_id,d]));
      document.getElementById('hv-body').innerHTML=rows.length?rows.map(x=>{
        const d=deliveryByEvent[x.id];
        const centerCat=d?`${e(d.health_center)}<br><small>${e(CAT_LABEL[d.nc_category]||d.nc_category)}</small>`:'—';
        return `<tr><td>${e(new Date(x.event_date).toLocaleString('es-DO'))}</td><td><code>${e(x.event_code)}</code></td><td>${e(x.event_type)}</td><td>${e(x.severity)}</td><td>${e(x.source_unit_code||'—')}</td><td>${centerCat}</td><td>${e(x.description)}</td><td>${e(x.status)}</td><td>${x.nonconformity_id?'Sí':'No'}</td><td>${x.capa_id?'Sí':'No'}</td></tr>`;
      }).join(''):'<tr><td colspan="10">Sin eventos.</td></tr>';
      document.getElementById('hv-msg').innerHTML='';
    }catch(err){document.getElementById('hv-msg').innerHTML=`<div class="status warn">${e(err.message)}</div>`}
  }

  document.getElementById('hv-new').onclick=()=>document.getElementById('hv-dialog').showModal();
  document.getElementById('h-cancel').onclick=()=>document.getElementById('hv-dialog').close();
  document.getElementById('hv-form').onsubmit=async ev=>{
    ev.preventDefault();
    try{
      await hemovigData.create({event_code:document.getElementById('h-code').value.trim(),event_type:document.getElementById('h-type').value,severity:document.getElementById('h-sev').value,source_unit_code:document.getElementById('h-unit').value.trim()||null,description:document.getElementById('h-desc').value.trim(),immediate_action:document.getElementById('h-action').value.trim()||null,status:'ABIERTO'});
      document.getElementById('hv-dialog').close();ev.target.reset();await load();
    }catch(err){document.getElementById('hv-msg').innerHTML=`<div class="status bad">${e(err.message)}</div>`}
  };

  document.getElementById('hv-new-nc').onclick=()=>openDeliveryNC();

  function openDeliveryNC(){
    const dialog=document.getElementById('hv-nc-dialog');
    let category='',severity='';
    function subtypeOptions(){
      const list=NC_SUBTYPES[category]||[];
      return `<option value="">Seleccionar tipo…</option>${list.map(s=>`<option value="${e(s)}">${e(s)}</option>`).join('')}`;
    }
    dialog.innerHTML=`<form id="nc-form">
      <h3>No conformidad post-entrega</h3>
      <p class="muted">Hemocomponente entregado a un centro de salud externo.</p>

      <h4>1. Información general</h4>
      <div class="filter-grid">
        <label>Código<input name="event_code" required value="NC-${Date.now().toString().slice(-6)}"></label>
        <label>Sucursal HemoCura<select name="branch_id" required>${branches.map(b=>`<option value="${e(b.id)}">${e(b.name)}</option>`).join('')}</select></label>
        <label>Centro de salud receptor<input name="health_center" required></label>
        <label>Nombre del paciente<input name="patient_name" required></label>
        <label>Fecha y hora de entrega<input name="delivered_at" type="datetime-local" value="${nowLocal()}" required></label>
      </div>

      <h4>Datos de quien reporta</h4>
      <div class="filter-grid">
        <label>Nombre completo<input name="reporter_name" required></label>
        <label>Cargo<input name="reporter_role" required placeholder="Ej: Bioanalista, Enfermera"></label>
        <label>Teléfono<input name="reporter_phone" type="tel" required></label>
      </div>

      <h4>2. Datos del hemocomponente</h4>
      <div class="filter-grid">
        <label>Tipo de hemocomponente<select name="component_type" required>
          <option value="">Seleccionar…</option>
          <option>Paquete de Sangre Total</option><option>Paquete Globular</option><option>Hematíes lavados</option>
          <option>Plasma Congelado</option><option>Plasma Fresco</option><option>Plaqueta por aféresis</option><option>Plasma por aféresis</option>
        </select></label>
        <label>Nº unidades<input name="units" type="number" min="1" required></label>
        <label>Grupo sanguíneo<select name="abo" required><option value="">Seleccionar…</option><option>A</option><option>B</option><option>AB</option><option>O</option></select></label>
        <label>Factor Rh<select name="rh" required><option value="">Seleccionar…</option><option value="POSITIVO">Positivo (+)</option><option value="NEGATIVO">Negativo (−)</option></select></label>
        <label>Código del producto<input name="product_code"></label>
        <label>Fecha de extracción<input name="collection_date" type="date"></label>
        <label>Fecha de vencimiento<input name="expiry_date" type="date"></label>
        <label>Volumen (ml)<input name="volume_ml" type="number" min="1"></label>
        <label>Procedencia<select name="origin"><option value="">Seleccionar…</option><option>Donación voluntaria</option><option>Donación por reposición</option><option>Aféresis</option></select></label>
      </div>

      <h4>3. No conformidad detectada</h4>
      <div class="filter-grid">
        <label>Categoría<select id="nc-category" name="nc_category" required><option value="">Seleccionar categoría…</option>${NC_CATEGORIES.map(([k,l])=>`<option value="${k}">${e(l)}</option>`).join('')}</select></label>
        <label>Tipo específico<select id="nc-subtype" name="nc_subtype">${subtypeOptions()}</select></label>
      </div>
      <div class="filter-grid" id="nc-temp-fields" hidden>
        <label>Temp. registrada (°C)<input name="temp_registered" placeholder="Ej: 12°C"></label>
        <label>Temp. esperada (°C)<input name="temp_expected" placeholder="Ej: 2-6°C"></label>
      </div>
      <label>Severidad</label>
      <div class="quick-links" id="nc-severity">${SEVERITY.map(([k,label,desc])=>`<button type="button" class="secondary" data-sev="${k}">${e(label)}<br><small>${e(desc)}</small></button>`).join('')}</div>
      <input type="hidden" name="severity_scale" required>
      <label>Descripción detallada<textarea name="description" required></textarea></label>

      <h4>4. Evidencia</h4>
      <div class="filter-grid">
        <label>Referencia foto del paquete<input name="evidence_package_ref" placeholder="Nombre de archivo, enlace o ubicación de la evidencia"></label>
        <label>Referencia foto de la tarjeta<input name="evidence_card_ref" placeholder="Nombre de archivo, enlace o ubicación de la evidencia"></label>
      </div>

      <h4>5. Acciones y disposición</h4>
      <label>Acción inmediata tomada<textarea name="immediate_action" required></textarea></label>
      <div class="filter-grid">
        <label>¿Producto devuelto?<select name="product_returned" required><option value="">Seleccionar…</option><option value="true">Sí</option><option value="false">No</option></select></label>
        <label>¿Médico notificado?<select name="doctor_notified"><option value="">Seleccionar…</option><option value="true">Sí</option><option value="false">No</option></select></label>
      </div>
      <p data-dialog-error role="alert"></p>
      <div class="dialog-actions"><button type="button" id="nc-cancel" class="secondary">Cancelar</button><button type="submit">Registrar no conformidad</button></div>
    </form>`;

    dialog.querySelector('#nc-cancel').onclick=()=>dialog.close();
    dialog.querySelector('#nc-category').onchange=ev=>{
      category=ev.target.value;
      dialog.querySelector('#nc-subtype').innerHTML=subtypeOptions();
      dialog.querySelector('#nc-temp-fields').hidden=category!=='cadena_frio';
    };
    dialog.querySelectorAll('[data-sev]').forEach(btn=>btn.onclick=()=>{
      severity=btn.dataset.sev;
      dialog.querySelectorAll('[data-sev]').forEach(b=>b.classList.toggle('primary',b===btn));
      dialog.querySelector('[name=severity_scale]').value=severity;
    });

    dialog.querySelector('#nc-form').onsubmit=async ev=>{
      ev.preventDefault();
      const fd=Object.fromEntries(new FormData(ev.target));
      if(!severity){dialog.querySelector('[data-dialog-error]').textContent='Seleccione un nivel de severidad.';return}
      if(category==='otro'&&!fd.nc_subtype){dialog.querySelector('[data-dialog-error]').textContent='Especifique el tipo de no conformidad.';return}
      const dbSeverity=SEVERITY.find(([k])=>k===severity)[3];
      try{
        await hemovigData.createDeliveryNC(fd.branch_id,{
          event_code:fd.event_code,health_center:fd.health_center,patient_name:fd.patient_name,
          delivered_at:fd.delivered_at,reporter_name:fd.reporter_name,reporter_role:fd.reporter_role,
          reporter_phone:fd.reporter_phone,component_type:fd.component_type,units:fd.units,
          abo:fd.abo,rh:fd.rh,product_code:fd.product_code||'',collection_date:fd.collection_date||'',
          expiry_date:fd.expiry_date||'',volume_ml:fd.volume_ml||'',origin:fd.origin||'',
          nc_category:fd.nc_category,nc_subtype:fd.nc_subtype||'Otro (especifique a continuación)',
          temp_registered:fd.temp_registered||'',temp_expected:fd.temp_expected||'',
          product_returned:fd.product_returned,doctor_notified:fd.doctor_notified||'',
          evidence_package_ref:fd.evidence_package_ref||'',evidence_card_ref:fd.evidence_card_ref||'',
          description:fd.description,immediate_action:fd.immediate_action,severity:dbSeverity
        });
        dialog.close();
        await load();
      }catch(err){dialog.querySelector('[data-dialog-error]').textContent=err.message}
    };
    dialog.showModal();
  }

  await load();
}
