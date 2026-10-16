// Browser unit fixture. No remote requests; this does not emulate or prove RLS.
export const fixture={tables:{},writes:[],permissions:[],session:null,error:null,context:null,admin:null,adminError:null,adminCalls:[],rpcCalls:[],rpcHandler:null,user:undefined,writeGate:null,readHook:null};
class Query {
  constructor(table){this.table=table;this.filters=[];this.conditions=[];this.payload=null;this.kind='select';this.one=false;}
  select(){return this} order(){return this} limit(){return this}
  range(start,end){this.offset=start;this.end=end;return this}
  gte(key,value){this.filters.push(row=>row[key]>=value);return this}
  lte(key,value){this.filters.push(row=>row[key]<=value);return this}
  lt(key,value){this.filters.push(row=>row[key]<value);return this}
  or(expression){const terms=expression.split(',');this.filters.push(row=>terms.some(term=>{const [key,op,...rest]=term.split('.');const value=rest.join('.');return op==='eq'?row[key]===value:op==='is'&&value==='null'?row[key]==null:false}));return this}
  eq(key,value){this.filters.push(row=>row[key]===value);this.conditions.push([key,value]);return this}
  not(key,operator,values){this.filters.push(row=>!values.slice(1,-1).split(',').includes(row[key]));return this}
  in(key,values){this.filters.push(row=>values.includes(row[key]));return this}
  single(){this.one=true;return this} maybeSingle(){this.one=true;return this}
  insert(payload){this.kind='insert';this.payload=payload;return this}
  upsert(payload){this.kind='upsert';this.payload=payload;return this}
  update(payload){this.kind='update';this.payload=payload;return this}
  then(resolve,reject){return Promise.resolve().then(async()=>{
    if(fixture.error)return{data:null,error:fixture.error};
    if(this.kind==='select'&&fixture.readHook){const reply=await fixture.readHook(this);if(reply!==undefined)return reply;}
    if(this.kind!=='select'&&fixture.writeGate)await fixture.writeGate;
    let rows=this.table==='vw_my_access'?fixture.permissions.map(permission_code=>({permission_code})):fixture.tables[this.table]||[];
    if(this.table==='vw_donor_coordination')rows=(fixture.tables.vw_donor_next_donation||fixture.tables.donors||[]).map(d=>{const c=(fixture.tables.donor_contacts||[]).filter(c=>c.donor_id===d.id).sort((a,b)=>String(b.contacted_at).localeCompare(String(a.contacted_at)))[0],v=(fixture.tables.donor_visits||[]).find(v=>v.donor_id===d.id&&['POR_CONFIRMAR','CONFIRMADA'].includes(v.status));return{...d,last_contact_id:c?.id,last_contact_at:c?.contacted_at,last_contact_outcome:c?.outcome,next_contact_at:c?.next_contact_at,active_visit_id:v?.id,visit_starts_at:v?.starts_at,visit_branch_id:v?.branch_id,visit_status:v?.status}});
    if(this.table==='vw_donor_appointment_agenda')rows=(fixture.tables.donor_visits||[]).map(v=>({...((fixture.tables.donors||[]).find(d=>d.id===v.donor_id)||{}),...v}));
    if(this.table==='vw_my_security_context')rows=[fixture.context||{roles:['FINANZAS'],email:'fixture@example.invalid'}];
    rows=rows.filter(row=>this.filters.every(test=>test(row)));if(this.offset!==undefined)rows=rows.slice(this.offset,this.end+1);
    if(this.kind==='insert'){rows=[{id:crypto.randomUUID(),...(this.table==='operations_orders'?{status:'PENDIENTE',revision:1}:{}),...this.payload}];fixture.tables[this.table]??=[];fixture.tables[this.table].push(...rows);}
    if(this.kind==='update')rows.forEach(row=>Object.assign(row,this.payload,this.table==='operations_orders'?{revision:(row.revision||1)+1}:{}));
    if(this.kind==='upsert'){fixture.tables[this.table]??=[];let existing=fixture.tables[this.table].find(r=>r.branch_id===this.payload.branch_id);if(existing)Object.assign(existing,this.payload);else{existing={...this.payload};fixture.tables[this.table].push(existing)}rows=[existing]}
    if(this.kind!=='select')fixture.writes.push({table:this.table,kind:this.kind,payload:this.payload});
    return{data:this.one?rows[0]||null:rows,error:null};
  }).then(resolve,reject)}
}
const client={functions:{invoke:async(name,{body})=>{
 fixture.adminCalls.push({name,body});
 if(fixture.adminError)return{data:null,error:fixture.adminError};
 if(name!=='admin-users')return{data:null,error:{message:'Unsupported fixture function'}};
 if(body.action==='remove_role'){
  const user=fixture.admin.users.find(user=>user.id===body.user_id);
  const before=user.roles.length;
  user.roles=user.roles.filter(role=>role.role_id!==body.role_id||!body.branch_ids.includes(role.branch_id));
  return{data:{ok:true,removed_assignments:before-user.roles.length},error:null};
 }
 return{data:structuredClone(fixture.admin),error:null};
}},from:table=>new Query(table),rpc:async(name,args)=>{fixture.rpcCalls.push({name,args});return fixture.rpcHandler?fixture.rpcHandler(name,args):{data:null,error:null}},auth:{
  getUser:async()=>({data:{user:fixture.user===undefined?{id:'20000000-0000-0000-0000-000000000001'}:fixture.user},error:fixture.error}),
  getSession:async()=>({data:{session:fixture.session},error:fixture.error}),
  signInWithPassword:async()=>({data:{session:fixture.session},error:fixture.error}),
  signOut:async()=>{fixture.session=null;return{error:fixture.error}},
  onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})
}};
export function getSupabase(){return client}
export async function testSupabaseConnection(){return {ok:true}}
