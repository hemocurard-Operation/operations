import {getSupabase} from './supabase.js';const sb=()=>getSupabase();
async function call(name,args){const {data,error}=await sb().rpc(name,args);if(error)throw new Error(error.message);return data}
export const finalReleaseData={
 readiness:version=>call('hc_release_readiness_v1',{p_version:version}),
 signoffs:async(version='1.0.0')=>{const {data,error}=await sb().from('release_signoffs').select('*').eq('release_version',version);if(error)throw new Error(error.message);return data||[]},
 sign:(version,data)=>call('hc_v044_release_signoff',{p_release_version:version,p_type:data.type,p_decision:data.decision,p_comment:data.comment})
};
