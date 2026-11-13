"""closing batch — L3+CM1+BI2+BI4 HemoCura v11. Nunca producción."""
import json, os, pathlib, re, subprocess, time
ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = pathlib.Path(os.environ.get('HEMOCURA_CLOSING_BATCH_REPORT','/tmp/hemocura-closing-batch'))
OUT.mkdir(parents=True, exist_ok=True)
NAME = f'hemocura-closing-batch-{os.getpid()}'; BASE = ['docker']
MIGRATIONS = [
    ('auth_bootstrap','tests/wave50/auth-bootstrap.sql'),
    ('baseline','sql/00_IMPLEMENT_SUPABASE_ALL_FIXED_v7_2.sql'),
    ('planning_forecast','sql/12_planning_forecast_v7_FIXED.sql'),
    ('operations_qms','sql/22_OPERATIONS_QMS_COMPLIANCE_v0_22.sql'),
    ('blood_operations','sql/23_BLOOD_OPERATIONS_BI_PM_v0_23.sql'),
    ('resources_control','sql/35_RESOURCES_CONTROL_v0_35.sql'),
    ('suppliers_procurement','sql/37_SUPPLIERS_PROCUREMENT_v0_37.sql'),
    ('value_chain','supabase/migrations/20261012105117_value_chain_50_foundation_v2.sql'),
    ('workflow_commercial','sql/migrations/20261013120000_workflow_commercial_quality.sql'),
    ('donor_identity','supabase/migrations/20261013183215_donor_management.sql'),
    ('predictive_meta','supabase/migrations/20261113140000_predictive_meta.sql'),
    ('donor_status_enum','supabase/migrations/20261113160000_donor_status_enum.sql'),
    ('equipment_usage','supabase/migrations/20261113180000_equipment_usage.sql'),
    ('purpose','supabase/migrations/20261113220000_commercial_visit_purpose.sql'),
    ('closing','supabase/migrations/20261114120000_closing_batch.sql'),
    ('rules','tests/closing-batch/business-rules.sql'),
]
checks = []
try:
    subprocess.run(BASE+['run','-d','--name',NAME,'--network','none','-e','POSTGRES_HOST_AUTH_METHOD=trust','postgres:17'],check=True,capture_output=True)
    for _ in range(100):
        if subprocess.run(BASE+['exec',NAME,'pg_isready','-h','127.0.0.1','-U','postgres'],capture_output=True).returncode==0:break
        time.sleep(0.2)
    else: raise RuntimeError('PostgreSQL no listo')
    def run(sql,label):
        r=subprocess.run(BASE+['exec','-i',NAME,'psql','-h','127.0.0.1','-U','postgres','-v','ON_ERROR_STOP=1'],input=sql,text=True,capture_output=True)
        (OUT/(label+'.log')).write_text(r.stdout+r.stderr)
        if r.returncode: raise RuntimeError(f'{label}: {r.stderr[-1800:]}')
        checks.extend(re.findall(r'NOTICE:  PASS ([^\n]+)',r.stderr))
    run("alter database postgres set timezone to 'America/Santo_Domingo';",'tz')
    for label,rel in MIGRATIONS:
        p=ROOT/rel
        if not p.is_file(): raise RuntimeError(f'Fixture faltante: {rel}')
        run(p.read_text(),label)
    if not checks: raise RuntimeError('Ningún PASS emitido')
    (OUT/'report.json').write_text(json.dumps({'status':'PASS','checks':checks,'production_verified':False,'brechas':'L3+CM1+BI2+BI4'},indent=2))
    print(f'PASS closing batch: {len(checks)} check(s)')
finally:
    subprocess.run(BASE+['rm','-f',NAME],capture_output=True)
