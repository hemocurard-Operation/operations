import {getSupabase} from './supabase.js';
import {qualityRows} from './quality-data.js';
export const managementData={
 objectives:()=>qualityRows('Objetivos',()=>getSupabase().from('quality_objectives').select('*').order('id')),
 reviews:()=>qualityRows('Revisiones',()=>getSupabase().from('management_reviews').select('*').order('review_date',{ascending:false}).order('id')),
 commitments:()=>qualityRows('Compromisos',()=>getSupabase().from('management_review_actions').select('*').order('id')),
 inputs:async()=>{const{data,error}=await getSupabase().from('vw_management_review_inputs').select('*').single();if(error)throw Error(error.message);return data},
 action:async(action,data)=>{const{data:result,error}=await getSupabase().rpc('qms_management_action',{p_action:action,p_data:data});if(error)throw Error(error.message);return result}
};
