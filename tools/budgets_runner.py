"""budgets — Brecha F3 §10 HemoCura v11. Nunca producción."""
import json, os, pathlib, re, subprocess, time
ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = pathlib.Path(os.environ.get('HEMOCURA_BUDGETS_REPORT','/tmp/hemocura-budgets'))
OUT.mkdir(parents=True, exist_ok=True)
NAME = f'hemocura-budgets-{os.getpid()}'; BASE = ['docker']
MIGRATIONS = [
    ('auth_bootstrap','tests/wave50/auth-bootstrap.sql'),
    ('baseline','sql/00_IMPLEMENT_SUPABASE_ALL_FIXED_v7_2.sql'),
    ('planning_forecast','sql/12_planning_forecast_v7_FIXED.sql'),
    ('operations_qms','sql/22_OPERATIONS_QMS_COMPLIANCE_v0_22.sql'),
    ('blood_operations','sql/23_BLOOD_OPERATIONS_BI_PM_v0_23.sql'),
    ('accounts_payable','supabase/migrations/20261114000000_accounts_payable.sql'),
    ('budgets','supabase/migrations/20261114080000_budgets.sql'),
    ('rules','tests/budgets/business-rules.sql'),
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
    (OUT/'report.json').write_text(json.dumps({'status':'PASS','checks':checks,'production_verified':False,'brecha':'F3 §10 budgets'},indent=2))
    print(f'PASS budgets: {len(checks)} check(s)')
finally:
    subprocess.run(BASE+['rm','-f',NAME],capture_output=True)
