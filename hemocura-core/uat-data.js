import {getSupabase} from './supabase.js';
const sb=()=>getSupabase();
async function many(label,q){const {data,error}=await q;if(error)throw new Error(`${label}: ${error.message}`);return data||[]}
async function call(name,args){const {data,error}=await sb().rpc(name,args);if(error)throw new Error(error.message);return data}
export const uatData={
 runs:()=>many('UAT',sb().from('uat_test_runs').select('*').order('started_at',{ascending:false})),
 cases:()=>many('Casos',sb().from('uat_test_cases').select('*').eq('active',true).order('test_code')),
 results:id=>many('Resultados',sb().from('uat_test_results').select('*').eq('run_id',id)),
 start:(code,version)=>call('hc_uat_start_run',{p_run_code:code,p_release_version:version}),
 record:(run,caseId,data)=>call('hc_uat_record_result',{p_run_id:run,p_test_case_id:caseId,p_result:data.result,p_actual_result:data.actual,p_evidence_reference:data.evidence}),
 complete:(run,summary)=>call('hc_uat_complete_run',{p_run_id:run,p_summary:summary})
};
