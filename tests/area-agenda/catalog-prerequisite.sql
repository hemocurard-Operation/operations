-- The legacy reconstruction lacks the existing production operations-assistant role.
-- Test-only catalog prerequisite, not a proposed production role migration.
insert into public.roles(code,name) values('ASISTENTE_OPERACIONES','Asistente de Operaciones') on conflict(code) do nothing;
