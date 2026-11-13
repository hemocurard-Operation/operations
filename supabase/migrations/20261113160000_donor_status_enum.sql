-- HemoCura v11 Brecha D4 — enum ampliado para donors.status.
--
-- El prompt maestro §6.1b lista cinco estados: ACEPTADO, DIFERIDO
-- TEMPORAL, DIFERIDO PERMANENTE, HEMOGLOBINA BAJA, PENDIENTE DE
-- EVALUACIÓN. El CHECK original solo aceptaba ACEPTADO y DIFERIDO.
--
-- Esta migración amplía el CHECK de forma aditiva (mantiene los dos
-- valores legacy para no invalidar filas existentes) y añade una
-- columna opcional deferral_type para sub-clasificar diferimientos
-- cuando el personal autorizado lo registra. No se hace backfill
-- automático: los diferimientos históricos como 'DIFERIDO' quedan
-- intactos hasta que un revisor clínico decida reclasificarlos.

begin;

alter table public.donors drop constraint if exists donors_status_check;

alter table public.donors
 add constraint donors_status_check check(status in (
  'PENDIENTE','ACEPTADO','DIFERIDO','DIFERIDO_TEMPORAL',
  'DIFERIDO_PERMANENTE','HEMOGLOBINA_BAJA','RECHAZADO'
 ));

alter table public.donors add column if not exists deferral_type text;
alter table public.donors drop constraint if exists donors_deferral_type_check;
alter table public.donors add constraint donors_deferral_type_check
 check(deferral_type is null or deferral_type in (
  'TEMPORAL','PERMANENTE','HEMOGLOBINA_BAJA','PRESION_ARTERIAL',
  'MEDICAMENTO','PROCEDIMIENTO_RECIENTE','CONDUCTA_RIESGO','OTRO'
 ));

-- Alineación semántica: si el status es un DIFERIDO_* o HEMOGLOBINA_BAJA,
-- debe existir una razón o un deferral_type. No es un trigger clínico, es
-- una verificación de completitud de registro.
alter table public.donors drop constraint if exists donors_deferral_requires_reason;
alter table public.donors add constraint donors_deferral_requires_reason
 check(
  status in ('ACEPTADO','PENDIENTE','DIFERIDO','RECHAZADO')
  or (coalesce(deferral_reason,'')<>'' or deferral_type is not null)
 );

create index if not exists donors_status_idx on public.donors(status) where status<>'ACEPTADO';

notify pgrst,'reload schema';
commit;
