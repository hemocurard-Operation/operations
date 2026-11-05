begin;
-- Contact email is deliberately not unique. Authentication and roles remain personal UUIDs.
create table public.user_account_contacts(
 user_id uuid primary key references auth.users(id) on delete cascade,
 username text not null unique check(username=lower(username) and username ~ '^[a-z][a-z0-9._-]{2,39}$'),
 contact_email text check(contact_email is null or (contact_email=lower(contact_email) and contact_email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$')),
 created_at timestamptz not null default now(),created_by uuid not null references public.profiles(id));
alter table public.user_account_contacts enable row level security;
revoke all on public.user_account_contacts from public,anon,authenticated;
grant select on public.user_account_contacts to authenticated;
grant select,insert on public.user_account_contacts to service_role;
create policy personal_login_read on public.user_account_contacts for select to authenticated
using(public.wf_active_actor() and (user_id=(select auth.uid()) or public.has_role('SUPER_USUARIO')));
insert into public.app_feature_flags(key,enabled,mode,description) values('personal_username_accounts',false,'OFF','Usuarios personales con nombre de acceso único y correo de contacto compartible; conserva los accesos existentes por correo');
comment on table public.user_account_contacts is 'Correo de contacto no es identidad de acceso. Solo admin-users, tras autenticar al Super Usuario, crea estos registros. El correo compartido nunca asigna roles ni recupera cuentas personales.';
notify pgrst,'reload schema';
commit;
