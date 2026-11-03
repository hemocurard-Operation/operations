import {allPages} from './data-pages.js';
import {getSupabase} from './supabase.js';
const sb=()=>getSupabase();
const STATUSES=['PLANIFICADO','EN_TRANSITO','RECIBIDO','CUARENTENA','CANCELADO'];
export const transportStatuses=()=>[...STATUSES];
export const transportData={
  list:(filters={})=>{
    let q=sb().from('transport_events').select('*').order('departure_at',{ascending:false,nullsFirst:false});
    if(filters.branchId)q=q.eq('branch_id',filters.branchId);
    if(filters.status)q=q.eq('status',filters.status);
    if(filters.from)q=q.gte('departure_at',filters.from);
    if(filters.to)q=q.lte('departure_at',filters.to+'T23:59:59');
    return allPages('Traslados',q);
  },
  get:async id=>{const {data,error}=await sb().from('transport_events').select('*').eq('id',id).single();if(error)throw new Error(error.message);return data},
  readings:transportId=>allPages('Lecturas de temperatura',sb().from('transport_temperature_readings').select('*').eq('transport_id',transportId).order('reading_time',{ascending:false})),
  create:async payload=>{const {data,error}=await sb().from('transport_events').insert(payload).select('*').single();if(error)throw new Error(error.message);return data},
  updateStatus:async(id,status,extra={})=>{
    if(!STATUSES.includes(status))throw new Error('Estado de traslado no válido');
    const patch={status,...extra};
    const {data,error}=await sb().from('transport_events').update(patch).eq('id',id).select('*').single();
    if(error)throw new Error(error.message);
    return data;
  },
  addTemperatureReading:async(transportId,payload)=>{
    const {data,error}=await sb().from('transport_temperature_readings').insert({...payload,transport_id:transportId}).select('*').single();
    if(error)throw new Error(error.message);
    return data;
  }
};
