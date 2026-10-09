const ERROR_TOKENS = new Set(['#REF!','#DIV/0!','#VALUE!','#NAME?','#N/A','#NUM!','#NULL!']);

const TEMPLATE_DEFS = {
  donors: {
    label:'Donantes',
    headers:['ID','Fecha','Hora','Sucursal','Donante/Código','Tipo de Donante','Grupo ABO','Rh','Estado','Aceptado','Diferido','Donación Efectiva','Motivo Diferimiento','Observaciones','Registrado Por','Fecha de Registro'],
    required:['Fecha','Sucursal','Donante/Código','Tipo de Donante','Estado'],
    unique:[['Donante/Código']],
    numeric:[]
  },
  screening: {
    label:'Tamizaje',
    headers:['ID','Fecha','Sucursal','Código de Unidad','Tipo de Prueba','Resultado','Reactivo','Lote','Vencimiento','Responsable','Estado','Registrado Por','Fecha de Registro'],
    required:['Fecha','Sucursal','Código de Unidad','Tipo de Prueba','Resultado'],
    unique:[['Código de Unidad','Tipo de Prueba']],
    numeric:[]
  },
  production: {
    label:'Producción',
    headers:['ID','Fecha','Sucursal','Unidad Origen','Componente','Grupo ABO','Rh','Cantidad','Vencimiento','Responsable','Estado','Registrado Por','Fecha de Registro'],
    required:['Fecha','Sucursal','Unidad Origen','Componente','Cantidad','Estado'],
    unique:[['Unidad Origen','Componente']],
    numeric:['Cantidad']
  },
  dispatches: {
    label:'Despachos',
    headers:['ID','Fecha','Hora','Centro','Sucursal','Solicitud','Paciente/Código','Componente','Grupo ABO','Rh','Cantidad','Responsable','Estado','Registrado Por','Fecha de Registro'],
    required:['Fecha','Centro','Sucursal','Componente','Cantidad','Estado'],
    unique:[['ID']],
    numeric:['Cantidad']
  },
  requests: {
    label:'Solicitudes',
    headers:['ID','Folio','Fecha Solicitud','Sucursal','Tipo','Item','Cantidad','Unidad','Prioridad','Justificación','Estado','Solicitado Por','Fecha de Registro','Comentario de Gerencia','Actualizado Por','Fecha de Actualización'],
    required:['Folio','Fecha Solicitud','Sucursal','Item','Cantidad','Prioridad','Estado'],
    unique:[['Folio','Item']],
    numeric:['Cantidad']
  },
  daily: {
    label:'Registro diario',
    headers:['ID','Fecha','Sucursal','Donantes Registrados','Donantes Diferidos','Unidades Recolectadas','Unidades Tamizadas','Unidades Reactivas','Unidades Aptas','Unidades Despachadas','Unidades Facturadas','Ingreso Facturado (DOP)','Observaciones','Registrado Por','Fecha de Registro'],
    required:['Fecha','Sucursal'],
    unique:[['Fecha','Sucursal']],
    numeric:['Donantes Registrados','Donantes Diferidos','Unidades Recolectadas','Unidades Tamizadas','Unidades Reactivas','Unidades Aptas','Unidades Despachadas','Unidades Facturadas','Ingreso Facturado (DOP)']
  }
};

export function normalizeHeader(value=''){
  return String(value??'').trim().normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim();
}

function normalizedMap(headers=[]){
  const map=new Map();
  headers.forEach((h,i)=>{const n=normalizeHeader(h);if(n&&!map.has(n))map.set(n,i)});
  return map;
}

function parseWithDelimiter(text,delimiter){
  const rows=[];let row=[],cell='',quoted=false;
  for(let i=0;i<text.length;i++){
    const ch=text[i],next=text[i+1];
    if(ch==='"'){
      if(quoted&&next==='"'){cell+='"';i++;continue}
      quoted=!quoted;continue;
    }
    if(ch===delimiter&&!quoted){row.push(cell);cell='';continue}
    if((ch==='\n'||ch==='\r')&&!quoted){
      if(ch==='\r'&&next==='\n')i++;
      row.push(cell);cell='';
      if(row.some(v=>String(v).trim()!==''))rows.push(row);
      row=[];continue;
    }
    cell+=ch;
  }
  row.push(cell);if(row.some(v=>String(v).trim()!==''))rows.push(row);
  return rows;
}

export function detectDelimiter(text=''){
  const candidates=[',',';','\t'];
  let best={delimiter:',',score:-1};
  for(const delimiter of candidates){
    const rows=parseWithDelimiter(String(text).slice(0,25000),delimiter).slice(0,12);
    if(!rows.length)continue;
    const widths=rows.map(r=>r.length).filter(n=>n>1);
    if(!widths.length)continue;
    const mode=[...new Set(widths)].map(n=>({n,count:widths.filter(x=>x===n).length})).sort((a,b)=>b.count-a.count||b.n-a.n)[0];
    const score=mode.count*100+mode.n;
    if(score>best.score)best={delimiter,score};
  }
  return best.delimiter;
}

export function parseCsv(text=''){
  const clean=String(text??'').replace(/^\uFEFF/,'');
  return parseWithDelimiter(clean,detectDelimiter(clean));
}

function templateScore(row,def){
  const rowSet=new Set(row.map(normalizeHeader).filter(Boolean));
  const expected=def.headers.map(normalizeHeader);
  return expected.filter(h=>rowSet.has(h)).length;
}

export function detectTemplate(rows=[]){
  let best={template:'generic',score:0,headerRow:0};
  const scan=rows.slice(0,10);
  for(let r=0;r<scan.length;r++){
    for(const [key,def] of Object.entries(TEMPLATE_DEFS)){
      const score=templateScore(scan[r],def);
      if(score>best.score)best={template:key,score,headerRow:r};
    }
  }
  return best.score>=3?best:{template:'generic',score:best.score,headerRow:0};
}

function emptyRow(row=[]){return !row.some(v=>String(v??'').trim()!=='')}
function errorToken(value=''){return ERROR_TOKENS.has(String(value??'').trim().toUpperCase())}
function rowObject(headers,row){const o={};headers.forEach((h,i)=>{o[h]=row[i]??''});return o}
function headerIndex(headers,name){return normalizedMap(headers).get(normalizeHeader(name))}
function cell(headers,row,name){const i=headerIndex(headers,name);return i===undefined?'':String(row[i]??'').trim()}
function positiveNumber(value){if(String(value??'').trim()==='')return false;const n=Number(String(value).replace(/,/g,''));return Number.isFinite(n)&&n>=0}

export function analyzeRows(rows=[],templateChoice='auto'){
  const detected=detectTemplate(rows);
  const template=templateChoice==='auto'?detected.template:templateChoice;
  const def=TEMPLATE_DEFS[template]||null;
  let headerRow=detected.headerRow;
  if(def&&templateChoice!=='auto'){
    let best={score:-1,row:0};
    rows.slice(0,10).forEach((row,i)=>{const score=templateScore(row,def);if(score>best.score)best={score,row:i}});
    headerRow=best.row;
  }
  const headers=(rows[headerRow]||[]).map(v=>String(v??'').trim());
  const dataRows=rows.slice(headerRow+1).filter(r=>!emptyRow(r));
  const issues=[];
  const add=(severity,code,row,column,message,value='')=>issues.push({severity,code,row,column,message,value});

  const dupHeaders=[];const seenHeaders=new Set();
  headers.forEach(h=>{const n=normalizeHeader(h);if(!n)return;if(seenHeaders.has(n))dupHeaders.push(h);seenHeaders.add(n)});
  dupHeaders.forEach(h=>add('error','DUPLICATE_HEADER',headerRow+1,h,`Encabezado duplicado: ${h}`));

  if(def){
    const map=normalizedMap(headers);
    for(const req of def.required){if(!map.has(normalizeHeader(req)))add('error','MISSING_HEADER',headerRow+1,req,`Falta columna obligatoria: ${req}`)}
    dataRows.forEach((row,idx)=>{
      const line=headerRow+2+idx;
      for(const req of def.required){const col=headerIndex(headers,req);if(col!==undefined&&String(row[col]??'').trim()==='')add('error','REQUIRED_BLANK',line,req,`Campo obligatorio vacío: ${req}`)}
      for(const num of def.numeric){const col=headerIndex(headers,num);if(col!==undefined&&String(row[col]??'').trim()!==''&&!positiveNumber(row[col]))add('error','INVALID_NUMBER',line,num,`Valor numérico inválido en ${num}`,row[col])}
      row.forEach((v,c)=>{if(errorToken(v))add('error','SPREADSHEET_ERROR',line,headers[c]||`Columna ${c+1}`,`Token de error heredado: ${String(v).trim()}`,v)});
    });
    for(const keyCols of def.unique){
      if(keyCols.every(k=>headerIndex(headers,k)!==undefined)){
        const seen=new Map();
        dataRows.forEach((row,idx)=>{
          const key=keyCols.map(k=>normalizeHeader(cell(headers,row,k))).join('|');
          if(!key.replaceAll('|',''))return;
          const line=headerRow+2+idx;
          if(seen.has(key))add('error','DUPLICATE_KEY',line,keyCols.join(' + '),`Duplicado respecto a fila ${seen.get(key)}: ${keyCols.join(' + ')}`);
          else seen.set(key,line);
        });
      }
    }
  }else{
    dataRows.forEach((row,idx)=>row.forEach((v,c)=>{if(errorToken(v))add('error','SPREADSHEET_ERROR',headerRow+2+idx,headers[c]||`Columna ${c+1}`,`Token de error heredado: ${String(v).trim()}`,v)}));
    add('warning','GENERIC_TEMPLATE',headerRow+1,'',`No se reconoció una plantilla HemoCura con suficiente certeza. Se aplicaron controles genéricos.`);
  }

  const errors=issues.filter(i=>i.severity==='error').length;
  const warnings=issues.filter(i=>i.severity==='warning').length;
  return {
    status:errors?'BLOCKED':'PASS',template,templateLabel:def?.label||'Genérica',detectedTemplate:detected.template,
    headerRow,headers,dataRows,rowCount:dataRows.length,columnCount:headers.length,errors,warnings,issues,
    preview:dataRows.slice(0,8).map(row=>rowObject(headers,row))
  };
}

export function analyzeCsv(text='',templateChoice='auto'){
  return analyzeRows(parseCsv(text),templateChoice);
}

export function templateOptions(){
  return Object.entries(TEMPLATE_DEFS).map(([value,def])=>({value,label:def.label}));
}

export function issuesToCsv(result){
  const q=v=>`"${String(v??'').replaceAll('"','""')}"`;
  const rows=[['Severidad','Código','Fila','Columna','Mensaje','Valor']].concat((result?.issues||[]).map(i=>[i.severity,i.code,i.row,i.column,i.message,i.value]));
  return rows.map(r=>r.map(q).join(',')).join('\r\n');
}
