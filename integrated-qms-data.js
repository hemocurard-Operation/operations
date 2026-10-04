import { getSupabase } from './supabase.js';

export async function listInspections(filters={}){
  let q=getSupabase().from('vw_inspection_summary').select('*').order('inspection_date',{ascending:false}).limit(100);
  if(filters.branchId) q=q.eq('branch_id',filters.branchId);
  const {data,error}=await q;
  if(error) throw new Error(`Inspecciones: ${error.message}`);
  return data||[];
}

export async function createInspection(payload, findings=[]){
  const sb=getSupabase();
  const {data:inspection,error}=await sb.from('branch_inspections').insert(payload).select('*').single();
  if(error) throw new Error(`Crear inspección: ${error.message}`);
  if(findings.length){
    const rows=findings.map(x=>({...x,inspection_id:inspection.id}));
    const {error:fe}=await sb.from('inspection_findings').insert(rows);
    if(fe) throw new Error(`Hallazgos: ${fe.message}`);
  }
  return inspection;
}

export async function listRequisitions(filters={}){
  let q=getSupabase().from('requisitions').select('*').order('request_date',{ascending:false}).limit(100);
  if(filters.branchId) q=q.eq('requesting_branch_id',filters.branchId);
  const {data,error}=await q;
  if(error) throw new Error(`Requisiciones: ${error.message}`);
  return data||[];
}

export async function createRequisition(header, lines=[]){
  const sb=getSupabase();
  const {data:req,error}=await sb.from('requisitions').insert(header).select('*').single();
  if(error) throw new Error(`Crear requisición: ${error.message}`);
  if(lines.length){
    const {error:le}=await sb.from('requisition_lines').insert(lines.map(x=>({...x,requisition_id:req.id})));
    if(le) throw new Error(`Líneas de requisición: ${le.message}`);
  }
  return req;
}

export async function listDocumentRegister(){
  const {data,error}=await getSupabase().from('document_register').select('*').order('document_code');
  if(error) throw new Error(`Registro documental: ${error.message}`);
  return data||[];
}

export async function listRisks(){
  const {data,error}=await getSupabase().from('risk_register').select('*').order('inherent_score',{ascending:false}).limit(200);
  if(error) throw new Error(`Riesgos: ${error.message}`);
  return data||[];
}

export async function createRisk(payload){
  const {data,error}=await getSupabase().from('risk_register').insert(payload).select('*').single();
  if(error) throw new Error(`Crear riesgo: ${error.message}`);
  return data;
}

export async function listOpenQmsActions(){
  const {data,error}=await getSupabase().from('vw_qms_open_actions').select('*').order('due_date',{ascending:true,nullsFirst:false}).limit(200);
  if(error) throw new Error(`Acciones SGC: ${error.message}`);
  return data||[];
}
