import { getSupabase } from './supabase.js';
import {qualityRows} from './quality-data.js';
const sb=()=>getSupabase();

async function many(label,p){
  const {data,error}=await p;
  if(error) throw new Error(`${label}: ${error.message}`);
  return data||[];
}
async function one(label,p){
  const {data,error}=await p;
  if(error) throw new Error(`${label}: ${error.message}`);
  return data;
}

export const qmsGovernanceData={
  documents:()=>qualityRows('Documentos',()=>sb().from('vw_document_control_status').select('*').order('id')),
  capas:()=>qualityRows('CAPA',()=>sb().from('vw_capa_control_status').select('*').order('id')),
  summary:()=>one('Resumen QMS',sb().from('vw_qms_governance_summary').select('*').single()),

  requestDocumentApproval:async(documentId,reason)=>{
    const {data,error}=await sb().rpc('request_document_approval',{p_document_id:documentId,p_reason:reason});
    if(error) throw new Error(`Aprobación documental: ${error.message}`);
    return data;
  },

  requestCapaClose:async(capaId,reason)=>{
    const {data,error}=await sb().rpc('request_capa_close',{p_capa_id:capaId,p_reason:reason});
    if(error) throw new Error(`Cierre CAPA: ${error.message}`);
    return data;
  }
};
