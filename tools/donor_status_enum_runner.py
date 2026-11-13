"""Verifica el enum ampliado de donors.status (Brecha D4 §6.1b).

HemoCura v11 — aditivo sobre la tabla donors existente. Prueba que
los valores legacy siguen aceptados, que los 5 nuevos del prompt
funcionan, que un diferimiento sin razón ni tipo es rechazado, y
que el índice parcial existe.

Nunca se conecta a producción.
"""
import json, os, pathlib, re, subprocess, time

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = pathlib.Path(os.environ.get('HEMOCURA_DONOR_STATUS_ENUM_REPORT','/tmp/hemocura-donor-status-enum'))
OUT.mkdir(parents=True, exist_ok=True)
NAME = f'hemocura-donor-status-enum-{os.getpid()}'
BASE = ['docker']
MIGRATIONS = [
    ('auth_bootstrap','tests/wave50/auth-bootstrap.sql'),
    ('baseline','sql/00_IMPLEMENT_SUPABASE_ALL_FIXED_v7_2.sql'),
    ('planning_forecast','sql/12_planning_forecast_v7_FIXED.sql'),
    ('operations_qms','sql/22_OPERATIONS_QMS_COMPLIANCE_v0_22.sql'),
    ('blood_operations','sql/23_BLOOD_OPERATIONS_BI_PM_v0_23.sql'),
    ('donor_status_enum','supabase/migrations/20261113160000_donor_status_enum.sql'),
    ('rules','tests/donor-status-enum/business-rules.sql'),
]
checks = []
try:
    subprocess.run(BASE+['run','-d','--name',NAME,'--network','none','-e','POSTGRES_HOST_AUTH_METHOD=trust','postgres:17'],check=True,capture_output=True)
    for _ in range(100):
        if subprocess.run(BASE+['exec',NAME,'pg_isready','-h','127.0.0.1','-U','postgres'],capture_output=True).returncode==0:break
        time.sleep(0.2)
    else: raise RuntimeError('PostgreSQL desechable no quedó listo')
    def run(sql_text,label):
        r=subprocess.run(BASE+['exec','-i',NAME,'psql','-h','127.0.0.1','-U','postgres','-v','ON_ERROR_STOP=1','-At'],input=sql_text,text=True,capture_output=True)
        (OUT/(label+'.log')).write_text(r.stdout+r.stderr)
        if r.returncode: raise RuntimeError(f'{label}: {r.stderr[-1800:]}')
        checks.extend(re.findall(r'NOTICE:  PASS ([^\n]+)',r.stderr))
        return r
    run("alter database postgres set timezone to 'America/Santo_Domingo';",'tz')
    for label,rel in MIGRATIONS:
        path=ROOT/rel
        if not path.is_file(): raise RuntimeError(f'Fixture faltante: {rel}')
        run(path.read_text(),label)
    if not checks: raise RuntimeError('Ningún PASS emitido; logs en '+str(OUT))
    (OUT/'report.json').write_text(json.dumps({'status':'PASS','checks':checks,'production_verified':False,'brecha':'D4 §6.1b donor status enum'},indent=2))
    print(f'PASS donor status enum: {len(checks)} check(s)')
finally:
    subprocess.run(BASE+['rm','-f',NAME],capture_output=True)
