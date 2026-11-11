import {fixture} from '/hemocura-core/supabase.js';import {mountImprovementAgents} from '/hemocura-core/improvement-agents.js';
fixture.permissions=['ORCHESTRATION_VIEW','WORK_AGENDA_VIEW','WORK_AGENDA_WRITE','SUPPLY_VIEW'];fixture.context={user_id:'u1',roles:['SUPER_USUARIO']};
fixture.tables.vw_work_agenda_branches=[{id:'b1',name:'Santiago · Demo'},{id:'b2',name:'Otra sucursal · Demo'}];fixture.tables.vw_my_work_areas=[{code:'OPERACIONES',name:'Operaciones'},{code:'CALIDAD',name:'Calidad'}];fixture.tables.work_tasks=[];
const requests=new Map();fixture.rpcHandler=async(name,args)=>{
 if(name==='work_agenda_people'){if(fixture.delayPeople&&args.p_area==='OPERACIONES')return new Promise(resolve=>window.finishPeople=resolve);return {data:[{id:args.p_area==='OPERACIONES'?'u1':'u2',full_name:args.p_area==='OPERACIONES'?'Operador de demostración':'Calidad de demostración'}],error:null}}
 if(name!=='work_task_action')return {data:null,error:null};const p=args.p_data;
 if(fixture.rejectSave)return {data:null,error:{message:'Responsable no autorizado'}};
 if(requests.has(p.request_id))return {data:{ids:requests.get(p.request_id),already_created:true},error:null};
 const id=crypto.randomUUID();fixture.tables.work_tasks.push({...p,id,status:'PENDIENTE',owner_name:p.owner_id==='u1'?'Operador de demostración':'Calidad de demostración'});requests.set(p.request_id,[id]);
 if(fixture.loseResponse){fixture.loseResponse=false;return {data:null,error:{message:'Synthetic lost response'}}}return {data:{ids:[id]},error:null};
};
const state={queue:[{priority_key:'stock1',branch_id:'b1',domain:'ABASTECIMIENTO',priority:'ALTA',title:'Revisar cobertura · Demostración',description:'Cobertura baja para revisión.',recommended_action:'Verificar conteo y registrar evidencia.'},{priority_key:'global1',branch_id:null,domain:'PROVEEDOR',priority:'ALTA',title:'Continuidad de proveedor · Demo',recommended_action:'Revisar continuidad.'}],resilience:[{branch_id:'b1',branch_name:'Santiago · Demo'}],dataQuality:[]};window.fixture=fixture;await mountImprovementAgents(document.querySelector('#root'),{state,reload:async()=>state});window.ready=true;
