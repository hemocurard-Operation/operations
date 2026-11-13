"""equipment_usage — Brecha L2 §5.4/§5.6 HemoCura v11. Nunca producción."""
import json, os, pathlib, re, subprocess, time
ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = pathlib.Path(os.environ.get('HEMOCURA_EQUIPMENT_USAGE_REPORT','/tmp/hemocura-equipment-usage'))
OUT.mkdir(parents=True, exist_ok=True)
NAME = f'hemocura-equipment-usage-{os.getpid()}'; BASE = ['docker']
MIGRATIONS = [
    ('auth_bootstrap','tests/wave50/auth-bootstrap.sql'),
    ('baseline','sql/00_IMPLEMENT_SUPABASE_ALL_FIXED_v7_2.sql'),
    ('planning_forecast','sql/12_planning_forecast_v7_FIXED.sql'),
    ('operations_qms','sql/22_OPERATIONS_QMS_COMPLIANCE_v0_22.sql'),
    ('blood_operations','sql/23_BLOOD_OPERATIONS_BI_PM_v0_23.sql'),
    ('resources_control','sql/35_RESOURCES_CONTROL_v0_35.sql'),
    ('super_user','supabase/migrations/20261013230050_super_user_total_access.sql'),
    ('branch_access','supabase/migrations/20261014135910_assigned_role_branch_access.sql'),
    ('lab_workspace','supabase/migrations/20261017084848_lab_management_workspace.sql'),
    ('equipment_usage','supabase/migrations/20261113180000_equipment_usage.sql'),
    ('rules','tests/equipment-usage/business-rules.sql'),
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
    if not checks: raise RuntimeError('Ningún PASS emitido; logs en '+str(OUT))
    (OUT/'report.json').write_text(json.dumps({'status':'PASS','checks':checks,'production_verified':False,'brecha':'L2 §5.4/§5.6 equipment_usage'},indent=2))
    print(f'PASS equipment usage: {len(checks)} check(s)')
finally:
    subprocess.run(BASE+['rm','-f',NAME],capture_output=True)
