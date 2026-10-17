begin;
set local lock_timeout='5s';
create table public.sgc_blueprints(code text primary key,version text not null,definition jsonb not null);
create table public.sgc_projects(id uuid primary key default gen_random_uuid(),project_code text not null unique,title text not null,branch_id uuid not null references public.branches(id),owner_id uuid not null references public.profiles(id),scope text not null,start_date date not null,target_date date not null check(target_date>=start_date),blueprint_code text not null references public.sgc_blueprints(code),definition jsonb not null,status text not null default 'EN_CURSO' check(status in ('EN_CURSO','CERRADO_VERIFICADO')),revision int not null default 1,created_at timestamptz not null default now());
create table public.sgc_members(project_id uuid not null references public.sgc_projects(id),user_id uuid not null references public.profiles(id),role text not null check(role in ('RESPONSABLE','COLABORADOR','REVISOR')),primary key(project_id,user_id));
create table public.sgc_steps(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.sgc_projects(id),phase_code text not null,step_code text not null,definition jsonb not null,owner_id uuid not null references public.profiles(id),due_date date not null,original_due_date date not null,status text not null default 'PENDIENTE' check(status in ('PENDIENTE','EN_CURSO','BLOQUEADO','EN_REVISION','VERIFICADO','NO_APLICA')),checklist jsonb not null default '[]',evidence text,documents jsonb not null default '[]',period_start date,period_end date,notes text,requested_na boolean not null default false,submitted_by uuid references public.profiles(id),submitted_at timestamptz,reviewed_by uuid references public.profiles(id),reviewed_at timestamptz,review_note text,revision int not null default 1,unique(project_id,step_code));
create table public.sgc_gates(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.sgc_projects(id),gate_code text not null,phase_code text not null,definition jsonb not null,status text not null default 'PENDIENTE' check(status in ('PENDIENTE','EN_REVISION','APROBADA','DEVUELTA')),evidence text,submitted_by uuid references public.profiles(id),reviewed_by uuid references public.profiles(id),reviewed_at timestamptz,review_note text,revision int not null default 1,unique(project_id,gate_code));
create table public.sgc_history(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.sgc_projects(id),record_type text not null,record_id uuid not null,action text not null,actor_id uuid not null references public.profiles(id),changed_at timestamptz not null default now(),before_data jsonb,after_data jsonb not null);
create index sgc_projects_branch_idx on public.sgc_projects(branch_id,id);
create index sgc_members_user_idx on public.sgc_members(user_id,project_id);
create index sgc_steps_owner_idx on public.sgc_steps(owner_id,due_date,id);
create index sgc_history_project_idx on public.sgc_history(project_id,changed_at,id);
-- Read-only tables for clients. All mutations use the single checked, atomic API.
do $$declare t text;begin foreach t in array array['sgc_blueprints','sgc_projects','sgc_members','sgc_steps','sgc_gates','sgc_history'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select on public.%I to authenticated',t);end loop;end$$;
alter table public.sgc_blueprints enable row level security;
alter table public.sgc_projects enable row level security;
alter table public.sgc_members enable row level security;
alter table public.sgc_steps enable row level security;
alter table public.sgc_gates enable row level security;
alter table public.sgc_history enable row level security;
create policy sgc_blueprint_read on public.sgc_blueprints for select to authenticated using((select public.wf_active_actor()) and (select public.has_permission('QUALITY_VIEW')));
create policy sgc_project_read on public.sgc_projects for select to authenticated using((select public.wf_active_actor()) and (select public.has_permission('QUALITY_VIEW')) and public.can_access_branch(branch_id));
do $$declare t text;begin foreach t in array array['sgc_members','sgc_steps','sgc_gates','sgc_history'] loop execute format('create policy sgc_child_read on public.%I for select to authenticated using((select public.wf_active_actor()) and (select public.has_permission(''QUALITY_VIEW'')) and exists(select 1 from public.sgc_projects p where p.id=project_id))',t);end loop;end$$;
insert into public.app_module_catalog(route_key,title,group_name,permission_code) values('sgcimplementation','Implementar el SGC','CALIDAD Y SEGURIDAD','QUALITY_VIEW');
insert into public.role_module_access(role_id,route_key,enabled) select r.id,'sgcimplementation',coalesce((select enabled from public.role_module_access m where m.role_id=r.id and route_key='quality'),false) from public.roles r;
insert into public.sgc_blueprints values('HC-SGC-IMP-1.0','1.0',$blueprint${
  "code": "HC-SGC-IMP-1.0",
  "version": "1.0",
  "title": "Ruta de implementación del SGC HemoCura",
  "source": "HC-SGC-MC-01 v2: MC-11, MC-14 y MC-15; adaptación operativa propuesta",
  "phases": [
    {
      "code": "F0",
      "title": "Decisión, alcance y gobernanza",
      "target_month": 1,
      "steps": [
        {
          "code": "GOV1",
          "title": "Compromiso de la Dirección y política de calidad",
          "source_route": "management",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Formalizar el mandato, objetivos iniciales, patrocinio y recursos; someter el documento a aprobación.",
          "criteria": [
            "Acta y política con código y versión",
            "Patrocinador y recursos identificados",
            "Aprobación documentada y difusión prevista"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        },
        {
          "code": "GOV2",
          "title": "Responsables, imparcialidad y segregación de funciones",
          "source_route": "documents",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Definir responsable de Calidad, dirección técnica, operaciones y suplencias; separar decisiones comerciales y técnicas.",
          "criteria": [
            "Organigrama y funciones por puesto",
            "Delegaciones técnicas y suplencias por escrito",
            "Conflictos de interés y líneas de reporte evaluados"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        },
        {
          "code": "GOV3",
          "title": "Alcance real por sucursal y servicio",
          "source_route": "documents",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Precisar qué procesos y servicios se incluyen en esta sucursal; justificar exclusiones y decidir el alcance de servicios adicionales.",
          "criteria": [
            "Sucursal y servicios reales identificados",
            "Procesos incluidos y excluidos justificados",
            "Responsables técnicos validaron el alcance"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        },
        {
          "code": "GOV4",
          "title": "Matriz legal, habilitaciones y esquema aplicable",
          "source_route": "compliance",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Solicitar validación jurídica de fuentes oficiales, vigencia, habilitación, protección de datos y requisitos del organismo evaluador; no tratar propuestas de ley como obligaciones vigentes.",
          "criteria": [
            "Fuentes oficiales, fecha y responsable de consulta",
            "Requisitos legales y referencias voluntarias separados",
            "Dictamen o validación de aplicabilidad y pendientes registrados"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        },
        {
          "code": "GOV5",
          "title": "Plan, recursos, presupuesto y riesgos del proyecto",
          "source_route": "management",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Planificar con cotizaciones reales, dedicación disponible, fechas y presupuesto por fase. El horizonte es ajustable y no garantiza acreditación.",
          "criteria": [
            "Cronograma y recursos por fase",
            "Presupuesto respaldado por cotizaciones o aprobación",
            "Riesgos del proyecto y decisiones de financiación registrados"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        },
        {
          "code": "GOV6",
          "title": "Lanzamiento y comunicación del proyecto",
          "source_route": "areaagenda",
          "document_required": false,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Comunicar responsabilidades y mecanismos de reporte al personal incluido en el alcance.",
          "criteria": [
            "Audiencias y responsables definidos",
            "Registro de presentación y comprensión",
            "Canal de dudas, reporte y seguimiento establecido"
          ],
          "deliverable": "Registro verificable y conclusión documentada"
        }
      ]
    },
    {
      "code": "F1",
      "title": "Diagnóstico y priorización",
      "target_month": 3,
      "steps": [
        {
          "code": "DIA1",
          "title": "Inventario documental y registros existentes",
          "source_route": "documents",
          "document_required": false,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Identificar versiones, propietarios, ubicaciones, estado de aprobación y registros faltantes sin asumir que un archivo equivale a cumplimiento.",
          "criteria": [
            "Lista maestra levantada",
            "Versiones y estado verificados",
            "Brechas y duplicados identificados"
          ],
          "deliverable": "Registro verificable y conclusión documentada"
        },
        {
          "code": "DIA2",
          "title": "Habilitación, infraestructura y bioseguridad",
          "source_route": "compliance",
          "document_required": false,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Verificar certificados, vencimientos, exequátur/delegaciones cuando apliquen y condiciones de infraestructura contra requisitos validados.",
          "criteria": [
            "Certificados y fechas comprobados",
            "Responsables de renovación asignados",
            "Hallazgos de infraestructura y bioseguridad registrados"
          ],
          "deliverable": "Registro verificable y conclusión documentada"
        },
        {
          "code": "DIA3",
          "title": "Equipos, reactivos y metrología",
          "source_route": "resources",
          "document_required": false,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Levantar equipos críticos, mantenimiento, calibración, reactivos y condiciones de conservación.",
          "criteria": [
            "Inventario con identificación y criticidad",
            "Certificados y vencimientos verificados",
            "Equipos y materiales no conformes segregados o tratados"
          ],
          "deliverable": "Registro verificable y conclusión documentada"
        },
        {
          "code": "DIA4",
          "title": "Diagnóstico de información y trazabilidad",
          "source_route": "bloodflow",
          "document_required": false,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Reconstruir casos de prueba autorizados de trazabilidad; evaluar accesos, respaldo y recuperación sin copiar datos personales al proyecto.",
          "criteria": [
            "Casos de prueba referenciados en repositorio autorizado",
            "Brechas y recuperación evaluadas",
            "Conclusión técnica y plan registrados"
          ],
          "deliverable": "Registro verificable y conclusión documentada"
        },
        {
          "code": "DIA5",
          "title": "Análisis de brechas y prioridades",
          "source_route": "quality",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Comparar la situación real con el alcance y requisitos validados. Clasificar por seguridad, urgencia y recursos.",
          "criteria": [
            "Requisito y fuente identificados",
            "Evidencia y brecha por proceso",
            "Plan priorizado con responsable y plazo"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        },
        {
          "code": "DIA6",
          "title": "Riesgos y criterios de aceptación",
          "source_route": "quality",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Evaluar riesgos inherentes y residuales; someter criterios de aceptación a la Dirección y asignar tratamientos.",
          "criteria": [
            "Criterios aprobados de evaluación y aceptación",
            "Registro de riesgos con controles y residual",
            "Tratamientos, responsables y fechas definidos"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        },
        {
          "code": "DIA7",
          "title": "Mapa de procesos, interacción y propietarios",
          "source_route": "documents",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Definir entradas, salidas, controles, recursos e indicadores de cada proceso crítico del alcance.",
          "criteria": [
            "Mapa e interacciones aprobados",
            "Fichas de procesos críticos disponibles",
            "Propietarios y criterios de aceptación definidos"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        }
      ]
    },
    {
      "code": "F2",
      "title": "Construcción documental y técnica",
      "target_month": 8,
      "steps": [
        {
          "code": "DOC1",
          "title": "Control de documentos y registros",
          "source_route": "documents",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Establecer elaboración, revisión, aprobación, publicación, cambios, retiro y retención. Mantener disponibles las versiones vigentes.",
          "criteria": [
            "Codificación, lista maestra y control de versiones",
            "Aprobaciones y retiro de copias obsoletas",
            "Retención, integridad, acceso y recuperación de registros"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        },
        {
          "code": "DOC2",
          "title": "Procedimientos de gestión del SGC",
          "source_route": "documents",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Preparar el conjunto de procedimientos de NC/CAPA, auditorías, revisión por Dirección, riesgos, quejas y seguimiento.",
          "criteria": [
            "Procedimientos aplicables completos y aprobados",
            "Formularios y criterios de aceptación asociados",
            "Responsables y escalamiento definidos"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        },
        {
          "code": "DOC3",
          "title": "POE de donación y cadena de hemocomponentes",
          "source_route": "documents",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Documentar los procesos aplicables de selección, identificación, colecta, procesamiento, tamizaje, cuarentena, liberación, conservación, despacho y transporte.",
          "criteria": [
            "POE del alcance con criterios y registros",
            "Autoridad de liberación y segregación definidas",
            "Trazabilidad y manejo de producto no conforme previstos"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        },
        {
          "code": "DOC4",
          "title": "Métodos analíticos y control de calidad",
          "source_route": "analyticalqc",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Verificar o validar métodos según aplicabilidad; definir controles, reglas de aceptación, investigación y participación externa.",
          "criteria": [
            "Informes técnicos y criterios aprobados",
            "Control interno y tratamiento de resultados no conformes",
            "Programa de evaluación externa y responsables"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        },
        {
          "code": "DOC5",
          "title": "Cadena de frío, instalaciones y bioseguridad",
          "source_route": "coldchain",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Documentar conservación, transporte, alarmas, excursiones, limpieza, residuos y respuesta ante contingencias.",
          "criteria": [
            "Condiciones y criterios técnicos aprobados",
            "Mapeo/verificación y respuesta a excursiones",
            "Procedimientos de bioseguridad y residuos validados"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        },
        {
          "code": "DOC6",
          "title": "Proveedores, compras y recepción",
          "source_route": "suppliers",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Definir homologación y evaluación de proveedores críticos, especificaciones de compra y aceptación de lotes al recibir.",
          "criteria": [
            "Proveedores críticos y especificaciones",
            "Criterios de cantidad, lote, vencimiento y condición",
            "Rechazo, cuarentena y seguimiento previstos"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        },
        {
          "code": "DOC7",
          "title": "Programa de capacitación y matriz de competencias",
          "source_route": "competencies",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Adaptar HC-TRN-SUITE-001 a puestos y POE; definir evaluación práctica, autorización nominal y reevaluación.",
          "criteria": [
            "Matriz puesto–tarea–competencia aprobada",
            "Plan N1 a N6 o equivalencia justificada",
            "Criterios, evaluadores y vigencias definidos"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        },
        {
          "code": "DOC8",
          "title": "Información, privacidad y continuidad",
          "source_route": "continuity",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Definir acceso por responsabilidad, respaldo probado, recuperación, confidencialidad y continuidad del servicio.",
          "criteria": [
            "Matriz de acceso y confidencialidad",
            "Prueba de respaldo y recuperación planificada",
            "Contingencias, responsables y comunicación"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        },
        {
          "code": "DOC9",
          "title": "Quejas, hemovigilancia y retirada",
          "source_route": "hemovigilance",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Definir notificación, investigación, respuesta y seguimiento de eventos, quejas y retirada/look-back según el alcance y la normativa validada.",
          "criteria": [
            "Canales, responsabilidades y tiempos definidos",
            "Trazabilidad e investigación de eventos previstas",
            "Comunicación y criterio de cierre documentados"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        }
      ]
    },
    {
      "code": "F3",
      "title": "Capacitación y puesta en práctica",
      "target_month": 13,
      "steps": [
        {
          "code": "IMP1",
          "title": "Inducción, documentación y difusión",
          "source_route": "training",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Ejecutar formación N1 a N3 y capacitación en las versiones aprobadas aplicables; usar el módulo de capacitación para los expedientes individuales.",
          "criteria": [
            "Personal incluido en el alcance identificado",
            "Evaluaciones y difusión por versión referenciadas",
            "Brechas de aprendizaje y seguimiento documentados"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        },
        {
          "code": "IMP2",
          "title": "Competencia práctica y autorización por tarea",
          "source_route": "competencies",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Ejecutar formación específica N4/N5, observar desempeño y registrar autorización nominal; asistencia no equivale a competencia.",
          "criteria": [
            "Evaluación teórico-práctica por tarea",
            "Evaluador competente y evidencia verificable",
            "Autorización y vencimiento registrados en el módulo correspondiente"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        },
        {
          "code": "IMP3",
          "title": "Control interno y participación externa operativos",
          "source_route": "analyticalqc",
          "document_required": false,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Poner en marcha controles con criterios de aceptación; registrar decisiones y participación externa real.",
          "criteria": [
            "Registros de controles y decisiones",
            "Desviaciones investigadas y referenciadas",
            "Participación externa con identificación del programa"
          ],
          "deliverable": "Registro verificable y conclusión documentada"
        },
        {
          "code": "IMP4",
          "title": "Uso real de procedimientos y registros",
          "source_route": "quality",
          "document_required": false,
          "minimum_months": 1,
          "optional": false,
          "instructions": "Verificar uso real en punto de trabajo durante al menos un mes calendario incluido en el alcance.",
          "criteria": [
            "Período de registros reales identificado",
            "Muestreo por proceso y personal",
            "Desviaciones, acciones y conclusión de aplicación"
          ],
          "deliverable": "Registro verificable y conclusión documentada"
        },
        {
          "code": "IMP5",
          "title": "Ciclo de no conformidad y CAPA",
          "source_route": "quality",
          "document_required": false,
          "minimum_months": 0,
          "optional": true,
          "instructions": "Referenciar casos reales y su eficacia. Si no hubo eventos, justificar la no aplicabilidad del caso real; un ejercicio debe identificarse como tal y no contarse como una NC real.",
          "criteria": [
            "Origen y acciones trazables",
            "Evidencia de ejecución y revisión independiente",
            "Conclusión de eficacia o justificación de ausencia de casos reales"
          ],
          "deliverable": "Registro verificable y conclusión documentada"
        },
        {
          "code": "IMP6",
          "title": "Recepción y trazabilidad de insumos",
          "source_route": "suppliers",
          "document_required": false,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Muestrear recepciones reales y comprobar cantidades, precios cuando proceda, lotes, vencimientos y condiciones contra lo solicitado.",
          "criteria": [
            "Recepciones y lotes referenciados",
            "Condiciones y aceptación documentadas",
            "Incumplimientos gestionados con el proveedor"
          ],
          "deliverable": "Registro verificable y conclusión documentada"
        },
        {
          "code": "IMP7",
          "title": "Comunicación, quejas y reporte de eventos",
          "source_route": "hemovigilance",
          "document_required": false,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Comprobar canales de comunicación y respuesta; si no hubo casos, documentar verificación del canal sin inventar eventos.",
          "criteria": [
            "Canales accesibles y responsables conocidos",
            "Registro real o prueba explícitamente identificada",
            "Respuesta y seguimiento comprobados"
          ],
          "deliverable": "Registro verificable y conclusión documentada"
        },
        {
          "code": "IMP8",
          "title": "Verificación del despliegue en el alcance",
          "source_route": "quality",
          "document_required": false,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Comprobar consistencia entre turnos y áreas de esta sucursal; para otras sedes, usar sus proyectos y consolidar la cartera.",
          "criteria": [
            "Muestreo representativo documentado",
            "Versiones vigentes en puntos de uso",
            "Brechas por área y turno con responsable"
          ],
          "deliverable": "Registro verificable y conclusión documentada"
        }
      ]
    },
    {
      "code": "F4",
      "title": "Verificación y eficacia",
      "target_month": 18,
      "steps": [
        {
          "code": "VER1",
          "title": "Serie de indicadores y línea base",
          "source_route": "quality",
          "document_required": false,
          "minimum_months": 6,
          "optional": false,
          "instructions": "Reunir al menos seis meses calendario de registros e indicadores con denominador, fuente y alcance. Fijar metas con datos reales y aprobación.",
          "criteria": [
            "Serie y período de seis meses trazables",
            "Fórmulas, denominadores y datos incompletos identificados",
            "Análisis de tendencias y decisiones documentados"
          ],
          "deliverable": "Registro verificable y conclusión documentada"
        },
        {
          "code": "VER2",
          "title": "Evaluación externa y desempeño técnico",
          "source_route": "analyticalqc",
          "document_required": false,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Revisar al menos un ciclo externo aplicable; identificar resultados y tratamiento de desviaciones.",
          "criteria": [
            "Informe del programa y ciclo referenciado",
            "Resultados comparados contra criterio aplicable",
            "Investigación y seguimiento de desviaciones"
          ],
          "deliverable": "Registro verificable y conclusión documentada"
        },
        {
          "code": "VER3",
          "title": "Auditoría interna independiente",
          "source_route": "internalaudits",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Ejecutar el programa sobre procesos críticos con auditores competentes e independientes de lo auditado.",
          "criteria": [
            "Programa, criterios, alcance y muestreo",
            "Competencia e independencia del equipo auditor",
            "Informe y hallazgos referenciados"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        },
        {
          "code": "VER4",
          "title": "Cierre de hallazgos y eficacia CAPA",
          "source_route": "quality",
          "document_required": false,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Revisar los hallazgos y acciones críticos; no confundir ejecución con eficacia ni declarar cierres desde el proyecto.",
          "criteria": [
            "Hallazgos vinculados a expedientes de origen",
            "Acciones críticas resueltas y eficacia comprobada",
            "Pendientes residuales y decisión registrados"
          ],
          "deliverable": "Registro verificable y conclusión documentada"
        },
        {
          "code": "VER5",
          "title": "Pruebas de trazabilidad y continuidad",
          "source_route": "continuity",
          "document_required": false,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Ejecutar escenarios autorizados de reconstrucción, retirada, excursión y recuperación; registrar resultados sin datos personales.",
          "criteria": [
            "Escenarios y criterios de aceptación",
            "Resultados, fallos y acciones",
            "Revisión de riesgos y planes de contingencia"
          ],
          "deliverable": "Registro verificable y conclusión documentada"
        },
        {
          "code": "VER6",
          "title": "Reevaluación de competencias y autorizaciones",
          "source_route": "competencies",
          "document_required": false,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Comprobar vigencias, cambios de POE y reevaluación del personal incluido en el alcance.",
          "criteria": [
            "Matriz actualizada y vencimientos",
            "Reevaluación ante cambios o desempeño",
            "Autorizaciones restringidas o renovadas con evidencia"
          ],
          "deliverable": "Registro verificable y conclusión documentada"
        },
        {
          "code": "VER7",
          "title": "Informe de suficiencia y pendientes",
          "source_route": "quality",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Consolidar evidencia de aplicación, riesgos residuales y pendientes antes de la revisión gerencial.",
          "criteria": [
            "Matriz requisito–proceso–riesgo–control–registro",
            "Pendientes y riesgos residuales explícitos",
            "Conclusión sustentada y recomendación gerencial"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        }
      ]
    },
    {
      "code": "F5",
      "title": "Revisión, preparación externa y sostenimiento",
      "target_month": 24,
      "steps": [
        {
          "code": "DIR1",
          "title": "Revisión por la Dirección",
          "source_route": "management",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Registrar entradas, resultados, decisiones, recursos, responsables y plazos en Revisión por la Dirección.",
          "criteria": [
            "Acta y entradas de revisión",
            "Decisiones y recursos justificados",
            "Compromisos registrados y responsables informados"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        },
        {
          "code": "DIR2",
          "title": "Resolución de brechas críticas",
          "source_route": "quality",
          "document_required": false,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Confirmar resolución de hallazgos críticos y riesgos no aceptables antes de declarar preparación.",
          "criteria": [
            "Revisión de hallazgos y riesgos críticos",
            "Evidencias de cierre en los módulos de origen",
            "Restricciones y decisiones de continuar documentadas"
          ],
          "deliverable": "Registro verificable y conclusión documentada"
        },
        {
          "code": "DIR3",
          "title": "Preparación para evaluación externa",
          "source_route": "compliance",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Confirmar esquema y requisitos actuales con el organismo competente; preparar expediente y preevaluación sin declarar acreditación.",
          "criteria": [
            "Alcance y esquema confirmados por fuente competente",
            "Expediente y lista de requisitos revisados",
            "Conclusión de preparación y pendientes documentados"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        },
        {
          "code": "DIR4",
          "title": "Solicitud y evaluación externa, si se decide",
          "source_route": "documents",
          "document_required": false,
          "minimum_months": 0,
          "optional": true,
          "instructions": "Si está incluida en el alcance, registrar solicitud y evaluación. Su aceptación depende del organismo externo, no del sistema.",
          "criteria": [
            "Decisión de solicitar y alcance",
            "Acuse y expediente o justificación de exclusión",
            "Informe del evaluador cuando corresponda"
          ],
          "deliverable": "Registro verificable y conclusión documentada"
        },
        {
          "code": "DIR5",
          "title": "Atención de observaciones externas",
          "source_route": "quality",
          "document_required": false,
          "minimum_months": 0,
          "optional": true,
          "instructions": "Si hubo evaluación, referenciar observaciones y evidencias aceptadas; no marcar aceptación externa sin respaldo.",
          "criteria": [
            "Observaciones vinculadas al expediente externo",
            "Respuestas y evidencias presentadas",
            "Aceptación del organismo o pendientes identificados"
          ],
          "deliverable": "Registro verificable y conclusión documentada"
        },
        {
          "code": "DIR6",
          "title": "Plan de mantenimiento y mejora",
          "source_route": "areaagenda",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Programar revisiones, auditorías, indicadores, competencias, documentos, metrología y continuidad con responsables reales.",
          "criteria": [
            "Calendario y frecuencias aprobadas",
            "Responsables y recursos de mantenimiento",
            "Agenda por área planificada y seguimiento establecido"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        },
        {
          "code": "DIR7",
          "title": "Entrega del sistema implementado y lecciones",
          "source_route": "management",
          "document_required": true,
          "minimum_months": 0,
          "optional": false,
          "instructions": "Formalizar la entrega a los dueños de proceso, registrar lecciones y revisar periódicamente el SGC. El cierre del proyecto no otorga acreditación.",
          "criteria": [
            "Acta de entrega y responsabilidades",
            "Lecciones, pendientes y controles de mantenimiento",
            "Aprobación independiente de cierre del proyecto"
          ],
          "deliverable": "Documento aprobado y evidencia de aplicación"
        }
      ]
    }
  ],
  "gates": [
    {
      "code": "G1",
      "phase": "F0",
      "title": "Gobernanza y alcance",
      "steps": [
        "GOV1",
        "GOV2",
        "GOV3",
        "GOV4",
        "GOV5",
        "GOV6"
      ]
    },
    {
      "code": "G2",
      "phase": "F1",
      "title": "Diagnóstico completo",
      "steps": [
        "DIA1",
        "DIA2",
        "DIA3",
        "DIA4"
      ]
    },
    {
      "code": "G3",
      "phase": "F1",
      "title": "Brechas, riesgos y procesos priorizados",
      "steps": [
        "DIA5",
        "DIA6",
        "DIA7"
      ]
    },
    {
      "code": "G4",
      "phase": "F2",
      "title": "Procesos y gestión definidos",
      "steps": [
        "DOC1",
        "DOC2",
        "DOC7"
      ]
    },
    {
      "code": "G5",
      "phase": "F2",
      "title": "Documentación técnica crítica aprobada",
      "steps": [
        "DOC3",
        "DOC4",
        "DOC5",
        "DOC6",
        "DOC8",
        "DOC9"
      ]
    },
    {
      "code": "G6",
      "phase": "F3",
      "title": "Personal capacitado y competente",
      "steps": [
        "IMP1",
        "IMP2"
      ]
    },
    {
      "code": "G7",
      "phase": "F3",
      "title": "Procesos en uso real",
      "steps": [
        "IMP3",
        "IMP4",
        "IMP5",
        "IMP6",
        "IMP7",
        "IMP8"
      ]
    },
    {
      "code": "G8",
      "phase": "F4",
      "title": "Evidencia longitudinal suficiente",
      "steps": [
        "VER1",
        "VER2"
      ]
    },
    {
      "code": "G9",
      "phase": "F4",
      "title": "Auditoría interna realizada",
      "steps": [
        "VER3"
      ]
    },
    {
      "code": "G10",
      "phase": "F4",
      "title": "Eficacia y suficiencia verificadas",
      "steps": [
        "VER4",
        "VER5",
        "VER6",
        "VER7"
      ]
    },
    {
      "code": "G11",
      "phase": "F5",
      "title": "Revisión gerencial y brechas críticas",
      "steps": [
        "DIR1",
        "DIR2"
      ]
    },
    {
      "code": "G12",
      "phase": "F5",
      "title": "Preparación externa y sostenimiento",
      "steps": [
        "DIR3",
        "DIR4",
        "DIR5",
        "DIR6",
        "DIR7"
      ]
    }
  ]
}
$blueprint$::jsonb);
insert into public.document_register(document_code,title,area,document_type,version,status,source_path,notes) values
('HC-SGC-IMP-001','Guía operativa de implementación del SGC','CALIDAD','GUIA_IMPLEMENTACION','1.0-BORRADOR','BORRADOR','docs/recursos/HC-SGC-IMP-001_Guia_Implementacion_SGC.html','Adaptación propuesta al proyecto guiado; requiere revisión y aprobación.'),
('HC-SGC-MC-01','Documento Maestro: adaptación al proyecto guiado','CALIDAD','DOCUMENTO_MAESTRO','3.0-BORRADOR','BORRADOR','docs/recursos/HC-SGC-MC-01_Documento_Maestro_v3_Borrador.html','Se conserva v2 como antecedente; esta adaptación no lo deroga automáticamente.'),
('HC-SGC-ARQ','Arquitectura documental conectada al proyecto','CALIDAD','ARQUITECTURA_DOCUMENTAL','2.0-BORRADOR','BORRADOR','docs/recursos/HC-SGC-ARQ_Arquitectura_v2_Borrador.html','Adaptación propuesta; no acredita emisión de documentos operativos.'),
('HC-CMP-AUD-001','Auditoría Penal + SGC: antecedente con anexo operativo','CALIDAD','REFERENCIA_LEGAL','2.0-REFERENCIA','BORRADOR','docs/recursos/HC-CMP-Auditoria-Penal-SGC-V2.html','Aplicabilidad y vigencia pendientes de validación jurídica competente.'),
('HC-CMP-MC-001','Manual de Compliance Penal: borrador con anexo operativo','CALIDAD','MANUAL_COMPLIANCE','1.0-BORRADOR','BORRADOR','docs/recursos/HC-CMP-MC-001_Manual_Compliance_Penal.md','Aplicabilidad y vigencia pendientes de validación jurídica competente.') on conflict(document_code) do nothing;
update public.document_register set source_path='index.html#training',notes=concat_ws(E'\n',notes,'Integración operativa: HC-SGC-IMP-001, DOC7, IMP1, IMP2 y VER6; conserva su versión y estado documental.') where document_code='HC-TRN-SUITE-001' and source_path='training.html' and status='BORRADOR';
create function private.sgc_docs_valid(docs jsonb,required boolean) returns boolean language sql stable security invoker set search_path=public,pg_temp as $$
 select jsonb_typeof(docs)='array' and (not required or jsonb_array_length(docs)>0) and not exists(select 1 from jsonb_array_elements(docs) x where not exists(select 1 from public.document_register d where d.id=(x->>'id')::uuid and d.version=x->>'version' and d.source_path=x->>'source_path' and d.status in ('APROBADO','VIGENTE') and nullif(trim(d.source_path),'') is not null and exists(select 1 from public.approval_requests ar where ar.id=d.approval_request_id and ar.entity_id=d.id and ar.action_type='DOCUMENT_APPROVAL' and ar.status='EJECUTADA')));
$$;
revoke all on function private.sgc_docs_valid(jsonb,boolean) from public,anon,authenticated;
create function private.sgc_log(p uuid,t text,r uuid,a text,b jsonb,n jsonb) returns void language sql security invoker set search_path=public,pg_temp as $$insert into public.sgc_history(project_id,record_type,record_id,action,actor_id,before_data,after_data) values(p,t,r,a,auth.uid(),b,n)$$;
revoke all on function private.sgc_log(uuid,text,uuid,text,jsonb,jsonb) from public,anon,authenticated;
-- A deliberately privileged writer: client DML is revoked. Every path checks the
-- active identity, existing permission, canonical branch scope and project role.
create function public.sgc_project_action(p_action text,p_data jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare p public.sgc_projects%rowtype;s public.sgc_steps%rowtype;g public.sgc_gates%rowtype;j jsonb;x jsonb;phase jsonb;v uuid;reviewer uuid;owner uuid;doc public.document_register%rowtype;beforej jsonb;is_manager boolean;is_reviewer boolean;today date:=(now() at time zone 'America/Santo_Domingo')::date;all_done boolean;invalid jsonb;min_months int;begin
 if auth.uid() is null or not public.wf_active_actor() or not public.has_permission('QUALITY_VIEW') then raise exception 'Consulta de implementación no autorizada' using errcode='42501';end if;
 if p_action='CREATE' then
  if not public.has_permission('QUALITY_WRITE') or not public.can_access_branch((p_data->>'branch_id')::uuid) then raise exception 'Creación no autorizada' using errcode='42501';end if;
  reviewer:=(p_data->>'reviewer_id')::uuid;
  if reviewer=auth.uid() or not private.work_owner_eligible(auth.uid(),(p_data->>'branch_id')::uuid,'CALIDAD') or not private.work_owner_eligible(reviewer,(p_data->>'branch_id')::uuid,'CALIDAD') then raise exception 'Responsable y revisor deben ser personas activas distintas y elegibles para la sucursal';end if;
  if not exists(select 1 from public.user_roles ur join public.roles r on r.id=ur.role_id where ur.user_id=reviewer and (r.code='SUPER_USUARIO' or exists(select 1 from public.role_permissions rp join public.app_permissions ap on ap.permission_code=rp.permission_code and ap.active where rp.role_id=r.id and rp.permission_code='QUALITY_DAILY_REVIEW'))) then raise exception 'El revisor requiere permiso de revisión de Calidad';end if;
  select definition into j from public.sgc_blueprints where code='HC-SGC-IMP-1.0';
  if nullif(trim(p_data->>'scope'),'') is null or nullif(trim(p_data->>'title'),'') is null or nullif(trim(p_data->>'project_code'),'') is null then raise exception 'Código, título y alcance requeridos';end if;
  insert into public.sgc_projects(project_code,title,branch_id,owner_id,scope,start_date,target_date,blueprint_code,definition) values(trim(p_data->>'project_code'),trim(p_data->>'title'),(p_data->>'branch_id')::uuid,auth.uid(),trim(p_data->>'scope'),(p_data->>'start_date')::date,(p_data->>'target_date')::date,'HC-SGC-IMP-1.0',j) returning * into p;
  insert into public.sgc_members values(p.id,auth.uid(),'RESPONSABLE'),(p.id,reviewer,'REVISOR');
  for phase in select * from jsonb_array_elements(j->'phases') loop for x in select * from jsonb_array_elements(phase->'steps') loop
   insert into public.sgc_steps(project_id,phase_code,step_code,definition,owner_id,due_date,original_due_date,checklist) values(p.id,phase->>'code',x->>'code',x,auth.uid(),least(p.target_date,(p.start_date+make_interval(months=>(phase->>'target_month')::int))::date),least(p.target_date,(p.start_date+make_interval(months=>(phase->>'target_month')::int))::date),(select jsonb_agg(jsonb_build_object('label',c,'done',false)) from jsonb_array_elements_text(x->'criteria') c));
  end loop;end loop;
  for x in select * from jsonb_array_elements(j->'gates') loop insert into public.sgc_gates(project_id,gate_code,phase_code,definition) values(p.id,x->>'code',x->>'phase',x);end loop;
  perform private.sgc_log(p.id,'PROJECT',p.id,p_action,null,to_jsonb(p));return jsonb_build_object('id',p.id);
 end if;
 select * into p from public.sgc_projects where id=(p_data->>'project_id')::uuid for update;
 if p.id is null or not public.can_access_branch(p.branch_id) then raise exception 'Proyecto no autorizado' using errcode='42501';end if;
 is_manager:=p.owner_id=auth.uid() or public.has_role('SUPER_USUARIO');
 is_reviewer:=exists(select 1 from public.sgc_members m where m.project_id=p.id and m.user_id=auth.uid() and m.role='REVISOR') and public.has_permission('QUALITY_DAILY_REVIEW') and private.work_owner_eligible(auth.uid(),p.branch_id,'CALIDAD');
 if p_action='CHECK' then
  select coalesce(jsonb_agg(step_code),'[]') into invalid from public.sgc_steps st where st.project_id=p.id and st.status='VERIFICADO' and (not private.sgc_docs_valid(st.documents,(st.definition->>'document_required')::boolean) or not private.work_owner_eligible(st.owner_id,p.branch_id,'CALIDAD'));
  return jsonb_build_object('invalid_steps',invalid,'scope','Estado documental y elegibilidad actuales; la suficiencia de evidencia requiere revisión humana');
 end if;
 if not public.has_permission('QUALITY_WRITE') then raise exception 'Escritura de implementación no autorizada' using errcode='42501';end if;
 if p.status='CERRADO_VERIFICADO' and p_action<>'REOPEN_PROJECT' then raise exception 'Reabra el proyecto con justificación antes de modificarlo';end if;
 if p_action in ('ADD_MEMBER','SET_REVIEWER','ADD_STEP','REGISTER_DOCUMENT','CLOSE_PROJECT','REOPEN_PROJECT') then
  if not is_manager then raise exception 'Solo el responsable del proyecto puede gestionar esta acción' using errcode='42501';end if;
  if p_action in ('ADD_MEMBER','SET_REVIEWER') then
   owner:=(p_data->>'user_id')::uuid;
   if not private.work_owner_eligible(owner,p.branch_id,'CALIDAD') then raise exception 'Colaborador no elegible';end if;
   if owner=p.owner_id then raise exception 'El responsable conserva su función';end if;
   if p_action='SET_REVIEWER' and not exists(select 1 from public.user_roles ur join public.roles r on r.id=ur.role_id where ur.user_id=owner and (r.code='SUPER_USUARIO' or exists(select 1 from public.role_permissions rp join public.app_permissions ap on ap.permission_code=rp.permission_code and ap.active where rp.role_id=r.id and rp.permission_code='QUALITY_DAILY_REVIEW'))) then raise exception 'Revisor sin permiso de revisión de Calidad';end if;
   select to_jsonb(m) into beforej from public.sgc_members m where m.project_id=p.id and m.user_id=owner;
   insert into public.sgc_members values(p.id,owner,case when p_action='SET_REVIEWER' then 'REVISOR' else 'COLABORADOR' end) on conflict(project_id,user_id) do update set role=excluded.role;perform private.sgc_log(p.id,'MEMBER',owner,p_action,beforej,p_data);return jsonb_build_object('id',owner);
  elsif p_action='ADD_STEP' then
   if not exists(select 1 from jsonb_array_elements(p.definition->'phases') ph where ph->>'code'=p_data->>'phase_code') or coalesce(p_data->>'step_code','') !~ '^X-[A-Z0-9-]{1,30}$' or nullif(trim(p_data->>'title'),'') is null or nullif(trim(p_data->>'instructions'),'') is null then raise exception 'Fase, código X-, título e instrucciones requeridos';end if;
   if jsonb_typeof(p_data->'criteria') is distinct from 'array' or jsonb_array_length(p_data->'criteria') not between 1 and 10 or exists(select 1 from jsonb_array_elements_text(p_data->'criteria') c where nullif(trim(c),'') is null) then raise exception 'Registre entre 1 y 10 criterios de aceptación';end if;
   owner:=(p_data->>'owner_id')::uuid;
   if not exists(select 1 from public.sgc_members where project_id=p.id and user_id=owner and role<>'REVISOR') or not private.work_owner_eligible(owner,p.branch_id,'CALIDAD') then raise exception 'Responsable no elegible';end if;
   x:=jsonb_build_object('code',p_data->>'step_code','title',trim(p_data->>'title'),'instructions',trim(p_data->>'instructions'),'source_route','quality','document_required',coalesce((p_data->>'document_required')::boolean,false),'minimum_months',0,'optional',false,'criteria',p_data->'criteria','deliverable','Entregable específico del alcance con evidencia verificable');
   insert into public.sgc_steps(project_id,phase_code,step_code,definition,owner_id,due_date,original_due_date,checklist) values(p.id,p_data->>'phase_code',p_data->>'step_code',x,owner,(p_data->>'due_date')::date,(p_data->>'due_date')::date,(select jsonb_agg(jsonb_build_object('label',c,'done',false)) from jsonb_array_elements_text(p_data->'criteria') c)) returning * into s;
   select * into g from public.sgc_gates where project_id=p.id and phase_code=p_data->>'phase_code' order by substring(gate_code from 2)::int desc limit 1 for update;
   beforej:=to_jsonb(g);update public.sgc_gates set definition=jsonb_set(definition,'{steps}',(definition->'steps')||jsonb_build_array(s.step_code)),revision=revision+1 where id=g.id returning * into g;perform private.sgc_log(p.id,'GATE',g.id,'ADD_REQUIRED_STEP',beforej,to_jsonb(g));
   for g in select * from public.sgc_gates where project_id=p.id and phase_code>=s.phase_code for update loop j:=to_jsonb(g);update public.sgc_gates set status='PENDIENTE',submitted_by=null,reviewed_by=null,reviewed_at=null,review_note=null,revision=revision+1 where id=g.id returning * into g;perform private.sgc_log(p.id,'GATE',g.id,'INVALIDATED_BY_ADDED_STEP',j,to_jsonb(g));end loop;
   perform private.sgc_log(p.id,'STEP',s.id,p_action,null,to_jsonb(s));return jsonb_build_object('id',s.id);
  elsif p_action='REGISTER_DOCUMENT' then
   if not public.has_permission('DOCUMENTS_WRITE') then raise exception 'Permiso documental requerido' using errcode='42501';end if;
   if nullif(trim(p_data->>'document_code'),'') is null or nullif(trim(p_data->>'title'),'') is null or nullif(trim(p_data->>'version'),'') is null or nullif(trim(p_data->>'document_type'),'') is null then raise exception 'Metadatos documentales requeridos';end if;
   if nullif(trim(p_data->>'source_path'),'') is null or p_data->>'source_path' !~ '^(https://|docs/recursos/)' then raise exception 'Use URL HTTPS o ruta docs/recursos/ del entregable';end if;
   insert into public.document_register(document_code,title,area,document_type,version,status,owner_user_id,source_path,notes) values(trim(p_data->>'document_code'),trim(p_data->>'title'),'CALIDAD',trim(p_data->>'document_type'),trim(p_data->>'version'),'BORRADOR',auth.uid(),trim(p_data->>'source_path'),'Entregable del proyecto '||p.project_code) returning * into doc;
   perform private.sgc_log(p.id,'DOCUMENT',doc.id,p_action,null,to_jsonb(doc));return jsonb_build_object('id',doc.id);
  elsif p_action='REOPEN_PROJECT' then
   if nullif(trim(p_data->>'note'),'') is null then raise exception 'Justifique la reapertura';end if;
   beforej:=to_jsonb(p);update public.sgc_projects set status='EN_CURSO',revision=revision+1 where id=p.id returning * into p;perform private.sgc_log(p.id,'PROJECT',p.id,p_action,beforej,to_jsonb(p)||jsonb_build_object('reason',p_data->>'note'));return jsonb_build_object('id',p.id);
  else
   if nullif(trim(p_data->>'note'),'') is null then raise exception 'Conclusión de cierre requerida';end if;
   if exists(select 1 from public.sgc_gates where project_id=p.id and status<>'APROBADA') or exists(select 1 from public.sgc_steps st where st.project_id=p.id and st.status='VERIFICADO' and (not private.sgc_docs_valid(st.documents,(st.definition->>'document_required')::boolean) or not private.work_owner_eligible(st.owner_id,p.branch_id,'CALIDAD'))) then raise exception 'Complete puertas y resuelva evidencias documentales desactualizadas';end if;
   beforej:=to_jsonb(p);update public.sgc_projects set status='CERRADO_VERIFICADO',revision=revision+1 where id=p.id returning * into p;perform private.sgc_log(p.id,'PROJECT',p.id,p_action,beforej,to_jsonb(p)||jsonb_build_object('conclusion',p_data->>'note'));return jsonb_build_object('id',p.id);
  end if;
 end if;
 if p_action in ('GATE_SUBMIT','GATE_APPROVE') and exists(select 1 from public.sgc_steps st where st.project_id=p.id and st.status='VERIFICADO' and (not private.sgc_docs_valid(st.documents,(st.definition->>'document_required')::boolean) or not private.work_owner_eligible(st.owner_id,p.branch_id,'CALIDAD'))) then raise exception 'Hay evidencias o responsables desactualizados; reabra y revise los pasos afectados';end if;
 if p_action in ('GATE_SUBMIT','GATE_APPROVE','GATE_RETURN') then
  select * into g from public.sgc_gates where id=(p_data->>'id')::uuid and project_id=p.id for update;
  if g.id is null or g.revision is distinct from (p_data->>'revision')::int then raise exception 'La puerta cambió; actualice';end if;
  beforej:=to_jsonb(g);
  if p_action='GATE_SUBMIT' then
   if not is_manager or g.status='APROBADA' then raise exception 'Envío de puerta no autorizado';end if;
   if exists(select 1 from public.sgc_gates xg where xg.project_id=p.id and substring(xg.gate_code from 2)::int<substring(g.gate_code from 2)::int and xg.status<>'APROBADA') then raise exception 'Primero complete las puertas anteriores';end if;
   if exists(select 1 from public.sgc_steps st where st.project_id=p.id and (g.definition->'steps') ? st.step_code and (st.status not in ('VERIFICADO','NO_APLICA') or st.status='VERIFICADO' and not private.sgc_docs_valid(st.documents,(st.definition->>'document_required')::boolean))) or not exists(select 1 from public.sgc_steps st where st.project_id=p.id and (g.definition->'steps') ? st.step_code and st.status='VERIFICADO') then raise exception 'Los entregables requeridos deben estar verificados y vigentes';end if;
   if nullif(trim(p_data->>'evidence'),'') is null then raise exception 'Referencia del expediente de decisión requerida';end if;
   update public.sgc_gates set status='EN_REVISION',evidence=trim(p_data->>'evidence'),submitted_by=auth.uid(),reviewed_by=null,reviewed_at=null,review_note=null,revision=revision+1 where id=g.id returning * into g;
  else
   if not is_reviewer or auth.uid()=g.submitted_by or auth.uid()=p.owner_id or g.status<>'EN_REVISION' or nullif(trim(p_data->>'note'),'') is null then raise exception 'Revisión independiente y observación requeridas';end if;
   if p_action='GATE_APPROVE' and exists(select 1 from public.sgc_steps st where st.project_id=p.id and (g.definition->'steps') ? st.step_code and (st.status not in ('VERIFICADO','NO_APLICA') or st.status='VERIFICADO' and not private.sgc_docs_valid(st.documents,(st.definition->>'document_required')::boolean))) then raise exception 'Revise los entregables actualizados antes de aprobar';end if;
   update public.sgc_gates set status=case when p_action='GATE_APPROVE' then 'APROBADA' else 'DEVUELTA' end,reviewed_by=auth.uid(),reviewed_at=now(),review_note=trim(p_data->>'note'),revision=revision+1 where id=g.id returning * into g;
  end if;
  perform private.sgc_log(p.id,'GATE',g.id,p_action,beforej,to_jsonb(g));return jsonb_build_object('id',g.id);
 end if;
 select * into s from public.sgc_steps where id=(p_data->>'id')::uuid and project_id=p.id for update;
 if s.id is null or s.revision is distinct from (p_data->>'revision')::int then raise exception 'El paso cambió; actualice antes de guardar';end if;
 beforej:=to_jsonb(s);
 if p_action in ('PLAN','REOPEN_STEP') then
  if not is_manager or nullif(trim(p_data->>'note'),'') is null then raise exception 'Responsable del proyecto y justificación requeridos';end if;
  if p_action='PLAN' then
   if s.status in ('VERIFICADO','NO_APLICA','EN_REVISION') then raise exception 'Reabra el paso antes de replanificar';end if;
   owner:=(p_data->>'owner_id')::uuid;if not exists(select 1 from public.sgc_members where project_id=p.id and user_id=owner and role<>'REVISOR') or not private.work_owner_eligible(owner,p.branch_id,'CALIDAD') then raise exception 'Responsable no elegible';end if;
   update public.sgc_steps set owner_id=owner,due_date=(p_data->>'due_date')::date,notes=trim(p_data->>'note'),status='PENDIENTE',evidence=null,documents='[]',period_start=null,period_end=null,requested_na=false,submitted_by=null,submitted_at=null,reviewed_by=null,reviewed_at=null,review_note=null,checklist=(select jsonb_agg(jsonb_build_object('label',c,'done',false)) from jsonb_array_elements_text(s.definition->'criteria') c),revision=revision+1 where id=s.id returning * into s;
  else
   update public.sgc_steps set status='EN_CURSO',submitted_by=null,submitted_at=null,reviewed_by=null,reviewed_at=null,review_note=null,notes=trim(p_data->>'note'),revision=revision+1 where id=s.id returning * into s;
  end if;
  -- Reopening/replanning invalidates this and all subsequent gates, preserving history.
  for g in select * from public.sgc_gates where project_id=p.id and substring(gate_code from 2)::int >= (select min(substring(gg.gate_code from 2)::int) from public.sgc_gates gg where gg.project_id=p.id and (gg.definition->'steps') ? s.step_code) for update loop
   j:=to_jsonb(g);update public.sgc_gates set status='PENDIENTE',reviewed_by=null,reviewed_at=null,submitted_by=null,review_note=null,revision=revision+1 where id=g.id returning * into g;perform private.sgc_log(p.id,'GATE',g.id,'INVALIDATED_BY_STEP',j,to_jsonb(g));
  end loop;
 elsif p_action in ('SAVE','SUBMIT','BLOCK','REQUEST_NA') then
  if s.owner_id<>auth.uid() or not exists(select 1 from public.sgc_members where project_id=p.id and user_id=auth.uid()) or not private.work_owner_eligible(auth.uid(),p.branch_id,'CALIDAD') or s.status in ('VERIFICADO','NO_APLICA','EN_REVISION') then raise exception 'Solo el responsable activo ejecuta un paso abierto';end if;
  if jsonb_typeof(coalesce(p_data->'documents','[]')) is distinct from 'array' or jsonb_array_length(coalesce(p_data->'documents','[]'))>20 then raise exception 'Vínculos documentales inválidos';end if;
  if p_action='REQUEST_NA' and not (s.definition->>'optional')::boolean then raise exception 'Este paso obligatorio no admite exclusión';end if;
  if jsonb_typeof(p_data->'checklist') is distinct from 'array' or jsonb_array_length(p_data->'checklist')<>jsonb_array_length(s.definition->'criteria') then raise exception 'Lista de comprobación inválida';end if;
  if exists(select 1 from jsonb_array_elements(p_data->'checklist') with ordinality c(value,n) where c.value->>'label' is distinct from s.definition->'criteria'->>((c.n-1)::int) or jsonb_typeof(c.value->'done') is distinct from 'boolean') then raise exception 'No altere los criterios del paso';end if;
  if p_action in ('SUBMIT','REQUEST_NA','BLOCK') and nullif(trim(p_data->>'evidence'),'') is null then raise exception 'Registre evidencia o justificación del bloqueo/exclusión';end if;
  if p_action='SUBMIT' then
   if exists(select 1 from public.sgc_gates where project_id=p.id and phase_code<s.phase_code and status<>'APROBADA') then raise exception 'Complete las puertas de fases anteriores antes de presentar el paso';end if;
   if exists(select 1 from jsonb_array_elements(p_data->'checklist') c where c->>'done'<>'true') or not private.sgc_docs_valid(coalesce(p_data->'documents','[]'),(s.definition->>'document_required')::boolean) then raise exception 'Complete criterios y vincule documentos aprobados en su versión vigente';end if;
   min_months:=(s.definition->>'minimum_months')::int;
   if min_months>0 and (nullif(p_data->>'period_start','') is null or nullif(p_data->>'period_end','') is null or (p_data->>'period_end')::date>today or (p_data->>'period_end')::date+1<((p_data->>'period_start')::date+make_interval(months=>min_months))::date) then raise exception 'Registros reales insuficientes: período mínimo % meses calendario',min_months;end if;
  end if;
  update public.sgc_steps set checklist=p_data->'checklist',evidence=nullif(trim(p_data->>'evidence'),''),documents=coalesce(p_data->'documents','[]'),period_start=nullif(p_data->>'period_start','')::date,period_end=nullif(p_data->>'period_end','')::date,notes=nullif(trim(p_data->>'notes'),''),requested_na=p_action='REQUEST_NA',status=case when p_action in ('SUBMIT','REQUEST_NA') then 'EN_REVISION' when p_action='BLOCK' then 'BLOQUEADO' else 'EN_CURSO' end,submitted_by=case when p_action in ('SUBMIT','REQUEST_NA') then auth.uid() end,submitted_at=case when p_action in ('SUBMIT','REQUEST_NA') then now() end,reviewed_by=null,reviewed_at=null,review_note=null,revision=revision+1 where id=s.id returning * into s;
 elsif p_action in ('VERIFY','RETURN') then
  if not is_reviewer or s.owner_id=auth.uid() or s.submitted_by=auth.uid() or s.status<>'EN_REVISION' or nullif(trim(p_data->>'note'),'') is null then raise exception 'Revisión independiente y observación requeridas';end if;
  if p_action='VERIFY' and not s.requested_na and not private.sgc_docs_valid(s.documents,(s.definition->>'document_required')::boolean) then raise exception 'La documentación cambió: devuelva el paso para corrección';end if;
  update public.sgc_steps set status=case when p_action='RETURN' then 'EN_CURSO' when s.requested_na and (s.definition->>'optional')::boolean then 'NO_APLICA' else 'VERIFICADO' end,reviewed_by=auth.uid(),reviewed_at=now(),review_note=trim(p_data->>'note'),revision=revision+1 where id=s.id returning * into s;
 else raise exception 'Acción de implementación inválida';end if;
 perform private.sgc_log(p.id,'STEP',s.id,p_action,beforej,to_jsonb(s));return jsonb_build_object('id',s.id);
end$$;
revoke all on function public.sgc_project_action(text,jsonb) from public,anon;
grant execute on function public.sgc_project_action(text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;
