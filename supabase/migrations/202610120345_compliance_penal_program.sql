-- HemoCura · Compliance Penal v1
-- Applied to Supabase project tiothqiljipdamgudvcb before this file was committed.
-- Additive schema only. No clinical tables are modified.

create table if not exists public.compliance_penal_requirements (
  id uuid primary key default gen_random_uuid(),
  requirement_code text not null unique,
  sequence_no integer not null unique check (sequence_no between 1 and 11),
  title text not null,
  legal_basis text not null,
  objective text not null,
  mandatory boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.compliance_penal_assessments (
  id uuid primary key default gen_random_uuid(),
  requirement_id uuid not null references public.compliance_penal_requirements(id) on delete restrict,
  branch_id uuid null references public.branches(id) on delete restrict,
  status text not null default 'NO_INICIADO' check (status in ('NO_INICIADO','EN_DESARROLLO','IMPLEMENTADO','VERIFICADO','BLOQUEADO')),
  maturity smallint not null default 0 check (maturity between 0 and 4),
  owner_user_id uuid null references public.profiles(id) on delete set null,
  target_date date null,
  evidence_reference text null,
  notes text null,
  last_reviewed_at timestamptz null,
  reviewed_by uuid null references public.profiles(id) on delete set null,
  created_by uuid null references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists compliance_penal_assessment_scope_uq
  on public.compliance_penal_assessments(requirement_id, coalesce(branch_id,'00000000-0000-0000-0000-000000000000'::uuid));

create table if not exists public.compliance_penal_actions (
  id uuid primary key default gen_random_uuid(),
  requirement_id uuid not null references public.compliance_penal_requirements(id) on delete restrict,
  assessment_id uuid null references public.compliance_penal_assessments(id) on delete set null,
  branch_id uuid null references public.branches(id) on delete restrict,
  title text not null,
  description text null,
  priority text not null default 'MEDIA' check (priority in ('BAJA','MEDIA','ALTA','CRITICA')),
  status text not null default 'PENDIENTE' check (status in ('PENDIENTE','EN_CURSO','BLOQUEADA','COMPLETADA','VERIFICADA')),
  owner_user_id uuid null references public.profiles(id) on delete set null,
  due_date date null,
  evidence_reference text null,
  verification_notes text null,
  verified_by uuid null references public.profiles(id) on delete set null,
  verified_at timestamptz null,
  created_by uuid null references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.compliance_penal_requirements enable row level security;
alter table public.compliance_penal_assessments enable row level security;
alter table public.compliance_penal_actions enable row level security;

revoke all on public.compliance_penal_requirements from anon;
revoke all on public.compliance_penal_assessments from anon;
revoke all on public.compliance_penal_actions from anon;
grant select on public.compliance_penal_requirements to authenticated;
grant select,insert,update,delete on public.compliance_penal_assessments to authenticated;
grant select,insert,update,delete on public.compliance_penal_actions to authenticated;

drop policy if exists compliance_penal_requirements_read on public.compliance_penal_requirements;
create policy compliance_penal_requirements_read on public.compliance_penal_requirements for select to authenticated using (public.has_permission('COMPLIANCE_VIEW'));

drop policy if exists compliance_penal_assessments_read on public.compliance_penal_assessments;
create policy compliance_penal_assessments_read on public.compliance_penal_assessments for select to authenticated using (public.has_permission('COMPLIANCE_VIEW') and (branch_id is null or public.can_access_branch(branch_id)));

drop policy if exists compliance_penal_assessments_write on public.compliance_penal_assessments;
create policy compliance_penal_assessments_write on public.compliance_penal_assessments for all to authenticated using (public.has_permission('COMPLIANCE_WRITE') and (branch_id is null or public.can_access_branch(branch_id))) with check (public.has_permission('COMPLIANCE_WRITE') and (branch_id is null or public.can_access_branch(branch_id)));

drop policy if exists compliance_penal_actions_read on public.compliance_penal_actions;
create policy compliance_penal_actions_read on public.compliance_penal_actions for select to authenticated using (public.has_permission('COMPLIANCE_VIEW') and (branch_id is null or public.can_access_branch(branch_id)));

drop policy if exists compliance_penal_actions_write on public.compliance_penal_actions;
create policy compliance_penal_actions_write on public.compliance_penal_actions for all to authenticated using (public.has_permission('COMPLIANCE_WRITE') and (branch_id is null or public.can_access_branch(branch_id))) with check (public.has_permission('COMPLIANCE_WRITE') and (branch_id is null or public.can_access_branch(branch_id)));

insert into public.compliance_penal_requirements(requirement_code,sequence_no,title,legal_basis,objective)
values
('CP-01',1,'Política y código de conducta','Ley 74-25, art. 8, párr. VI.1, mod. Ley 44-26','Definir obligaciones claras para órganos, representantes y empleados sobre prevención y detección de infracciones.'),
('CP-02',2,'Mapa de riesgos penales','Ley 74-25, art. 8, párr. VI.2, mod. Ley 44-26','Identificar por proceso y actividad los ámbitos donde puedan presentarse riesgos penales.'),
('CP-03',3,'Controles preventivos','Ley 74-25, art. 8, párr. VI.3, mod. Ley 44-26','Establecer medidas de control adecuadas y verificables para prevenir infracciones.'),
('CP-04',4,'Formación continua y derechos humanos','Ley 74-25, art. 8, párr. VI.4, mod. Ley 44-26','Capacitar continuamente y documentar sensibilización, igualdad, no discriminación y prevención de infracciones.'),
('CP-05',5,'Órgano de supervisión con autonomía','Ley 74-25, art. 8, párr. VI.5, mod. Ley 44-26','Asignar poderes y responsabilidades suficientes para supervisar el programa con independencia funcional.'),
('CP-06',6,'Controles financieros y contables','Ley 74-25, art. 8, párr. VI.6, mod. Ley 44-26','Prevenir pagos, operaciones o beneficios ilícitos mediante controles financieros y contables.'),
('CP-07',7,'Protocolo de actuación y régimen disciplinario','Ley 74-25, art. 8, párr. VI.7, mod. Ley 44-26','Definir respuesta ante riesgos o infracciones y consecuencias disciplinarias por incumplimientos.'),
('CP-08',8,'Canal interno de denuncia y no represalias','Ley 74-25, art. 8, párr. VI.8, mod. Ley 44-26','Mantener canal interno anónimo, protección al denunciante y reglas contra represalias.'),
('CP-09',9,'Investigación de denuncias','Ley 74-25, art. 8, párr. VI.9, mod. Ley 44-26','Contar con un procedimiento claro, imparcial y eficiente para investigar reportes.'),
('CP-10',10,'Revisión y actualización periódica','Ley 74-25, art. 8, párr. VI.10, mod. Ley 44-26','Revisar el modelo periódicamente y cuando cambien organización, procesos o requisitos.'),
('CP-11',11,'Trazabilidad documental','Ley 74-25, art. 8, párr. VI.11, mod. Ley 44-26','Conservar evidencia trazable de diseño, ejecución, monitoreo, decisiones y mejoras del programa.')
on conflict (requirement_code) do update set sequence_no=excluded.sequence_no,title=excluded.title,legal_basis=excluded.legal_basis,objective=excluded.objective,mandatory=true,active=true;
