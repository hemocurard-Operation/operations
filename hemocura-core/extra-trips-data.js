import {getSupabase} from './supabase.js';
import {allPages} from './data-pages.js';
const sb=()=>getSupabase();
export const tripData={
 branches:()=>allPages('Sucursales',sb().from('vw_logistics_trip_branches').select('*').order('name').order('id')),
 trips:branch=>allPages('Viajes',sb().from('logistics_trips').select('*').eq('branch_id',branch).order('departure_at',{ascending:false}).order('id')),
 history:id=>allPages('Historial',sb().from('logistics_trip_history').select('*').eq('trip_id',id).order('changed_at',{ascending:false}).order('id')),
 async action(action,data){const {data:result,error}=await sb().rpc('logistics_trip_action',{p_action:action,p_data:data});if(error){if(/fetch|network|conexi/i.test(error.message||''))throw Error('No pudimos conectar. Tus datos siguen aquí; vuelve a intentar cuando tengas señal.');if(error.code==='42501')throw Error('No tienes acceso a esta acción. Pide ayuda a tu supervisor.');const technical=['22P02','22007','22008','23502','23514','22003'].includes(error.code);throw Error(technical?'Revisa los datos y las fechas antes de enviar.':error.message)}if(!result||typeof result!=='object')throw Error('No pudimos confirmar el registro. Revisa Mis viajes antes de volver a enviar.');return result;}
};
