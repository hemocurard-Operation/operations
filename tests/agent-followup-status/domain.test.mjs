import {test} from 'node:test';import assert from 'node:assert/strict';
import {referenceBatches,followupsForFinding,followupSummary} from '../../hemocura-core/agent-followup-status.js';import {agentSourceReference} from '../../hemocura-core/agent-followup-domain.js';
const finding={source:'vw_orchestration_priority_queue',key:'x',branch_id:'b1'};
test('references are deduplicated and grouped rather than queried once per finding',()=>{const batch=referenceBatches(Array.from({length:60},(_,i)=>({...finding,key:String(i%30)})));assert.equal(batch.length,2);assert.equal(batch.flat().length,30)});
test('encoded URL budgets split large reference lists',()=>{const batches=referenceBatches(Array.from({length:10},(_,i)=>({...finding,key:'x'.repeat(500)+i})));assert(batches.length>1);assert(batches.every(b=>b.reduce((n,r)=>n+encodeURIComponent(r).length+8,0)<=3500))});
test('unsupported long references fail rather than misreporting no tasks',()=>assert.throws(()=>referenceBatches([{...finding,key:'é'.repeat(1000)}])));
test('linked tasks must retain finding branch',()=>{const tasks=['b1','b2'].map(branch_id=>({branch_id,source_reference:agentSourceReference(finding)}));assert.equal(followupsForFinding(tasks,finding).length,1)});
test('global source can have followups assigned to several authorized branches',()=>{const global={...finding,branch_id:null};const tasks=['b1','b2'].map(branch_id=>({branch_id,source_reference:agentSourceReference(global)}));assert.equal(followupsForFinding(tasks,global).length,2)});
test('only active past-due tasks are overdue',()=>{const due_at='2020-01-01T00:00:00Z';assert.deepEqual(followupSummary([{status:'PENDIENTE',due_at},{status:'COMPLETADA',due_at},{status:'CANCELADA',due_at},{status:'EN_REVISION',due_at:'2030-01-01T00:00:00Z'}],Date.parse('2026-01-01')),{total:4,active:2,overdue:1,review:1,completed:1})});
test('invalid due date does not invent an overdue deadline',()=>assert.equal(followupSummary([{status:'PENDIENTE',due_at:null}]).overdue,0));

test('pinned SDK sends correctly quoted references including commas quotes and backslashes',async()=>{
 const {createClient}=await import('../../js/vendor/supabase-2.117.3.js');const {postgrestReferences}=await import('../../hemocura-core/agent-followup-status.js');let captured;
 const client=createClient('https://fixture.invalid','public-synthetic-key',{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},global:{fetch:async(input)=>{captured=new URL(typeof input==='string'?input:input.url);return new Response('[]',{status:200,headers:{'content-type':'application/json'}})}}});
 const references=[agentSourceReference(finding),agentSourceReference({...finding,key:'value",(x)\\path'})];
 const {error}=await client.from('work_tasks').select('id').in('source_reference',postgrestReferences(references));assert.equal(error,null);assert.equal(captured.searchParams.get('source_reference'),'in.('+references.map(v=>JSON.stringify(v)).join(',')+')');
});
