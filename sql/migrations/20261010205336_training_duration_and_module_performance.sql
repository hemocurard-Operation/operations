-- HemoCura Training: duration capture and module-level performance.
grant update on public.training_quiz_attempts to authenticated;
create policy training_quiz_attempts_update_instructor on public.training_quiz_attempts
for update to authenticated
using (public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'))
with check (public.has_role('ADMIN') or public.has_role('CALIDAD') or public.has_role('GERENCIA_OPERATIVA'));

create or replace view public.vw_training_module_performance
with (security_invoker = true)
as
select role_code,task_code,task_label,count(*) as observations,
       count(*) filter(where result='COMPETENTE') as competent,
       count(*) filter(where result='REQUIERE_SUPERVISION') as requires_supervision,
       count(*) filter(where result='NO_COMPETENTE') as not_competent,
       round(100.0*count(*) filter(where result='COMPETENTE')/nullif(count(*),0),2) as pass_rate_pct
from public.training_practical_evidence
group by role_code,task_code,task_label;
revoke all on public.vw_training_module_performance from public,anon,authenticated;
grant select on public.vw_training_module_performance to authenticated;
