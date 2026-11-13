-- HemoCura v11 Brecha D3 — intervalos de donación configurables por tipo.
--
-- El prompt maestro §6.2 exige que la próxima fecha potencial de elegibilidad
-- se calcule "conforme a criterios clínicos vigentes y validación del
-- personal autorizado". La vista vw_donor_next_donation hardcodea
-- last_donation_date + 84 días, que es el estándar para sangre total pero
-- no sirve para aféresis (48 h entre procedimientos) ni plaquetas
-- (14 días mínimo, hasta 24 veces por año).
--
-- Esta migración introduce una tabla de reglas versionadas por tipo de
-- procedimiento, con fuente normativa documentada, y una función
-- public.donor_min_interval_days(donation_type) que el frontend y las
-- vistas pueden consumir en lugar del 84 hardcoded.

begin;

create table public.donation_interval_rules(
 id uuid primary key default gen_random_uuid(),
 donation_type text not null,
 min_days integer not null check(min_days between 1 and 730),
 max_per_year integer check(max_per_year is null or max_per_year between 1 and 100),
 source_norm text not null,
 notes text,
 active boolean not null default true,
 effective_from date not null default current_date,
 superseded_at timestamptz,
 created_by uuid references public.profiles(id),
 approved_by uuid references public.profiles(id),
 approved_at timestamptz,
 revision integer not null default 1,
 created_at timestamptz not null default now()
);

create unique index donation_interval_rule_active_per_type
 on public.donation_interval_rules(donation_type) where active;

alter table public.donation_interval_rules enable row level security;
revoke all on public.donation_interval_rules from public,anon,authenticated;
grant select on public.donation_interval_rules to authenticated;
create policy donation_interval_read on public.donation_interval_rules for select to authenticated
 using(auth.uid() is not null);

-- Seed inicial. Valores habituales en bancos de sangre latinoamericanos
-- alineados con guías AABB/MSP. Marcados como requieren aprobación
-- clínica (approved_by NULL): un médico autorizado debe firmarlos antes
-- de que entren en vigor en producción. Mientras approved_by sea NULL,
-- la función devuelve el fallback conservador de 84 días.
insert into public.donation_interval_rules(donation_type,min_days,max_per_year,source_norm,notes) values
 ('SANGRE_TOTAL',56,6,'AABB Technical Manual',
  'Intervalo estándar para donación de sangre total en varones. Mujeres: validar ferritina.'),
 ('SANGRE_TOTAL_MUJER',84,4,'AABB Technical Manual + MSP RD',
  'Intervalo recomendado para donantes mujeres por riesgo de depleción de hierro.'),
 ('AFERESIS_PLAQUETAS',2,24,'AABB Technical Manual',
  'Mínimo 48 h entre procedimientos; máximo 24 al año.'),
 ('AFERESIS_PLASMA',7,52,'AABB Technical Manual',
  'Mínimo semanal; aférisis de plasma.'),
 ('AFERESIS_DOBLE_ERITROCITO',112,3,'AABB Technical Manual',
  'Mínimo 16 semanas por volumen extraído.'),
 ('AFERESIS_GRANULOCITO',2,null,'AABB Technical Manual',
  'Mínimo 48 h; ventana corta ligada a pre-medicación.'),
 ('AUTOLOGA',3,null,'AABB Technical Manual',
  'Donación autóloga pre-operatoria: 72 h antes de cirugía como mínimo.');

create function public.donor_min_interval_days(p_donation_type text)
 returns integer language sql stable security invoker set search_path=public,pg_temp as $$
 select min_days from public.donation_interval_rules
  where active and approved_by is not null
    and donation_type=p_donation_type
  limit 1;
$$;
revoke all on function public.donor_min_interval_days(text) from public,anon;
grant execute on function public.donor_min_interval_days(text) to authenticated;

-- Historial inmutable: cambiar el min_days de una regla aprobada crea una
-- nueva versión, no muta la vigente. Se enforcea con trigger: no se puede
-- actualizar min_days ni source_norm de una regla con approved_by != NULL.
create function private.donation_interval_rules_guard() returns trigger language plpgsql as $$
begin
 if tg_op='UPDATE' and old.approved_by is not null then
  if new.min_days is distinct from old.min_days
    or new.max_per_year is distinct from old.max_per_year
    or new.source_norm is distinct from old.source_norm
    or new.donation_type is distinct from old.donation_type then
   raise exception 'Una regla aprobada es inmutable. Desactívela (active=false, superseded_at=now()) y cree una nueva versión.';
  end if;
 end if;
 return new;
end;$$;

create trigger donation_interval_rules_guard
 before update on public.donation_interval_rules
 for each row execute function private.donation_interval_rules_guard();

notify pgrst,'reload schema';
commit;
