-- HemoCura v0.20.0
-- CREAR PERFIL + ROL DEL PRIMER ADMINISTRADOR
-- Ejecutar DESPUÉS de:
-- 1) crear el usuario en Authentication > Users
-- 2) copiar su UUID
-- 3) ejecutar el instalador v7.2
--
-- REEMPLAZAR:
-- REEMPLAZAR_USER_UUID
-- REEMPLAZAR_NOMBRE

begin;

insert into public.profiles(id, full_name, branch_id, active)
select
  'REEMPLAZAR_USER_UUID'::uuid,
  'REEMPLAZAR_NOMBRE',
  b.id,
  true
from public.branches b
where b.code='STI'
on conflict (id) do update
set full_name=excluded.full_name,
    branch_id=excluded.branch_id,
    active=true,
    updated_at=now();

insert into public.user_roles(user_id, role_id, branch_id)
select
  'REEMPLAZAR_USER_UUID'::uuid,
  r.id,
  b.id
from public.roles r
cross join public.branches b
where r.code='ADMIN'
  and b.code='STI'
on conflict do nothing;

commit;

-- VERIFICACIÓN
select
  p.id,
  p.full_name,
  b.code branch_code,
  b.name branch_name,
  r.code role_code,
  r.name role_name
from public.profiles p
left join public.branches b on b.id=p.branch_id
left join public.user_roles ur on ur.user_id=p.id
left join public.roles r on r.id=ur.role_id
where p.id='REEMPLAZAR_USER_UUID'::uuid;
