begin;
-- Allows "lanzamiento de producto" projects to live in the existing projects
-- table (domain=COMERCIAL) instead of a parallel table, so the new unified
-- commercial calendar can read target_date directly from what already exists.

alter table public.projects drop constraint if exists projects_domain_check;
alter table public.projects add constraint projects_domain_check
  check(domain in ('OPERACIONES','SGC','COMPLIANCE','TECNOLOGIA','CAPACITACION','COMERCIAL'));

notify pgrst,'reload schema';
commit;
