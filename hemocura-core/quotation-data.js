import {getSupabase} from './supabase.js';
const fields='id,branch_id,supplier_id,requisition_id,code,quote_date,valid_until,currency,delivery_days,payment_terms,notes,lines,pdf_name,recorded_at,created_by';
async function result(query){const {data,error}=await query;if(error)throw Error(error.message);return data}
async function pages(table,columns,branch){const all=[];for(let n=0;;n+=100){const data=await result(getSupabase().from(table).select(columns).eq('branch_id',branch).order('recorded_at').order('id').range(n,n+99));all.push(...data);if(data.length<100)return all}}
export const quotationData={
 list:branch=>pages('supplier_quotations',fields,branch),
 decisions:branch=>pages('quotation_decisions','*',branch),
 save:q=>result(getSupabase().from('supplier_quotations').insert(q)),
 decide:q=>result(getSupabase().from('quotation_decisions').insert(q)),
 pdf:async id=>(await result(getSupabase().from('supplier_quotations').select('pdf_base64,pdf_name').eq('id',id).single()))
};
export async function readQuotationPDF(file){
 if(!file||file.size>5*1024*1024||file.size<5||!file.name.toLowerCase().endsWith('.pdf'))throw Error('Seleccione un PDF de hasta 5 MB.');
 const bytes=new Uint8Array(await file.arrayBuffer());if(new TextDecoder().decode(bytes.slice(0,5))!=='%PDF-')throw Error('El archivo no tiene una cabecera PDF válida.');
 let binary='';for(let i=0;i<bytes.length;i+=8192)binary+=String.fromCharCode(...bytes.subarray(i,i+8192));return btoa(binary);
}
