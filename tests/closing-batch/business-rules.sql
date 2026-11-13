begin;

insert into branches(id,code,name,active) values ('cb100000-0000-0000-0000-000000000099','CB-A','Closing A',true);
insert into auth.users(id,email) values
 ('cb200000-0000-0000-0000-000000000011','author@example.invalid'),
 ('cb200000-0000-0000-0000-000000000012','responsible@example.invalid');
insert into profiles(id,full_name,branch_id,active) values
 ('cb200000-0000-0000-0000-000000000011','Autor','cb100000-0000-0000-0000-000000000099',true),
 ('cb200000-0000-0000-0000-000000000012','Responsable técnico','cb100000-0000-0000-0000-000000000099',true);
insert into suppliers(id,name,active) values('cb400000-0000-0000-0000-000000000001','Proveedor L3',true);

create function pg_temp.ok(v boolean,label text) returns void language plpgsql as $$
begin if v is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;
create function pg_temp.denied(stmt text,label text) returns void language plpgsql as $$
begin begin execute stmt;exception when others then raise notice 'PASS %',label;return;end;
 raise exception 'FAIL unexpectedly allowed %',label;end$$;

------------------------------------------------------------
-- L3: dossier de equipo.
------------------------------------------------------------
insert into lab_equipment(id,equipment_code,branch_id,equipment_type,status,
                           manufacturer,model,serial_number,acquisition_date,
                           supplier_id,warranty_until,documentation_ref,responsible_user_id) values
 ('cb300000-0000-0000-0000-000000000001','DOSS-OK',
  'cb100000-0000-0000-0000-000000000099','Nevera','ACTIVO',
  'Fabricante X','MX-100','SN-ABC',current_date-120,
  'cb400000-0000-0000-0000-000000000001',current_date+200,'DOC-URL','cb200000-0000-0000-0000-000000000012'),
 ('cb300000-0000-0000-0000-000000000002','DOSS-EXP',
  'cb100000-0000-0000-0000-000000000099','Centrifuga','ACTIVO',
  'Fabricante Y','MY-200','SN-XYZ',current_date-700,
  'cb400000-0000-0000-0000-000000000001',current_date-10,null,null),
 ('cb300000-0000-0000-0000-000000000003','DOSS-SOON',
  'cb100000-0000-0000-0000-000000000099','Analizador','ACTIVO',
  'Fabricante Z','MZ-50','SN-SOON',current_date-300,
  null,current_date+20,null,null);

select pg_temp.ok(
 (select warranty_status='VIGENTE' from vw_equipment_dossier where equipment_code='DOSS-OK'),
 'warranty>30d shows VIGENTE');

select pg_temp.ok(
 (select warranty_status='VENCIDA' from vw_equipment_dossier where equipment_code='DOSS-EXP'),
 'past warranty shows VENCIDA');

select pg_temp.ok(
 (select warranty_status='POR_VENCER' from vw_equipment_dossier where equipment_code='DOSS-SOON'),
 'warranty <= 30d shows POR_VENCER');

select pg_temp.ok(
 (select supplier_name='Proveedor L3' and responsible_name='Responsable técnico'
    from vw_equipment_dossier where equipment_code='DOSS-OK'),
 'dossier joins supplier and responsible user');

------------------------------------------------------------
-- CM1: metas comerciales.
------------------------------------------------------------
insert into commercial_goals(period_start,period_end,branch_id,metric,target_value,approved_by,approved_at)
values
 (date_trunc('month',current_date)::date,
  (date_trunc('month',current_date)+interval '1 month -1 day')::date,
  'cb100000-0000-0000-0000-000000000099','VISITAS_COMPLETADAS',20,
  'cb200000-0000-0000-0000-000000000011',now());

-- target_value <= 0 rechazado.
select pg_temp.denied(
 $q$insert into commercial_goals(period_start,period_end,branch_id,metric,target_value)
    values(current_date,current_date+30,'cb100000-0000-0000-0000-000000000099','VISITAS_COMPLETADAS',0)$q$,
 'target_value must be positive');

-- metric fuera del enum.
select pg_temp.denied(
 $q$insert into commercial_goals(period_start,period_end,branch_id,metric,target_value)
    values(current_date,current_date+30,'cb100000-0000-0000-0000-000000000099','VIBES',5)$q$,
 'metric outside enum is rejected');

-- period_end <= period_start.
select pg_temp.denied(
 $q$insert into commercial_goals(period_start,period_end,branch_id,metric,target_value)
    values(current_date,current_date-1,'cb100000-0000-0000-0000-000000000099','VISITAS_COMPLETADAS',5)$q$,
 'period_end must be after period_start');

-- vw_commercial_goal_progress produce actual_value.
select pg_temp.ok(
 (select actual_value=0 from vw_commercial_goal_progress
   where branch_id='cb100000-0000-0000-0000-000000000099' and metric='VISITAS_COMPLETADAS'),
 'goal progress reports actual=0 when no visits yet');

------------------------------------------------------------
-- BI2: supply forecast.
------------------------------------------------------------
select pg_temp.ok(
 (select 1 from pg_views where viewname='vw_supply_consumption_forecast')=1,
 'supply consumption forecast view exists');

------------------------------------------------------------
-- BI4: donor outlook.
------------------------------------------------------------
select pg_temp.ok(
 (select supply_tier='SIN_HISTORIAL' from vw_donor_outlook
   where branch_id='cb100000-0000-0000-0000-000000000099'),
 'donor outlook reports SIN_HISTORIAL when no donations');

-- Seed donaciones efectivas.
insert into donors(id,donor_code,branch_id,donor_type,status) values
 ('cb500000-0000-0000-0000-000000000001','BI4-D','cb100000-0000-0000-0000-000000000099','VOLUNTARIO','ACEPTADO');
insert into donations(donation_code,donor_id,branch_id,source_unit_code,donation_date,collection_effective)
 select 'BI4-DN-'||i::text,'cb500000-0000-0000-0000-000000000001',
        'cb100000-0000-0000-0000-000000000099','BI4-UN-'||i::text,
        current_date-((i*2)%89),true
  from generate_series(1,30) i;

select pg_temp.ok(
 (select effective_donations_90d>=25 from vw_donor_outlook
   where branch_id='cb100000-0000-0000-0000-000000000099'),
 'donor outlook aggregates 90-day history');

select pg_temp.ok(
 (select projected_next_4w>0 from vw_donor_outlook
   where branch_id='cb100000-0000-0000-0000-000000000099'),
 'donor outlook projects 4-week supply from average');

-- Meta registrada en predictive_meta.
select pg_temp.ok(
 (select 1 from predictive_meta where view_name='vw_donor_outlook')=1,
 'donor outlook registered in predictive_meta');

select pg_temp.ok(
 (select 1 from predictive_meta where view_name='vw_supply_consumption_forecast')=1,
 'supply forecast registered in predictive_meta');

commit;
