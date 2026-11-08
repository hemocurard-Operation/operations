import {getSupabase} from './supabase.js';
import {loadAccess,filterRoutes} from './access-control.js';
import {routeList} from './router.js';
import {agentSourceReference} from './agent-followup-domain.js';
import {activeTask,overdue} from './area-agenda-domain.js';
export async function canReadAgentFollowups(){const [a,routes]=await Promise.all([loadAccess(),filterRoutes(routeList())]);return a.permissions.has('WORK_AGENDA_VIEW')&&routes.some(([key])=>key==='areaagenda')}
export function referenceBatches(findings){
 const refs=[...new Set(findings.map(agentSourceReference))],batches=[];let batch=[],size=0;
 for(const ref of refs){const bytes=encodeURIComponent(JSON.stringify(ref)).length+8;if(bytes>3500)throw Error('La referencia del hallazgo supera el límite de consulta.');if(batch.length>=25||size+bytes>3500){batches.push(batch);batch=[];size=0}batch.push(ref);size+=bytes}if(batch.length)batches.push(batch);return batches;
}
// The pinned SDK adds enclosing quotes to IN values but does not escape their inner quotes.
export const postgrestReferences=refs=>refs.map(ref=>ref.replace(/\\/g,'\\\\').replace(/"/g,'\\"'));
export function followupsForFinding(tasks,finding){const reference=agentSourceReference(finding);return tasks.filter(t=>t.source_reference===reference&&(!finding.branch_id||t.branch_id===finding.branch_id))}
export function followupSummary(tasks,now=Date.now()){return {total:tasks.length,active:tasks.filter(activeTask).length,overdue:tasks.filter(t=>overdue(t,now)).length,review:tasks.filter(t=>t.status==='EN_REVISION').length,completed:tasks.filter(t=>t.status==='COMPLETADA').length}}
export async function loadAgentFollowups(findings){
 if(!await canReadAgentFollowups())throw Error('Agenda por área no habilitada.');
 const tasks=[],seen=new Set(),branches=[...new Set(findings.map(f=>f.branch_id))];let partial=false;const limit=2000;
 for(const refs of referenceBatches(findings)){
  for(let offset=0;;offset+=500){
   const count=Math.min(500,limit-tasks.length);if(count<=0){partial=true;break}
   let query=getSupabase().from('work_tasks').select('id,branch_id,source_reference,title,owner_name,due_at,status,created_at').eq('source_route','orchestration').in('source_reference',postgrestReferences(refs));
   if(branches.length===1&&branches[0])query=query.eq('branch_id',branches[0]);
   const {data,error}=await query.order('created_at',{ascending:false}).order('id').range(offset,offset+count-1);
   if(error)throw Error('No se pudo consultar el seguimiento.');if(!Array.isArray(data))throw Error('Respuesta de seguimiento no disponible.');
   for(const task of data)if(!seen.has(task.id)){seen.add(task.id);tasks.push(task)}
   if(tasks.length>=limit){partial=true;break}if(data.length<count)break;
  }
  if(partial)break;
 }
 return {tasks,partial,checkedAt:new Date().toLocaleString('es-DO')};
}
