import {getSupabase} from './supabase.js';
async function all(label,make){const out=[];for(let n=0;;n+=500){const {data,error}=await make().range(n,n+499);if(error)throw Error(label+': '+error.message);out.push(...(data||[]));if((data||[]).length<500)return out}}
async function save(label,q){const {data,error}=await q.select('*').single();if(error){if(error.code==='PGRST116')throw Error('El registro cambió o no está disponible. Actualice y vuelva a intentar.');if(error.code==='23505'&&label==='Pedido')throw Error('Ya existe un pedido con esa referencia en la sucursal.');throw Error(label+': '+error.message)}if(!data)throw Error('El registro cambió. Actualice y vuelva a intentar.');return data}
export const coordinationData={
 currentDonor:async id=>{const {data,error}=await getSupabase().from('vw_donor_coordination').select('*').eq('id',id).single();if(error||!data)throw Error('No se pudo verificar el estado actual del donante. Actualice la ficha.');return data},
 orders:()=>all('Pedidos',()=>getSupabase().from('operations_orders').select('*').order('due_at').order('id')),
 saveOrder:(id,revision,p)=>save('Pedido',id?getSupabase().from('operations_orders').update(p).eq('id',id).eq('revision',revision):getSupabase().from('operations_orders').insert(p)),
 calendar:(start,end)=>all('Citas',()=>getSupabase().from('vw_donor_appointment_agenda').select('*').gte('starts_at',start).lt('starts_at',end).order('starts_at').order('id')),
 capacity:()=>all('Cupos',()=>getSupabase().from('donor_agenda_capacity').select('*').order('branch_id')),
 saveCapacity:p=>save('Cupos',getSupabase().from('donor_agenda_capacity').upsert(p,{onConflict:'branch_id'}))
};
