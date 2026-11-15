-- HemoCura v11 Brecha BI1 — metadata de predicción.
-- Verifica el schema y el seed.

begin;

create function pg_temp.ok(v boolean,label text) returns void language plpgsql as $$
begin
 if v is distinct from true then raise exception 'FAIL %',label;end if;
 raise notice 'PASS %',label;
end$$;

create function pg_temp.denied(stmt text,label text) returns void language plpgsql as $$
begin
 begin execute stmt;exception when others then
  raise notice 'PASS %',label;return;
 end;
 raise exception 'FAIL unexpectedly allowed %',label;
end$$;

-- Invariante 1: la tabla existe.
select pg_temp.ok(
 (select to_regclass('public.predictive_meta') is not null),
 'predictive_meta table exists');

-- Invariante 2: seed de las 8 vistas.
select pg_temp.ok(
 (select count(*)>=8 from public.predictive_meta),
 'seed includes at least 8 predictive views');

-- Invariante 3: cada seed tiene campos obligatorios no nulos.
select pg_temp.ok(
 (select count(*)=0 from public.predictive_meta
   where method is null or limitations is null or domain is null or title is null),
 'every seeded row has required fields populated');

-- Invariante 4: confidence_level solo acepta los valores del enum.
select pg_temp.denied(
 $q$insert into public.predictive_meta(view_name,title,domain,method,limitations,confidence_level)
    values('vw_x','x','DEMANDA','agg','x','ML_BLACKBOX')$q$,
 'invalid confidence_level is rejected');

-- Invariante 5: domain solo acepta valores del enum.
select pg_temp.denied(
 $q$insert into public.predictive_meta(view_name,title,domain,method,limitations)
    values('vw_y','y','SOLO_DIOS_SABE','agg','x')$q$,
 'invalid domain is rejected');

-- Invariante 6: horizon_days en rango.
select pg_temp.denied(
 $q$insert into public.predictive_meta(view_name,title,domain,method,limitations,horizon_days)
    values('vw_z','z','DEMANDA','agg','x',10000)$q$,
 'horizon_days out of range is rejected');

do $$declare previous integer;begin
 select revision into previous from predictive_meta where view_name='vw_predictive_demand_30d';
 update predictive_meta set method='Nuevo método suavizado' where view_name='vw_predictive_demand_30d';
 perform pg_temp.ok((select revision>previous from predictive_meta where view_name='vw_predictive_demand_30d'),'updating method bumps revision via trigger');
end$$;

-- Invariante 8: data_sources es un text array.
select pg_temp.ok(
 (select array_length(data_sources,1)>=1
    from predictive_meta where view_name='vw_stock_risk_projection'),
 'data_sources is populated as text array');

do $$declare previous integer;begin
 select revision into previous from predictive_meta where view_name='vw_stock_risk_projection';
 update predictive_meta set title=title where view_name='vw_stock_risk_projection';
 perform pg_temp.ok((select revision=previous from predictive_meta where view_name='vw_stock_risk_projection'),'updating title does not bump revision');
end$$;
rollback;
