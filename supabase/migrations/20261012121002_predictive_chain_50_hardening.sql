-- HemoCura Predictive Chain 50 hardening (live migration 20261012121002)
create or replace view public.vw_predictive_action_queue with (security_invoker=true) as
select c.* from public.vw_predictive_action_candidates c
where not exists (
  select 1 from public.predictive_decision_reviews r
  where r.candidate_key=c.candidate_key
    and (r.decision in ('ACEPTAR','DESCARTAR') or (r.decision='DIFERIR' and coalesce(r.review_due_date,current_date+1)>current_date))
);
grant select on public.vw_predictive_action_queue to authenticated;
revoke all on public.vw_predictive_action_queue from anon;
create index if not exists idx_predictive_review_source on public.predictive_decision_reviews(source_table,source_id);
create index if not exists idx_predictive_review_due on public.predictive_decision_reviews(review_due_date) where decision='DIFERIR';
