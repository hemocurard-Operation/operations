import {getSupabase} from './supabase.js';
const metadata='id,report_id,content_sha256,file_name,mime_type,reviewed_inventory,recorded_at';
async function result(q){const {data,error}=await q;if(error)throw Error(error.message);return data}
export const dailyPhotoData={
 list:id=>result(getSupabase().from('daily_report_photos').select(metadata).eq('report_id',id).order('recorded_at')),
 image:id=>result(getSupabase().from('daily_report_photos').select('image_base64,mime_type,content_sha256').eq('id',id).single()),
 save:async(report,pending)=>{
  let binary='';for(let i=0;i<pending.bytes.length;i+=8192)binary+=String.fromCharCode(...pending.bytes.subarray(i,i+8192));
  const {error}=await getSupabase().from('daily_report_photos').insert({report_id:report,content_sha256:pending.hash,file_name:pending.file.name.slice(0,255),mime_type:pending.file.type,image_base64:btoa(binary),reviewed_inventory:pending.values});
  if(error?.code==='23505'){const rows=await dailyPhotoData.list(report);if(rows.some(r=>r.content_sha256===pending.hash))return;}
  if(error)throw Error(error.message);
 }
};
