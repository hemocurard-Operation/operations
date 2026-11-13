-- HemoCura v11 Brecha C1 — Matriz regulatoria general (§8).
--
-- Compliance Penal ya está digitalizado como requisitos+assessments+actions.
-- Falta el equivalente para el marco sanitario, laboral, ambiental y de
-- datos. Esta migración genera el esqueleto con el mismo patrón:
--
--   regulatory_requirements — catálogo de normas aplicables (artículo,
--                             obligación, fuente oficial, aplicabilidad).
--   regulatory_assessments  — estado por norma × sucursal (NO_INICIADO,
--                             EN_DESARROLLO, IMPLEMENTADO, VERIFICADO,
--                             BLOQUEADO) con madurez 0-4 y evidencia.
--   regulatory_actions      — plan de acciones por requisito.
--
-- El seed inicial carga las normas RD más relevantes para HemoCura
-- documentadas en docs/recursos/HC-SGC-MC-01_*.html y
-- HC-SGC-Arquitectura-Documental-v1.html. Cada requisito se marca como
-- borrador (active=true pero mandatory=true solo para leyes). El equipo
-- legal interno debe revisar y aprobar antes de usar como matriz
-- vinculante.

begin;

insert into public.app_permissions(permission_code,active,description) values
 ('REGULATORY_VIEW',true,'Consulta de matriz regulatoria y evidencias'),
 ('REGULATORY_WRITE',true,'Registrar evaluaciones y evidencias regulatorias'),
 ('REGULATORY_REVIEW',true,'Revisión independiente de cumplimiento regulatorio')
 on conflict (permission_code) do update set active=excluded.active,description=excluded.description;

insert into public.role_permissions(role_id,permission_code)
 select r.id,p.permission_code from public.roles r cross join public.app_permissions p
 where r.code in ('SUPER_USUARIO','GERENCIA_GENERAL','CALIDAD')
   and p.permission_code in ('REGULATORY_VIEW','REGULATORY_WRITE','REGULATORY_REVIEW')
 on conflict do nothing;

insert into public.role_permissions(role_id,permission_code)
 select r.id,'REGULATORY_VIEW' from public.roles r
 where r.code in ('GERENCIA_OPERATIVA','ENCARGADA_LABORATORIO','MEDICO_GERENTE_TECNICO')
 on conflict do nothing;

create table public.regulatory_requirements(
 id uuid primary key default gen_random_uuid(),
 requirement_code text not null unique,
 sequence_no integer not null,
 domain text not null check(domain in (
  'SALUD_GENERAL','BANCO_SANGRE','LABORATORIO','CAMARA_HIPERBARICA',
  'DATOS_PERSONALES','SEGURIDAD_LABORAL','AMBIENTAL','TRIBUTARIO','OTRO'
 )),
 source_norm text not null,
 article_reference text,
 title text not null,
 obligation text not null,
 applicability text not null,
 responsible_role text,
 evidence_type text,
 review_frequency_months integer check(review_frequency_months is null or review_frequency_months between 1 and 60),
 mandatory boolean not null default true,
 active boolean not null default true,
 approved_by uuid references public.profiles(id),
 approved_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table public.regulatory_assessments(
 id uuid primary key default gen_random_uuid(),
 requirement_id uuid not null references public.regulatory_requirements(id) on delete restrict,
 branch_id uuid references public.branches(id) on delete restrict,
 status text not null default 'NO_INICIADO'
  check(status in ('NO_INICIADO','EN_DESARROLLO','IMPLEMENTADO','VERIFICADO','BLOQUEADO','NO_APLICA')),
 maturity smallint not null default 0 check(maturity between 0 and 4),
 owner_user_id uuid references public.profiles(id),
 target_date date,
 evidence_reference text,
 notes text,
 last_reviewed_at timestamptz,
 reviewed_by uuid references public.profiles(id),
 created_by uuid references public.profiles(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create unique index regulatory_assessment_scope
 on public.regulatory_assessments(requirement_id,coalesce(branch_id,'00000000-0000-0000-0000-000000000000'::uuid));

create table public.regulatory_actions(
 id uuid primary key default gen_random_uuid(),
 requirement_id uuid not null references public.regulatory_requirements(id) on delete restrict,
 assessment_id uuid references public.regulatory_assessments(id) on delete set null,
 branch_id uuid references public.branches(id),
 title text not null,
 description text,
 priority text not null default 'MEDIA' check(priority in ('BAJA','MEDIA','ALTA','CRITICA')),
 status text not null default 'PENDIENTE' check(status in ('PENDIENTE','EN_CURSO','BLOQUEADA','COMPLETADA','VERIFICADA','CANCELADA')),
 owner_user_id uuid references public.profiles(id),
 due_date date,
 evidence_reference text,
 verification_notes text,
 verified_by uuid references public.profiles(id),
 verified_at timestamptz,
 created_by uuid references public.profiles(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 check(verified_by is null or verified_by is distinct from owner_user_id)
);

alter table public.regulatory_requirements enable row level security;
alter table public.regulatory_assessments enable row level security;
alter table public.regulatory_actions enable row level security;
revoke all on public.regulatory_requirements,public.regulatory_assessments,public.regulatory_actions
 from public,anon,authenticated;
grant select on public.regulatory_requirements to authenticated;
grant select,insert,update on public.regulatory_assessments,public.regulatory_actions to authenticated;

create policy regulatory_req_read on public.regulatory_requirements for select to authenticated
 using(public.has_permission('REGULATORY_VIEW'));
create policy regulatory_ass_read on public.regulatory_assessments for select to authenticated
 using(public.has_permission('REGULATORY_VIEW')
       and (branch_id is null or public.can_access_branch(branch_id) or public.has_role('SUPER_USUARIO')));
create policy regulatory_ass_write on public.regulatory_assessments for insert to authenticated
 with check(public.has_permission('REGULATORY_WRITE')
            and (branch_id is null or public.can_access_branch(branch_id)));
create policy regulatory_ass_update on public.regulatory_assessments for update to authenticated
 using(public.has_permission('REGULATORY_WRITE'))
 with check(public.has_permission('REGULATORY_WRITE'));
create policy regulatory_act_read on public.regulatory_actions for select to authenticated
 using(public.has_permission('REGULATORY_VIEW'));
create policy regulatory_act_write on public.regulatory_actions for insert to authenticated
 with check(public.has_permission('REGULATORY_WRITE'));
create policy regulatory_act_update on public.regulatory_actions for update to authenticated
 using(public.has_permission('REGULATORY_WRITE') or public.has_permission('REGULATORY_REVIEW'))
 with check(public.has_permission('REGULATORY_WRITE') or public.has_permission('REGULATORY_REVIEW'));

-- Seed inicial. Borrador — requiere revisión legal interna antes de uso
-- vinculante (approved_by=NULL hasta que lo apruebe un oficial de cumplimiento).
insert into public.regulatory_requirements
 (requirement_code,sequence_no,domain,source_norm,article_reference,title,obligation,applicability,review_frequency_months)
values
 ('LEY-42-01-GEN',1,'SALUD_GENERAL','Ley General de Salud 42-01','Marco general',
  'Habilitación sanitaria y potestad sancionadora',
  'Mantener habilitación vigente del establecimiento y cumplir las normas que desarrollan la ley',
  'Todas las sucursales del banco de sangre y la cámara hiperbárica',12),
 ('DEC-349-04-BS',2,'BANCO_SANGRE','Decreto 349-04 + Norma de Habilitación de Bancos de Sangre','Norma de Habilitación',
  'Cumplimiento de requisitos técnicos y documentales de banco de sangre',
  'Mantener procedimientos, personal, infraestructura, equipos y registros exigidos por la norma',
  'Banco de sangre en Santiago, Puerto Plata y Tenares',12),
 ('MSP-INMUNO-BS',3,'BANCO_SANGRE','Manual de Procedimientos de Inmunohematología MSP','Manual oficial',
  'Determinación ABO/Rh con doble determinación y controles',
  'Aplicación en tamizaje y pre-transfusión según el manual vigente',
  'Laboratorio',12),
 ('MSP-GUIA-USO',4,'BANCO_SANGRE','Guía de Uso Clínico de Sangre y Hemoderivados MSP','Guía oficial',
  'Uso clínico ajustado a indicaciones autorizadas',
  'Despacho de hemocomponentes a centros y hospitales',
  'Despacho y relaciones con hospitales',12),
 ('LEY-172-13-DP',5,'DATOS_PERSONALES','Ley 172-13 de Protección de Datos de Carácter Personal','Arts. 2-17',
  'Protección de datos personales y de salud, incluyendo el dato serológico del donante',
  'Inventario de datos, base legal, minimización, accesos por perfil, acuerdos de confidencialidad, gestión de brechas',
  'Todas las áreas que manejen datos de donantes, pacientes, personal y clientes',6),
 ('LEY-87-01-SS',6,'SEGURIDAD_LABORAL','Ley 87-01 Sistema Dominicano de Seguridad Social','Marco general',
  'Afiliación y cotización al sistema de seguridad social',
  'Relación con ARS, facturación y requisitos de prestador — alcance específico pendiente',
  'Administración y recursos humanos',12),
 ('LEY-64-00-AMB',7,'AMBIENTAL','Ley 64-00 de Medio Ambiente y Recursos Naturales','Residuos biológicos',
  'Manejo y disposición de residuos biológico-infecciosos',
  'Manifiesto de entrega de residuos, ruta de disposición final, plan de gestión',
  'Laboratorio y servicios generales',12),
 ('CODIGO-TRABAJO',8,'SEGURIDAD_LABORAL','Código de Trabajo','Capítulos de salud ocupacional',
  'Seguridad y salud ocupacional del personal',
  'Riesgos biológicos, ergonómicos, químicos; EPP; incidentes y accidentes de trabajo',
  'Todas las sucursales',12),
 ('ISO-15189-TEC',9,'LABORATORIO','ISO 15189:2022','Capítulos 4-8',
  'Competencia técnica, imparcialidad y funcionamiento consistente del laboratorio',
  'Mantener SGC de laboratorio alineado y evidencias de competencia, no conformidades, CAPA, evaluación externa',
  'Laboratorio clínico',12),
 ('ISO-9001-SGC',10,'SALUD_GENERAL','ISO 9001:2015','Capítulos 4-10',
  'Sistema de gestión de la calidad',
  'Mantener SGC documentado, revisión por dirección, auditorías internas, mejora continua',
  'Toda la organización',12),
 ('CAM-HIP-REG',11,'CAMARA_HIPERBARICA','Normativa aplicable a cámaras hiperbáricas en RD','Pendiente de confirmación legal',
  'Habilitación específica del servicio de medicina hiperbárica',
  'Pendiente — requiere investigación legal RD (ver Brecha C3 del PLAN_EJECUTIVO_v11)',
  'Cámara hiperbárica',null)
on conflict (requirement_code) do update set
 source_norm=excluded.source_norm,title=excluded.title,obligation=excluded.obligation,
 applicability=excluded.applicability,updated_at=now();

-- Función helper para filtrar normas vigentes.
create or replace view public.vw_regulatory_matrix with(security_invoker=true) as
select
 r.id as requirement_id,r.requirement_code,r.sequence_no,r.domain,r.source_norm,
 r.article_reference,r.title,r.obligation,r.applicability,r.mandatory,r.review_frequency_months,
 r.approved_by,r.approved_at,
 a.id as assessment_id,a.branch_id,a.status as assessment_status,a.maturity,
 a.owner_user_id,a.target_date,a.evidence_reference,a.last_reviewed_at,a.reviewed_by,
 case
  when not r.active then 'INACTIVO'
  when a.status in ('VERIFICADO') and (a.last_reviewed_at is null or r.review_frequency_months is null
                                        or a.last_reviewed_at>=now()-make_interval(months=>r.review_frequency_months)) then 'AL_DIA'
  when a.status='IMPLEMENTADO' then 'IMPLEMENTADO_SIN_VERIFICAR'
  when a.status in ('NO_INICIADO','EN_DESARROLLO','BLOQUEADO') then 'PENDIENTE'
  when a.status='NO_APLICA' then 'NO_APLICA'
  when a.status='VERIFICADO' then 'REVISION_VENCIDA'
  else 'SIN_EVALUAR'
 end as overall_state
from public.regulatory_requirements r
left join public.regulatory_assessments a on a.requirement_id=r.id;

grant select on public.vw_regulatory_matrix to authenticated;

notify pgrst,'reload schema';
commit;
