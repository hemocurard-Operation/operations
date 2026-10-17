import {allPages} from './data-pages.js';
import { getSupabase } from './supabase.js';
const sb=()=>getSupabase();
async function many(label,p){return allPages(label,p)}
async function one(label,p){const {data,error}=await p;if(error)throw new Error(`${label}: ${error.message}`);return data}

export const analyticalQcData={
  branches:()=>many('Sucursales',sb().from('branches').select('id,code,name').eq('active',true).order('name').order('id')),
  equipment:()=>many('Equipos',sb().from('lab_equipment').select('id,equipment_code,equipment_type,branch_id,status').neq('status','RETIRADO').order('equipment_code').order('id')),
  methods:()=>many('Métodos',sb().from('lab_methods').select('*').order('method_code').order('id')),
  plans:()=>many('Planes IQC',sb().from('iqc_plans').select('*').eq('active',true).order('plan_code').order('id')),
  iqcAlerts:()=>many('Alertas IQC',sb().from('vw_iqc_alerts').select('*').order('run_time',{ascending:false})),
  eqaAlerts:()=>many('Alertas EQA',sb().from('vw_eqa_alerts').select('*').order('due_date',{ascending:true})),
  deviations:()=>many('Desviaciones',sb().from('qc_deviations').select('*').order('opened_at',{ascending:false}).order('id')),
  eqaPrograms:()=>many('Programas EQA',sb().from('eqa_programs').select('*').eq('active',true).order('program_name').order('id')),
  eqaEvents:()=>many('Eventos EQA',sb().from('eqa_events').select('*').order('due_date',{ascending:true,nullsFirst:false}).order('id')),
  summary:()=>one('Resumen analítico',sb().from('vw_analytical_quality_summary').select('*').single()),
  createMethod:async p=>{const {data,error}=await sb().from('lab_methods').insert(p).select('*').single();if(error)throw new Error(`Método: ${error.message}`);return data},
  createPlan:async p=>{const {data,error}=await sb().from('iqc_plans').insert(p).select('*').single();if(error)throw new Error(`Plan IQC: ${error.message}`);return data},
  addIqc:async p=>{const {data,error}=await sb().from('iqc_results').insert(p).select('*').single();if(error)throw new Error(`Resultado IQC: ${error.message}`);return data},
  createEqaProgram:async p=>{const {data,error}=await sb().from('eqa_programs').insert(p).select('*').single();if(error)throw new Error(`Programa EQA: ${error.message}`);return data},
  createEqaEvent:async p=>{const {data,error}=await sb().from('eqa_events').insert(p).select('*').single();if(error)throw new Error(`Evento EQA: ${error.message}`);return data}
};
