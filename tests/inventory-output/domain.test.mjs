import test from 'node:test';
import assert from 'node:assert/strict';
import {eligibleOutputUnits,outputPayload,outputSummary} from '../../hemocura-core/inventory-output-domain.js';
const unit={id:'u1',branch_id:'b1',quantity:2,expiry_date:'2026-11-08'};
const fields={sale_code:' SAL-1 ',sale_date:'2026-11-08',branch_id:'b1',customer_id:'c1',shift:'DIURNO',treating_doctor:' Doctor ',unit_price:900,collected_amount:100,status:'COBRADA',invoice_number:'fake'};
test('output payload excludes financial input and uses complete source quantity',()=>{
 const p=outputPayload(fields,unit,'2026-11-08');assert.equal(p.header.status,'DESPACHADA');assert.equal(p.header.invoice_number,null);assert.equal(p.header.total_amount,0);assert.equal(p.header.collected_amount,0);assert.equal(p.lines[0].unit_price,0);assert.equal(p.lines[0].quantity,2);assert.equal(p.header.sale_code,'SAL-1');
});
test('eligibility respects Dominican cutoff, branch and valid source quantity',()=>{
 assert.equal(eligibleOutputUnits([unit],'b1','2026-11-08').length,1);
 for(const u of [{...unit,expiry_date:'2026-11-07'},{...unit,expiry_date:null},{...unit,quantity:NaN},{...unit,quantity:0},{...unit,branch_id:'b2'}])assert.throws(()=>outputPayload(fields,u,'2026-11-08'));
 assert.throws(()=>outputPayload(fields,null,'2026-11-08'));
});
test('summary excludes cancelled deliveries and counts source quantities',()=>{
 assert.deepEqual(outputSummary([{id:'s1',customer_id:'c1',status:'DESPACHADA'},{id:'s2',customer_id:'c1',status:'FACTURADA'},{id:'s3',customer_id:'c2',status:'CANCELADA'}],[{sale_id:'s1',quantity:2},{sale_id:'s2',quantity:1},{sale_id:'s3',quantity:50}]),{records:2,units:3,centers:1});
});
