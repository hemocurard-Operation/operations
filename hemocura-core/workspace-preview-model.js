import {ROUTE_PERMISSION} from './access-control.js';
import {routeList} from './router.js';
import {workspaceTasks} from './my-work.js';

// Navigation projection only. Never substitutes an identity or authorizes data access.
export function workspacePreview(user,{catalog,settings,permissions,rolePermissions}){
 const roles=user.roles||[],ids=new Set(roles.map(r=>r.role_id));
 const superUser=roles.some(r=>r.role_code==='SUPER_USUARIO');
 const active=user.active===true;
 const assigned=new Set(rolePermissions.filter(p=>ids.has(p.role_id)).map(p=>p.permission_code));
 const granted=new Set(permissions.filter(p=>active&&p.active===true&&(superUser||(p.permission_code!=='ACCESS_ADMIN'&&assigned.has(p.permission_code)))).map(p=>p.permission_code));
 const enabled=new Set(settings.filter(s=>ids.has(s.role_id)&&s.enabled===true).map(s=>s.route_key));
 const modules=new Map(catalog.map(m=>[m.route_key,m]));
 const routes=routeList().filter(([key])=>{const m=modules.get(key);return active&&m?.active===true&&granted.has(m.permission_code)&&granted.has(ROUTE_PERMISSION[key])&&(superUser||enabled.has(key))});
 return {routes,permissions:granted,tasks:workspaceTasks(routes,{roles:roles.map(r=>r.role_code)},granted),active,superUser};
}
