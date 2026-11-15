import {fixture} from '/hemocura-core/supabase.js';
import {mountUsers} from '/hemocura-core/users.js';
fixture.admin={caller_user_id:'super',rules:{},branches:[{id:'santiago',name:'Santiago',active:true}],roles:[{id:'rs',code:'SUPER_USUARIO',name:'Súper Usuario'},{id:'ri',code:'INVENTARIO',name:'Inventario'},{id:'rl',code:'LABORATORIO',name:'Laboratorio'}],users:[
{id:'super',full_name:'Súper Usuario · Demo',active:true,roles:[{role_id:'rs',role_code:'SUPER_USUARIO',role_name:'Súper Usuario'}]},
{id:'ana',full_name:'Ana · Inventario (demo)',active:true,roles:[{role_id:'ri',role_code:'INVENTARIO',role_name:'Inventario',branch_id:'santiago',branch_name:'Santiago'}]},
{id:'luis',full_name:'Luis · Laboratorio (demo)',active:true,roles:[{role_id:'rl',role_code:'LABORATORIO',role_name:'Laboratorio',branch_id:'santiago',branch_name:'Santiago'}]},
{id:'inactive',full_name:'Perfil inactivo (demo)',active:false,roles:[{role_id:'ri',role_code:'INVENTARIO'}]},
{id:'unassigned',full_name:'Sin roles (demo)',active:true,roles:[]}
]};
fixture.tables.app_module_catalog=[['inventory','BLOOD_INVENTORY_VIEW'],['requisitions','DISPATCH_VIEW'],['donors','DONORS_VIEW'],['screening','SCREENING_VIEW'],['users','ACCESS_ADMIN']].map(([route_key,permission_code])=>({route_key,permission_code,active:true}));
fixture.tables.app_permissions=fixture.tables.app_module_catalog.map(m=>({permission_code:m.permission_code,active:true}));
fixture.tables.role_module_access=fixture.tables.app_module_catalog.map((m,i)=>({role_id:i<2?'ri':'rl',route_key:m.route_key,enabled:true}));
fixture.tables.role_permissions=fixture.tables.role_module_access.map(s=>({role_id:s.role_id,permission_code:fixture.tables.app_module_catalog.find(m=>m.route_key===s.route_key).permission_code}));
fixture.reads=[];fixture.readHook=q=>{fixture.reads.push(q.table);return fixture.previewReadError?{data:null,error:{message:'Synthetic outage'}}:undefined};
window.fixture=fixture;await mountUsers(document.querySelector('#root'));window.previewReady=true;

fixture.rpcHandler=async(name,args)=>{
 if(name!=='admin_workspace_preview')return {data:null,error:{message:'Unexpected RPC'}};
 if(fixture.previewReadError||!fixture.admin.users.find(u=>u.id==='super')?.roles.some(r=>['ADMIN','SUPER_USUARIO'].includes(r.role_code)))return {data:null,error:{message:'Denied'}};
 return {data:{...fixture.admin,users:fixture.admin.users.filter(u=>!args.p_search||u.full_name.toLowerCase().includes(args.p_search.toLowerCase())),has_more:false,catalog:fixture.tables.app_module_catalog,settings:fixture.tables.role_module_access,permissions:fixture.tables.app_permissions,rolePermissions:fixture.tables.role_permissions},error:null};
};
