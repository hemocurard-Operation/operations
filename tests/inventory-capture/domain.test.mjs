import test from 'node:test';import assert from 'node:assert/strict';import {inventoryBatchPayload} from '../../hemocura-core/inventory-capture-domain.js';
const shared={branch_id:'branch',production_date:'2026-11-20',screening_status:'PENDIENTE',inventory_status:'CUARENTENA'};
const line=()=>({component_name:'PG',quantity:2,group:'O|POSITIVO',units:[{code:'A',source:'S1'},{code:'B',source:'S2'}]});
test('quantity creates individually traceable units with shared context',()=>{const rows=inventoryBatchPayload(shared,[line()]);assert.equal(rows.length,2);assert.deepEqual(rows.map(r=>r.unit_code),['A','B']);assert.ok(rows.every(r=>r.quantity===1&&r.branch_id==='branch'&&r.abo==='O'&&r.rh==='POSITIVO'&&r.inventory_status==='CUARENTENA'))});
test('duplicates across products are rejected before any write',()=>assert.throws(()=>inventoryBatchPayload(shared,[line(),line()]),/repetidos/));
test('missing identities, group, product and fractional quantities are rejected',()=>{for(const patch of [{quantity:1.5},{group:''},{component_name:''},{units:[{code:'A',source:''}]}])assert.throws(()=>inventoryBatchPayload(shared,[{...line(),...patch}]))});
test('dates and batch size are validated',()=>{assert.throws(()=>inventoryBatchPayload({...shared,expiry_date:'2026-11-19'},[line()]));assert.throws(()=>inventoryBatchPayload(shared,[{...line(),quantity:51}]))});
