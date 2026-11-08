export const IMPROVEMENT_AGENTS=[
 {id:'inventory',name:'Abastecimiento y merma',domains:['ABASTECIMIENTO','MERMA'],route:'supply',mission:'Priorizar cobertura de stock y pérdidas evitables.',rule:'Revisa las señales de abastecimiento y merma de la cola de orquestación.'},
 {id:'suppliers',name:'Proveedores',domains:['PROVEEDOR'],route:'suppliers',mission:'Detectar riesgos de continuidad y evaluaciones pendientes.',rule:'Revisa los proveedores que la cola clasifica con riesgo.'},
 {id:'finance',name:'Cobranza',domains:['FINANZAS'],route:'collections',mission:'Priorizar saldos vencidos para revisión y contacto.',rule:'Revisa las señales de cobranza y su fecha objetivo.'},
 {id:'quality',name:'Calidad y cumplimiento',domains:['CALIDAD','COMPLIANCE'],route:'actions',mission:'Señalar acciones próximas a vencer o que requieren evidencia.',rule:'Revisa las señales de CAPA y cumplimiento; no cierra ni aprueba acciones.'},
 {id:'operations',name:'Servicios y coordinación',domains:['RESILIENCIA','RED_MEDICA'],route:'decisioncenter',mission:'Ordenar los riesgos de sucursal y oportunidades de coordinación.',rule:'Revisa resiliencia, red médica y las señales de otros dominios autorizados.'},
 {id:'data',name:'Calidad de información',domains:[],route:'orchestration',mission:'Localizar información incompleta antes de decidir.',rule:'Señala sucursales con calidad de datos inferior a 80/100 o sin score evaluable.'}
];
const priorities={CRITICA:0,ALTA:1,MEDIA:2,BAJA:3};
export function evaluateImprovementAgents(state){
 const results=IMPROVEMENT_AGENTS.map(agent=>({...agent,findings:[]})),seen=new Set();
 const owner=new Map(results.flatMap(a=>a.domains.map(d=>[d,a])));
 for(const row of state.queue||[]){
  if(!row.priority_key||seen.has(row.priority_key))continue;seen.add(row.priority_key);
  const agent=owner.get(row.domain)||results.find(a=>a.id==='operations');
  agent.findings.push({...row,key:String(row.priority_key),source:'vw_orchestration_priority_queue',priority:row.priority in priorities?row.priority:'MEDIA'});
 }
 const dataAgent=results.find(a=>a.id==='data');
 for(const row of state.dataQuality||[]){
  if(!row.branch_id)continue;
  const raw=row.data_readiness_score==null?NaN:Number(row.data_readiness_score);
  const score=Number.isFinite(raw)&&raw>=0&&raw<=100?raw:NaN;
  if(Number.isFinite(score)&&score>=80)continue;
  const key='DATA:'+row.branch_id;if(seen.has(key))continue;seen.add(key);
  dataAgent.findings.push({key,branch_id:row.branch_id,branch_name:row.branch_name,domain:'DATOS',source:'vw_data_quality_readiness',priority:Number.isFinite(score)&&score<50?'ALTA':'MEDIA',title:Number.isFinite(score)?'Calidad de información inferior al objetivo':'Calidad de información no evaluable',description:Number.isFinite(score)?`Score: ${score}/100. Ventas sin cliente: ${row.sales_without_customer??'N/D'}; ventas sin demanda: ${row.sales_without_demand??'N/D'}; despachos sin demanda: ${row.dispatches_without_demand??'N/D'}.`:'La fuente no devolvió un score válido para esta sucursal.',recommended_action:'Revisar los registros de origen y completar los vínculos faltantes antes de decidir.'});
 }
 for(const agent of results)agent.findings.sort((a,b)=>(priorities[a.priority]-priorities[b.priority])||String(a.due_date||'9999').localeCompare(String(b.due_date||'9999'))||a.key.localeCompare(b.key));
 return results;
}
