import test from 'node:test';import assert from 'node:assert/strict';import {assignedBranches,defaultDepartment} from '../../hemocura-core/operations-form-context.js';
const branches=[{id:'a'},{id:'b'}];
test('branch staff never inherit corporate scope from broad permissions',()=>assert.deepEqual(assignedBranches(branches,{context:{profile_branch_id:'a',roles:['ENCARGADA_LABORATORIO','CALIDAD']}}),[{id:'a'}]));
test('only super user can pick all branches and missing assignment fails closed',()=>{assert.equal(assignedBranches(branches,{context:{roles:['SUPER_USUARIO']}}).length,2);assert.equal(assignedBranches(branches,{context:{roles:['ADMIN']}}).length,0)});
test('department suggestions follow operational role',()=>{assert.equal(defaultDepartment({roles:['ENCARGADA_LABORATORIO']}),'Laboratorio');assert.equal(defaultDepartment({roles:['LOGISTICA_CONDUCTOR']}),'Logística')});
