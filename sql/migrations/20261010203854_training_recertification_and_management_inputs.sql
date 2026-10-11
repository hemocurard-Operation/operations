-- HemoCura Training Release 1.0 recertification and management inputs
-- Applied to production via Supabase migration history as training_recertification_and_management_inputs.

alter table public.training_certificates drop constraint if exists training_certificates_participation_id_key;
alter table public.training_certificates add constraint training_certificates_assessment_id_key unique (assessment_id);

create or replace view public.vw_training_question_performance
with (security_invoker = true)
as
select q.role_code,
       item->>'question' as question,
       count(*) as responses,
       count(*) filter (where coalesce((item->>'correct')::boolean,false)) as correct_responses,
       round(100.0 * count(*) filter (where not coalesce((item->>'correct')::boolean,false)) / nullif(count(*),0),2) as error_rate_pct
from public.training_quiz_attempts q
cross join lateral jsonb_array_elements(coalesce(q.answers->'items','[]'::jsonb)) item
group by q.role_code,item->>'question';

create or replace view public.vw_training_management_review_input
with (security_invoker = true)
as
select
  (select count(distinct user_id) from public.training_quiz_attempts) as participants_evaluated,
  (select round(avg(score),2) from public.training_quiz_attempts) as avg_score,
  (select round(100.0 * count(*) filter (where passed) / nullif(count(*),0),2) from public.training_quiz_attempts) as pass_rate_pct,
  (select count(*) from public.vw_training_recertification_alerts where severity='ALTA') as high_recertification_alerts,
  (select count(*) from public.vw_training_certificate_status where effective_status='VIGENTE') as active_certificates,
  (select count(*) from public.vw_training_certificate_status where effective_status in ('VENCIDO','REVOCADO','SUSPENDIDO')) as inactive_certificates,
  (select count(*) from public.training_authorizations where status='ACTIVE' and (valid_until is null or valid_until >= current_date)) as active_authorizations,
  (select max(version_code) from public.training_content_versions where status='APPROVED') as approved_content_version;

revoke all on public.vw_training_question_performance from public, anon, authenticated;
revoke all on public.vw_training_management_review_input from public, anon, authenticated;
grant select on public.vw_training_question_performance to authenticated;
grant select on public.vw_training_management_review_input to authenticated;
