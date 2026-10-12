insert into public.app_permissions(permission_code,module,description,risk_level,active) values
('VALUE_CHAIN_VIEW','VALUE_CHAIN','Ver cadena de valor integrada','NORMAL',true),
('VALUE_CHAIN_WRITE','VALUE_CHAIN','Gestionar demanda y cadena de valor','SENSIBLE',true),
('DONOR_OUTREACH_VIEW','DONOR_OUTREACH','Ver campañas de captación de donantes','NORMAL',true),
('DONOR_OUTREACH_WRITE','DONOR_OUTREACH','Gestionar campañas de captación de donantes','SENSIBLE',true),
('CUSTOMER_VIEW','CUSTOMERS','Ver clientes, acuerdos y retroalimentación','NORMAL',true),
('CUSTOMER_WRITE','CUSTOMERS','Gestionar clientes, acuerdos y retroalimentación','SENSIBLE',true),
('ACTIONS_VIEW','INTEGRATED_ACTIONS','Ver registro maestro de acciones','NORMAL',true),
('ACTIONS_WRITE','INTEGRATED_ACTIONS','Gestionar registro maestro de acciones','SENSIBLE',true)
on conflict(permission_code) do update set module=excluded.module,description=excluded.description,risk_level=excluded.risk_level,active=true;
