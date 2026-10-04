-- HemoCura v0.20.0
-- VERIFICACIÓN DE INSTALACIÓN SUPABASE

-- 1. Catálogos base
select 'branches' objeto, count(*) total from public.branches
union all
select 'roles', count(*) from public.roles
union all
select 'products', count(*) from public.products;

-- Esperado inicialmente:
-- branches = 3
-- roles = 9
-- products = 6

-- 2. Sucursales
select code,name,active from public.branches order by code;

-- 3. Roles
select code,name from public.roles order by code;

-- 4. Productos
select code,name,active from public.products order by code;

-- 5. Perfil / roles
select p.id,p.full_name,b.code branch_code,r.code role_code
from public.profiles p
left join public.branches b on b.id=p.branch_id
left join public.user_roles ur on ur.user_id=p.id
left join public.roles r on r.id=ur.role_id
order by p.full_name;

-- 6. Vistas críticas (deben ejecutar sin error en SQL Editor)
select * from public.vw_command_center_today limit 1;
select * from public.vw_inventory_status limit 1;
select * from public.vw_monthly_product_costs limit 1;
select * from public.vw_quality_today limit 1;
select * from public.vw_plan_vs_actual_status limit 1;
