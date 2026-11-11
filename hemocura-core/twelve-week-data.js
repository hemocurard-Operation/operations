import {getSupabase} from './supabase.js';
async function call(name,args={}){const {data,error}=await getSupabase().rpc(name,args);if(error)throw Error(error.message);return data}
export const cycleData={
 context:()=>call('twelve_week_context'),
 load:(branch,area)=>call('twelve_week_catalog',{p_branch:branch,p_area:area}),
 people:(branch,area)=>call('work_agenda_people',{p_branch:branch,p_area:area}),
 action:(branch,area,action,data,request)=>call('twelve_week_action',{p_branch:branch,p_area:area,p_action:action,p_data:data,p_request:request})
};
