import fs from 'node:fs';
import assert from 'node:assert/strict';

const source=fs.readFileSync(new URL('../hemocura-core/data-quality-engine.js',import.meta.url),'utf8');
const engine=await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);

let passed=0;
function test(name,fn){
  try{fn();passed++;console.log(`PASS ${name}`)}
  catch(error){console.error(`FAIL ${name}: ${error.message}`);process.exitCode=1}
}

test('detect donors after title row',()=>{
  const csv='01_DONANTES — REGISTRO POR DONANTE\nID,Fecha,Hora,Sucursal,Donante/Código,Tipo de Donante,Grupo ABO,Rh,Estado\n1,2026-10-09,08:00,Santiago,D-001,VOLUNTARIO,O,POSITIVO,PENDIENTE';
  const r=engine.analyzeCsv(csv,'auto');
  assert.equal(r.template,'donors');assert.equal(r.headerRow,1);assert.equal(r.status,'PASS');
});

test('screening requires explicit result',()=>{
  const csv='ID,Fecha,Sucursal,Código de Unidad,Tipo de Prueba,Resultado,Estado\n1,2026-10-09,Santiago,U-1,VIH,,PENDIENTE';
  const r=engine.analyzeCsv(csv,'screening');
  assert.equal(r.status,'BLOCKED');assert.ok(r.issues.some(x=>x.code==='REQUIRED_BLANK'&&x.column==='Resultado'));
});

test('spreadsheet error token blocks',()=>{
  const csv='ID,Fecha,Sucursal,Unidad Origen,Componente,Cantidad,Estado\n1,2026-10-09,Santiago,U-1,Plasma,#REF!,CUARENTENA';
  const r=engine.analyzeCsv(csv,'production');
  assert.equal(r.status,'BLOCKED');assert.ok(r.issues.some(x=>x.code==='SPREADSHEET_ERROR'));
});

test('duplicate screening key blocks',()=>{
  const csv='ID,Fecha,Sucursal,Código de Unidad,Tipo de Prueba,Resultado\n1,2026-10-09,Santiago,U-1,VIH,NO_REACTIVO\n2,2026-10-09,Santiago,U-1,VIH,NO_REACTIVO';
  const r=engine.analyzeCsv(csv,'screening');
  assert.ok(r.issues.some(x=>x.code==='DUPLICATE_KEY'));
});

test('negative quantities are blocked',()=>{
  const csv='Folio,Fecha Solicitud,Sucursal,Item,Cantidad,Prioridad,Estado\nF-1,2026-10-09,Santiago,Bolsa,-2,NORMAL,PENDIENTE';
  const r=engine.analyzeCsv(csv,'requests');
  assert.ok(r.issues.some(x=>x.code==='INVALID_NUMBER'));
});

test('semicolon delimiter supported',()=>{
  const csv='ID;Fecha;Centro;Sucursal;Componente;Cantidad;Estado\n1;2026-10-09;Clinica A;Santiago;Plasma;1;BORRADOR';
  const r=engine.analyzeCsv(csv,'dispatches');
  assert.equal(r.rowCount,1);assert.equal(r.errors,0);
});

test('quoted delimiter supported',()=>{
  const rows=engine.parseCsv('ID,Fecha,Sucursal,Donante/Código,Tipo de Donante,Estado,Observaciones\n1,2026-10-09,Santiago,D-1,VOLUNTARIO,PENDIENTE,"Nota, con coma"');
  assert.equal(rows[1][6],'Nota, con coma');
});

test('generic template still finds formula errors',()=>{
  const r=engine.analyzeCsv('A,B\n1,#DIV/0!','generic');
  assert.equal(r.status,'BLOCKED');assert.ok(r.issues.some(x=>x.code==='SPREADSHEET_ERROR'));
});

if(process.exitCode)process.exit(process.exitCode);
console.log(`\nPASS ${passed}/8 data-quality engine checks`);
