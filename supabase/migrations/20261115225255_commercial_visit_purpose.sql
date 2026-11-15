-- HemoCura v11 Brecha CM2 — tipificación de visitas comerciales.
-- Prompt §9 pide separar "promoción banco de sangre, campañas de donación,
-- cámara hiperbárica, relaciones con hospitales, educación y promoción
-- institucional". El campo purpose existente es texto libre, lo que impide
-- reportar mix de actividad por tipo. Añadimos purpose_type como enum
-- opcional (aditivo, no rompe filas existentes) y una vista agregadora.

begin;

alter table public.commercial_visits add column if not exists purpose_type text;
alter table public.commercial_visits drop constraint if exists commercial_visits_purpose_type_check;
alter table public.commercial_visits add constraint commercial_visits_purpose_type_check
 check(purpose_type is null or purpose_type in (
  'VENTA','PROMOCION_DONACION','EDUCACION_INSTITUCIONAL',
  'CAMARA_HIPERBARICA','POST_SERVICIO','REVISION_SLA','OTRO'
 ));

create index if not exists commercial_visits_purpose_type
 on public.commercial_visits(branch_id,purpose_type)
 where purpose_type is not null;

create or replace view public.vw_commercial_activity_mix with(security_invoker=true) as
select
 branch_id,
 date_trunc('month',scheduled_at) as month,
 coalesce(purpose_type,'SIN_TIPIFICAR') as purpose_type,
 count(*) as visits_count,
 count(*) filter(where status='REALIZADA') as completed_count,
 sum(duration_minutes) as total_minutes,
 sum(duration_minutes) filter(where status='REALIZADA') as completed_minutes
from public.commercial_visits
group by branch_id,date_trunc('month',scheduled_at),coalesce(purpose_type,'SIN_TIPIFICAR');

grant select on public.vw_commercial_activity_mix to authenticated;

notify pgrst,'reload schema';
commit;
