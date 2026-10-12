-- HemoCura Predictive Chain 50 network effectiveness (live migration 20261012121216)
create or replace view public.vw_referrer_effectiveness_score with (security_invoker=true) as
select referrer_id,branch_id,referrer_code,full_name,specialty,organization,status,referrals,converted_referrals,estimated_units,conversion_pct,last_referral_date,
       greatest(0,least(100,least(coalesce(referrals,0)::int*5,30)+least(coalesce(converted_referrals,0)::int*10,40)+case when coalesce(conversion_pct,0)>=70 then 20 when coalesce(conversion_pct,0)>=40 then 10 else 0 end+case when last_referral_date>=current_date-30 then 10 else 0 end))::int effectiveness_score,
       case when coalesce(referrals,0)=0 then 'SIN_ACTIVIDAD' when last_referral_date<current_date-60 then 'INACTIVO' when coalesce(conversion_pct,0)<30 and coalesce(referrals,0)>=3 then 'BAJA_CONVERSION' when coalesce(conversion_pct,0)>=70 then 'ALTO_DESEMPENO' else 'DESARROLLO' end network_signal
from public.vw_medical_network_performance;
grant select on public.vw_referrer_effectiveness_score to authenticated; revoke all on public.vw_referrer_effectiveness_score from anon;
create or replace view public.vw_predictive_network_candidates with (security_invoker=true) as
select 'NETWORK:'||referrer_id::text candidate_key,branch_id,'RED_MEDICA' domain,'medical_referrers' source_table,referrer_id source_id,case when network_signal='INACTIVO' then 'ALTA' else 'MEDIA' end priority,'Activar referidor: '||full_name title,'Señal: '||network_signal||'; referencias: '||referrals::text||'; conversión: '||coalesce(conversion_pct,0)::text||'%' description,current_date+7 due_date,case when network_signal='INACTIVO' then 'Programar contacto y validar causas de inactividad.' else 'Revisar calidad de referencias, SLA y propuesta de valor.' end recommended_action
from public.vw_referrer_effectiveness_score where network_signal in ('INACTIVO','BAJA_CONVERSION');
grant select on public.vw_predictive_network_candidates to authenticated; revoke all on public.vw_predictive_network_candidates from anon;
create or replace view public.vw_predictive_action_queue with (security_invoker=true) as
with all_candidates as (select * from public.vw_predictive_action_candidates union all select * from public.vw_predictive_network_candidates)
select c.* from all_candidates c where not exists (select 1 from public.predictive_decision_reviews r where r.candidate_key=c.candidate_key and (r.decision in ('ACEPTAR','DESCARTAR') or (r.decision='DIFERIR' and coalesce(r.review_due_date,current_date+1)>current_date)));
grant select on public.vw_predictive_action_queue to authenticated; revoke all on public.vw_predictive_action_queue from anon;
