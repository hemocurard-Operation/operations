// Execute the real Edge handler with a mocked SDK. No live users or credentials.
const vm=require('node:vm');
const fs=require('node:fs');
const path=require('node:path');
const {stripTypeScriptTypes}=require('node:module');
const assert=require('node:assert/strict');
(async()=>{
 let handler,mode='admin';const writes=[],rpcCalls=[];
 const tables={app_permissions:[{permission_code:'ACCESS_ADMIN',active:true}],user_roles:[{user_id:'caller',role_id:'admin-role',branch_id:'branch-a'},{user_id:'caller',role_id:'super-role',branch_id:'branch-a'}],role_permissions:[{role_id:'admin-role',permission_code:'ACCESS_ADMIN'},{role_id:'super-role',permission_code:'ACCESS_ADMIN'}],roles:[{id:'admin-role',code:'ADMIN',name:'Admin'},{id:'lab-role',code:'LABORATORIO',name:'Laboratorio'},{id:'super-role',code:'SUPER_USUARIO',name:'Superusuario'}],branches:[{id:'branch-a',code:'A',name:'Branch A',active:true},{id:'branch-b',code:'B',name:'Branch B',active:true}],profiles:[{id:'caller',active:true},{id:'target',active:true}]};
 class Query{
  constructor(table){this.table=table;this.filters=[];this.one=false;this.kind='read';}
  select(columns){if(this.table==='app_permissions')assert.equal(columns,'permission_code,active','Native permission catalog columns');return this}order(){return this}limit(){return this}
  eq(key,value){this.filters.push(row=>row[key]===value);return this}
  in(key,values){this.filters.push(row=>values.includes(row[key]));return this}
  maybeSingle(){this.one=true;return this}
  insert(payload){this.kind='insert';this.payload=payload;return this}
  upsert(payload){this.kind='upsert';this.payload=payload;return this}
  then(resolve,reject){return Promise.resolve().then(()=>{
   let rows=tables[this.table]||[];
   if(this.table==='user_roles'&&mode==='admin-only')rows=rows.filter(row=>row.role_id!=='super-role');
   if(this.table==='audit_events'&&this.kind==='insert'&&mode==='audit-error')return{data:null,error:{message:'Audit unavailable'}};
   if(this.table==='role_permissions'&&mode==='no-permission')rows=[];
   if(this.table==='profiles'&&mode==='inactive-caller')rows=rows.map(row=>row.id==='caller'?{...row,active:false}:row);
   if(this.table==='profiles'&&mode==='unknown-active')rows=rows.map(row=>row.id==='caller'?{...row,active:null}:row);
   if(this.table==='profiles'&&mode==='unknown-target-active')rows=rows.map(row=>row.id==='target'?{...row,active:null}:row);
   if(this.table==='profiles'&&mode==='inactive-target')rows=rows.map(row=>row.id==='target'?{...row,active:false}:row);
   if(this.table==='profiles'&&mode==='missing-target')rows=rows.filter(row=>row.id!=='target');
   if(this.table==='profiles'&&mode==='list-inactive')rows=rows.map(row=>row.id==='target'?{...row,active:false}:row);
   if(this.table==='profiles'&&mode==='list-null')rows=rows.map(row=>row.id==='target'?{...row,active:null}:row);
   if(this.table==='profiles'&&mode==='list-missing')rows=rows.filter(row=>row.id!=='target');
   if(this.table==='profiles'&&mode==='list-profile-error'&&!this.one)return{data:null,error:{message:'Fixture profiles unavailable'}};
   if(this.table==='app_permissions'&&['disabled-permission','actual-disabled-permission'].includes(mode))rows=rows.map(row=>({...row,active:false}));
   if(this.table==='app_permissions'&&mode==='permission-catalog-error')return{data:null,error:{message:'Fixture permission catalog unavailable'}};
   rows=rows.filter(row=>this.filters.every(filter=>filter(row)));
   if(this.kind!=='read')writes.push({table:this.table,kind:this.kind,payload:this.payload});
   return{data:this.one?rows[0]||null:rows,error:null};
  }).then(resolve,reject)}
 }
 const client={from:table=>new Query(table),auth:{getUser:async()=>mode==='invalid'?{data:{user:null},error:{message:'invalid'}}:{data:{user:{id:'caller'}},error:null},admin:{updateUserById:async(userId,values)=>{writes.push({table:'auth-password',payload:{userId,values}});return{data:{user:{id:userId}},error:mode==='password-error'?{message:'secret provider error'}:null}},listUsers:async()=>({data:{users:mode.startsWith('list-')?[{id:'target',email:'fixture@example.invalid',created_at:'2026-01-01T00:00:00Z'}]:[]},error:null})}}};
 const callerClient={...client,rpc:async(name,params)=>{
  rpcCalls.push({name,params});
  if(mode==='rpc-forbidden')return{data:null,error:{code:'42501',message:'Unauthorized branch'}};
  if(mode==='rpc-protected')return{data:null,error:{code:'23514',message:'Protected role'}};
  if(mode==='rpc-failed')return{data:null,error:{code:'P0001',message:'Audit failed'}};
  return{data:1,error:null};
 }};
 const context=vm.createContext({Request,Response,console:{error(){}},Deno:{env:{get:name=>name==='SUPABASE_URL'?'https://fixture.invalid':'not-a-live-credential'},serve:fn=>{handler=fn}}});
 const sdk=new vm.SyntheticModule(['createClient'],function(){this.setExport('createClient',(url,key,options)=>options.global?.headers?.Authorization?callerClient:client)},{context});
 const edgeRuntime=new vm.SyntheticModule([],function(){},{context});
 const source=stripTypeScriptTypes(fs.readFileSync(path.join(__dirname,'../supabase/functions/admin-users/index.ts'),'utf8'),{mode:'transform'});
 const module=new vm.SourceTextModule(source,{context});await module.link(specifier=>specifier.startsWith('npm:')?sdk:edgeRuntime);await module.evaluate();
 const results=[];
 async function run(name,authorization,body,expected,scenario='admin'){
  mode=scenario;const headers={'Content-Type':'application/json'};if(authorization)headers.Authorization=authorization;
  const response=await handler(new Request('https://fixture.invalid/admin-users',{method:'POST',headers,body:JSON.stringify(body)}));
  assert.equal(response.status,expected,name);results.push({name,pass:true});console.log('PASS '+name);
 }
 await run('I282 no JWT rejected',null,{action:'list'},401);
 await run('I282 invalid JWT rejected','Bearer fixture',{action:'list'},401,'invalid');
 await run('I282 no ACCESS_ADMIN rejected','Bearer fixture',{action:'list'},403,'no-permission');
 await run('I282 superuser lists catalogs','Bearer fixture',{action:'catalogs'},200);
 await run('Only ADMIN with ACCESS_ADMIN cannot administer accounts','Bearer fixture',{action:'catalogs'},403,'admin-only');
 for(const action of ['create','invite','add_role','remove_role'])await run('ADMIN cannot '+action,'Bearer fixture',{action},403,'admin-only');
 await run('Short temporary key rejected','Bearer fixture',{action:'create',email:'test@example.invalid',full_name:'Synthetic User',role_id:'lab-role',branch_ids:['branch-a'],password:'too-short'},400);
 await run('I291 laboratory role requires exactly one branch','Bearer fixture',{action:'add_role',user_id:'target',role_id:'lab-role',branch_ids:['branch-a','branch-b']},400);
 await run('I291 second superuser rejected','Bearer fixture',{action:'add_role',user_id:'target',role_id:'super-role'},409);
 await run('I292 authorized role assignment writes audit','Bearer fixture',{action:'add_role',user_id:'target',role_id:'lab-role',branch_ids:['branch-a']},200);
 await run('I291 inactive caller denied before mutations','Bearer fixture',{action:'remove_role',user_id:'target',role_id:'lab-role',branch_ids:['branch-a']},403,'inactive-caller');
 const before=rpcCalls.length;
 await run('I291 self retirement rejected before RPC','Bearer fixture',{action:'remove_role',user_id:'caller',role_id:'admin-role',branch_ids:['branch-a']},409);
 assert.equal(rpcCalls.length,before);
 await run('I291 empty scope rejected before RPC','Bearer fixture',{action:'remove_role',user_id:'target',role_id:'lab-role'},400);
 assert.equal(rpcCalls.length,before);
 await run('I291 retirement uses caller JWT client','Bearer fixture',{action:'remove_role',user_id:'target',role_id:'lab-role',branch_ids:['branch-a']},200);
 assert.equal(rpcCalls.at(-1).name,'remove_user_role');
 assert.equal(rpcCalls.at(-1).params.p_user_id,'target');
 assert.deepEqual(Array.from(rpcCalls.at(-1).params.p_branch_ids),['branch-a']);
 await run('I291 forbidden SQL scope remains forbidden','Bearer fixture',{action:'remove_role',user_id:'target',role_id:'lab-role',branch_ids:['branch-b']},403,'rpc-forbidden');
 await run('I291 protected SQL role returns conflict','Bearer fixture',{action:'remove_role',user_id:'target',role_id:'super-role',branch_ids:['branch-a']},409,'rpc-protected');
 await run('I292 failed audit does not report success','Bearer fixture',{action:'remove_role',user_id:'target',role_id:'lab-role',branch_ids:['branch-a']},500,'rpc-failed');
 async function rejectShape(name,body,scenario='admin',raw=false){
  mode=scenario;const beforeWrites=writes.length,beforeRpc=rpcCalls.length;
  const response=await handler(new Request('https://fixture.invalid/admin-users',{method:'POST',headers:{Authorization:'Bearer fixture','Content-Type':'application/json'},body:raw?body:JSON.stringify(body)}));
  assert.equal(response.status,scenario==='admin'?400:403,name);
  assert.equal(writes.length,beforeWrites,name+' wrote data');assert.equal(rpcCalls.length,beforeRpc,name+' invoked RPC');
  results.push({name,pass:true});console.log('PASS '+name);
 }
 await rejectShape('I650 malformed JSON rejected without writes','{', 'admin',true);
 await rejectShape('I651 null JSON rejected without writes',null);
 await rejectShape('I652 array JSON rejected without writes',[]);
 await rejectShape('I653 numeric action rejected without writes',{action:7});
 await rejectShape('I654 empty action rejected without writes',{action:' '});
 await rejectShape('I655 object user ID rejected without writes',{action:'remove_role',user_id:{id:'target'},role_id:'lab-role',branch_ids:['branch-a']});
 await rejectShape('I656 nonarray branches rejected without writes',{action:'remove_role',user_id:'target',role_id:'lab-role',branch_ids:'branch-a'});
 await rejectShape('I657 object branch rejected without writes',{action:'remove_role',user_id:'target',role_id:'lab-role',branch_ids:[{id:'branch-a'}]});
 await rejectShape('I658 unknown caller activation state denied',{action:'list'},'unknown-active');
 await rejectShape('I659 disabled administrative permission denied',{action:'catalogs'},'disabled-permission');
 async function rejectAccess(name,scenario,expected){
  mode=scenario;const beforeWrites=writes.length,beforeRpc=rpcCalls.length;
  const response=await handler(new Request('https://fixture.invalid/admin-users',{method:'POST',headers:{Authorization:'Bearer fixture','Content-Type':'application/json'},body:JSON.stringify({action:'add_role',user_id:'target',role_id:'lab-role',branch_ids:['branch-a']})}));
  assert.equal(response.status,expected,name);assert.equal(writes.length,beforeWrites,name+' wrote data');assert.equal(rpcCalls.length,beforeRpc,name+' invoked RPC');
  results.push({name,pass:true});console.log('PASS '+name);
 }
 await rejectAccess('I725 unknown target activation state denies role assignment','unknown-target-active',409);
 await rejectAccess('I726 inactive target denies role assignment','inactive-target',409);
 await rejectAccess('I727 missing target denies role assignment','missing-target',404);
 await rejectAccess('I728 permission catalog outage blocks mutation','permission-catalog-error',500);
 await rejectAccess('I729 false permission activation blocks mutation','actual-disabled-permission',403);
 async function listState(name,scenario,expected){
  mode=scenario;const beforeWrites=writes.length,beforeRpc=rpcCalls.length;
  const response=await handler(new Request('https://fixture.invalid/admin-users',{method:'POST',headers:{Authorization:'Bearer fixture','Content-Type':'application/json'},body:JSON.stringify({action:'list'})}));
  const payload=await response.json();assert.equal(response.status,expected==='error'?500:200,name);
  if(expected==='error'){assert(payload.error,name);assert.equal(payload.users,undefined,name+' fabricated users');}
  else{assert.equal(payload.users.length,1,name);assert.equal(payload.users[0].active,expected,name);}
  assert.equal(writes.length,beforeWrites,name+' wrote data');assert.equal(rpcCalls.length,beforeRpc,name+' invoked RPC');
  results.push({name,pass:true});console.log('PASS '+name);
 }
 await listState('I800 listing preserves explicitly active profile','list-active',true);
 await listState('I801 listing preserves inactive profile','list-inactive',false);
 await listState('I802 unknown activation is never listed as active','list-null',false);
 await listState('I803 missing profile is never listed as active','list-missing',false);
 await listState('I804 profile read outage does not fabricate a successful list','list-profile-error','error');
 await run('Superuser can change active target password','Bearer fixture',{action:'change_password',user_id:'target',password:'synthetic-test-key-123'},200);
 const passwordCount=()=>writes.filter(x=>x.table==='auth-password').length;
 const beforePasswords=passwordCount();
 await run('ADMIN cannot change target password','Bearer fixture',{action:'change_password',user_id:'target',password:'synthetic-test-key-123'},403,'admin-only');
 await run('Short password rejected','Bearer fixture',{action:'change_password',user_id:'target',password:'short'},400);
 await run('Missing target rejected','Bearer fixture',{action:'change_password',user_id:'absent',password:'synthetic-test-key-123'},404);
 await run('Inactive target rejected','Bearer fixture',{action:'change_password',user_id:'target',password:'synthetic-test-key-123'},409,'inactive-target');
 await run('Audit failure blocks password mutation','Bearer fixture',{action:'change_password',user_id:'target',password:'synthetic-test-key-123'},500,'audit-error');
 assert.equal(passwordCount(),beforePasswords,'Rejected password request mutated Auth');
 assert(writes.filter(x=>x.table==='audit_events').every(x=>!JSON.stringify(x.payload).includes('synthetic-test-key-123')),'Audit leaked password');
 await run('Provider failure returns controlled error','Bearer fixture',{action:'change_password',user_id:'target',password:'synthetic-test-key-123'},400,'password-error');
 assert(writes.some(x=>x.table==='audit_events'&&x.payload.user_id==='caller'&&x.payload.action==='ROLE_ASSIGNED'));
 assert(writes.some(x=>x.table==='user_roles'&&x.payload[0].branch_id==='branch-a'));
 assert.equal(writes.filter(x=>x.table==='user_roles').length,1,'rejected requests wrote roles');
 if(process.env.HEMOCURA_ADMIN_REPORT)fs.writeFileSync(process.env.HEMOCURA_ADMIN_REPORT,JSON.stringify({environment:'node-vm-edge-handler-with-mocked-sdk',production_verified:false,checks:results},null,2));
 console.log(`${results.length}/${results.length} Edge handler regressions passed`);
})().catch(error=>{console.error(error.message);process.exitCode=1});
