-- HemoCura v11 Brecha C2 — Habilitaciones sanitarias por sucursal (§8).
--
-- Un inspector del MSP pide al banco de sangre la resolución de habilitación
-- y su vigencia por sucursal. Hoy esto vive en un folder físico y Excel.
-- Esta tabla lo digitaliza con alertas 90/60/30 días antes del vencimiento.
--
-- RLS: cada sucursal lee las suyas; SUPER_USUARIO ve todas. No almacenamos
-- PDFs aquí — solo la referencia documental (document_ref) que apunta a
-- Supabase Storage o al expediente legal interno.

begin;

insert into public.app_permissions(permission_code,active,description) values
 ('LICENSE_VIEW',true,'Consulta de habilitaciones sanitarias y documentos regulatorios'),
 ('LICENSE_WRITE',true,'Registrar y renovar habilitaciones sanitarias')
 on conflict (permission_code) do update set active=excluded.active,description=excluded.description;

insert into public.role_permissions(role_id,permission_code)
 select r.id,p.permission_code from public.roles r cross join public.app_permissions p
 where r.code in ('SUPER_USUARIO','GERENCIA_GENERAL','GERENCIA_OPERATIVA','CALIDAD')
   and p.permission_code in ('LICENSE_VIEW','LICENSE_WRITE')
 on conflict do nothing;

insert into public.role_permissions(role_id,permission_code)
 select r.id,'LICENSE_VIEW' from public.roles r
 where r.code in ('ENCARGADA_LABORATORIO','MEDICO_GERENTE_TECNICO')
 on conflict do nothing;

create table public.facility_licenses(
 id uuid primary key default gen_random_uuid(),
 branch_id uuid not null references public.branches(id),
 license_type text not null check(license_type in (
  'HABILITACION_BANCO_SANGRE','HABILITACION_LABORATORIO','HABILITACION_CAMARA_HIPERBARICA',
  'PERMISO_MANEJO_RESIDUOS','AUTORIZACION_SANITARIA_GENERAL','REGISTRO_MSP',
  'LICENCIA_RADIACIONES','CERTIFICACION_ISO','OTRO'
 )),
 authority text not null,
 license_number text not null,
 issued_at date not null,
 expires_at date check(expires_at is null or expires_at>=issued_at),
 scope text,
 document_ref text,
 status text not null default 'VIGENTE'
  check(status in ('VIGENTE','EN_RENOVACION','SUSPENDIDA','VENCIDA','ANULADA')),
 renewal_notes text,
 entered_by uuid references public.profiles(id),
 approved_by uuid references public.profiles(id),
 approved_at timestamptz,
 revision integer not null default 1,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(branch_id,license_type,license_number)
);

create index facility_licenses_expiry on public.facility_licenses(expires_at)
 where status in ('VIGENTE','EN_RENOVACION');
create index facility_licenses_branch on public.facility_licenses(branch_id);

alter table public.facility_licenses enable row level security;
revoke all on public.facility_licenses from public,anon,authenticated;
grant select,insert,update on public.facility_licenses to authenticated;

create policy facility_licenses_read on public.facility_licenses for select to authenticated
 using(public.has_permission('LICENSE_VIEW') and (public.has_role('SUPER_USUARIO') or public.can_access_branch(branch_id)));
create policy facility_licenses_insert on public.facility_licenses for insert to authenticated
 with check(public.has_permission('LICENSE_WRITE') and public.can_access_branch(branch_id));
create policy facility_licenses_update on public.facility_licenses for update to authenticated
 using(public.has_permission('LICENSE_WRITE') and public.can_access_branch(branch_id))
 with check(public.has_permission('LICENSE_WRITE') and public.can_access_branch(branch_id));

create or replace view public.vw_license_alerts with(security_invoker=true) as
select
 l.id,l.branch_id,l.license_type,l.authority,l.license_number,l.expires_at,l.status,
 case when l.expires_at is null then 999999
      else (l.expires_at-current_date) end as days_to_expiry,
 case
  when l.status='VENCIDA' then 'CRITICA'
  when l.expires_at is null then 'INFO'
  when l.expires_at<current_date then 'CRITICA'
  when l.expires_at<=current_date+30 then 'ALTA'
  when l.expires_at<=current_date+60 then 'MEDIA'
  when l.expires_at<=current_date+90 then 'BAJA'
  else 'OK'
 end as severity,
 case
  when l.status='VENCIDA' or l.expires_at<current_date then 'Habilitación vencida — detener la operación afectada e iniciar renovación de emergencia'
  when l.expires_at<=current_date+30 then 'Renovación urgente'
  when l.expires_at<=current_date+60 then 'Preparar documentación de renovación'
  when l.expires_at<=current_date+90 then 'Agendar renovación'
  else 'Vigente'
 end as recommended_action
from public.facility_licenses l
where l.status in ('VIGENTE','EN_RENOVACION','VENCIDA');

grant select on public.vw_license_alerts to authenticated;

notify pgrst,'reload schema';
commit;
