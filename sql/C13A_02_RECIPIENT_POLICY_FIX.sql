-- =====================================================================
-- HemoCura · C13-A2 · RECIPIENT POLICY FIX
-- Ajuste preventivo del candidato C13-A antes de aplicación.
-- recipient_issues depende de dispatch_unit_allocations, cuya policy exige
-- DISPATCH_VIEW; por coherencia la lectura de recipient_issues también.
-- =====================================================================

begin;

drop policy if exists c13a_recipient_issues_select on public.recipient_issues;

create policy c13a_recipient_issues_select on public.recipient_issues
for select to authenticated
using (
  public.has_permission('DISPATCH_VIEW')
  and exists (
    select 1
    from public.dispatch_unit_allocations a
    join public.dispatch_lines dl on dl.id=a.dispatch_line_id
    join public.dispatches d on d.id=dl.dispatch_id
    where a.id=dispatch_unit_allocation_id
      and public.can_access_branch(d.branch_id)
  )
);

commit;
