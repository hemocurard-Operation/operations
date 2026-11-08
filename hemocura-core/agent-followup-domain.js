import {rdTimestamp} from './workflow-domain.js';
export function agentSourceReference(finding){
 if(!finding||typeof finding.key!=='string'||!finding.key||finding.key.length>2048||!['vw_orchestration_priority_queue','vw_data_quality_readiness'].includes(finding.source))throw Error('Hallazgo de agente no válido.');
 return 'AGENT:'+JSON.stringify([finding.source,finding.key]);
}
export function agentFollowupPayload(finding,form,requestId){
 const reference=agentSourceReference(finding),title=String(form.title||'').trim(),description=String(form.description||'').trim();
 if(!title||title.length>250||description.length>6000)throw Error('Revise el título (hasta 250 caracteres) y las instrucciones (hasta 6000).');
 if(!form.branch_id||finding.branch_id&&form.branch_id!==finding.branch_id)throw Error('La tarea debe conservar la sucursal del hallazgo.');
 if(!form.area_code||!form.owner_id)throw Error('Seleccione el área y un responsable habilitado.');
 if(!['NORMAL','ALTA','CRITICA'].includes(form.priority))throw Error('Prioridad inválida.');
 if(!requestId)throw Error('Falta el identificador de la solicitud.');
 const due=rdTimestamp(form.due_at);
 return {branch_id:form.branch_id,area_code:form.area_code,owner_id:form.owner_id,title,description:description+'\n\nOrigen del agente: '+reference,priority:form.priority,due_at:due,requires_review:true,source_route:'orchestration',source_reference:reference,request_id:requestId,occurrences:1,interval_days:1,checklist:[]};
}
