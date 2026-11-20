// Used only by the opaque-origin, network-disabled screen preview.
let configuration=null;
export function configureWorkspaceScreen(value){configuration=value;}
const denied=()=>({data:null,error:{message:'Vista de demostración: no permite guardar ni consultar registros reales.'}});
class ReadOnlyQuery{
 constructor(table){this.table=table;this.one=false;this.write=false;this.start=0;this.end=Infinity;this.filters=[];}
 select(){return this}eq(key,value){this.filters.push(r=>r[key]===value);return this}neq(){return this}in(){return this}is(){return this}not(){return this}or(){return this}gte(){return this}lte(){return this}gt(){return this}lt(){return this}ilike(){return this}order(){return this}limit(n){this.end=n-1;return this}range(a,b){this.start=a;this.end=b;return this}match(){return this}abortSignal(){return this}filter(){return this}
 single(){this.one=true;return this}maybeSingle(){this.one=true;return this}
 insert(){this.write=true;return this}upsert(){this.write=true;return this}update(){this.write=true;return this}delete(){this.write=true;return this}
 then(resolve,reject){return Promise.resolve().then(()=>{if(!configuration||this.write)return denied();let rows=[];const c=configuration;
  if(this.table==='vw_my_security_context')rows=[c.context];
  if(this.table==='vw_my_access')rows=c.permissions.map(permission_code=>({permission_code,module:'VISTA_PREVIA',role_code:c.roles[0]||'',user_id:c.context.user_id}));
  if(this.table==='vw_my_module_access')rows=c.routes.map(route_key=>({route_key,enabled:true}));
  if(this.table==='branches')rows=c.branches;
  if(this.table==='suppliers')rows=c.branches.map((b,i)=>({id:'practice-supplier-'+i,branch_id:b.id,legal_name:'Proveedor de práctica · '+b.name,status:'ACTIVO',critical:false}));
  if(this.table==='profiles')rows=[{id:c.context.user_id,full_name:c.name,branch_id:c.context.profile_branch_id,active:true}];
  if(this.table==='vw_work_agenda_branches')rows=c.branches.map(b=>({...b,branch_id:b.id,branch_name:b.name}));
  if(this.table==='products')rows=[{id:'00000000-0000-0000-0000-000000000101',code:'PRACTICA',name:'Insumo de práctica',unit_of_measure:'caja',active:true}];
  if(this.table==='workflow_supply_catalog')rows=[{id:'00000000-0000-0000-0000-000000000102',product_id:'00000000-0000-0000-0000-000000000101',approved_name:'Insumo de práctica',unit_of_measure:'caja',reviewed_at:'2000-01-01T00:00:00Z'}];
  rows=rows.filter(r=>this.filters.every(f=>f(r)));rows=rows.slice(this.start,this.end===Infinity?undefined:this.end+1);return {data:this.one?(rows[0]||null):rows,error:null,count:rows.length};
 }).then(resolve,reject)}
}
const client={from:table=>new ReadOnlyQuery(table),rpc:async(name)=>name==='donor_search_page'?{data:{rows:[],total:0,offset:0},error:null}:['work_agenda_people','crm_branch_contacts','commercial_agenda'].includes(name)?{data:[],error:null}:denied(),functions:{invoke:async()=>denied()},storage:{from:()=>({upload:async()=>denied(),download:async()=>denied(),remove:async()=>denied(),createSignedUrl:async()=>denied(),getPublicUrl:()=>({data:{publicUrl:''}})})},auth:{onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),getUser:async()=>({data:{user:configuration?{id:configuration.context.user_id}:null},error:null}),getSession:async()=>({data:{session:null},error:null}),signOut:async()=>denied(),signInWithPassword:async()=>denied()}};
export function getSupabase(){return client;}
export async function testSupabaseConnection(){return {ok:false,code:'READ_ONLY_PREVIEW'};}
