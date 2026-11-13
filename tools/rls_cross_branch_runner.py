"""Ejercita RLS cross-sucursal en PostgreSQL desechable.

Prompt maestro HemoCura v11 §17 escenario crítico #5: "Una sucursal no
puede consultar datos restringidos de otra." Este runner levanta un
contenedor efímero, aplica el baseline y las migraciones de acceso
(incluyendo super_user_total_access + assigned_role_branch_access), y
corre `tests/rls-cross-branch/business-rules.sql` que valida:

- Un operador de la sucursal A solo ve filas de A.
- Un operador de la sucursal B solo ve filas de B.
- Un SUPER_USUARIO ve ambas sucursales.
- Un perfil desactivado pierde acceso incluso a su propia sucursal.
- INSERT/UPDATE cross-sucursal son rechazados por RLS.

Nunca se conecta a producción.
"""
import json
import os
import pathlib
import re
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = pathlib.Path(
    os.environ.get(
        'HEMOCURA_RLS_CROSS_BRANCH_REPORT',
        '/tmp/hemocura-rls-cross-branch',
    )
)
OUT.mkdir(parents=True, exist_ok=True)

NAME = f'hemocura-rls-cross-branch-{os.getpid()}'
BASE = ['docker']

MIGRATIONS = [
    ('auth_bootstrap', 'tests/wave50/auth-bootstrap.sql'),
    ('baseline', 'sql/00_IMPLEMENT_SUPABASE_ALL_FIXED_v7_2.sql'),
    ('planning_forecast', 'sql/12_planning_forecast_v7_FIXED.sql'),
    ('operations_qms', 'sql/22_OPERATIONS_QMS_COMPLIANCE_v0_22.sql'),
    ('blood_operations', 'sql/23_BLOOD_OPERATIONS_BI_PM_v0_23.sql'),
    ('audit_trace', 'sql/27_AUDIT_TRACE_EXCEPTIONS_v0_27.sql'),
    ('access_governance', 'sql/29_ACCESS_GOVERNANCE_v0_29.sql'),
    ('donor_identity', 'supabase/migrations/20261013183215_donor_management.sql'),
    ('super_user', 'supabase/migrations/20261013230050_super_user_total_access.sql'),
    ('branch_access', 'supabase/migrations/20261014135910_assigned_role_branch_access.sql'),
    ('rules', 'tests/rls-cross-branch/business-rules.sql'),
]

checks = []

try:
    subprocess.run(
        BASE + [
            'run', '-d', '--name', NAME,
            '--network', 'none',
            '-e', 'POSTGRES_HOST_AUTH_METHOD=trust',
            'postgres:17',
        ],
        check=True, capture_output=True,
    )
    for _ in range(100):
        ready = subprocess.run(
            BASE + ['exec', NAME, 'pg_isready', '-h', '127.0.0.1', '-U', 'postgres'],
            capture_output=True,
        )
        if ready.returncode == 0:
            break
        time.sleep(0.2)
    else:
        raise RuntimeError('PostgreSQL desechable no quedó listo a tiempo')

    def run(sql_text, label):
        r = subprocess.run(
            BASE + [
                'exec', '-i', NAME,
                'psql', '-h', '127.0.0.1', '-U', 'postgres',
                '-v', 'ON_ERROR_STOP=1',
            ],
            input=sql_text, text=True, capture_output=True,
        )
        (OUT / (label + '.log')).write_text(r.stdout + r.stderr)
        if r.returncode:
            raise RuntimeError(f'{label}: {r.stderr[-1800:]}')
        checks.extend(re.findall(r'NOTICE:  PASS ([^\n]+)', r.stderr))
        return r

    run(
        "alter database postgres set timezone to 'America/Santo_Domingo';",
        'local-business-timezone',
    )

    for label, rel in MIGRATIONS:
        path = ROOT / rel
        if not path.is_file():
            raise RuntimeError(f'Fixture faltante: {rel}')
        run(path.read_text(), label)

    if not checks:
        raise RuntimeError('Ningún PASS emitido; revisar logs en ' + str(OUT))

    (OUT / 'report.json').write_text(json.dumps({
        'status': 'PASS',
        'checks': checks,
        'production_verified': False,
        'environment': 'disposable isolated PostgreSQL',
        'scenario': 'HemoCura v11 §17 critical scenario #5 — RLS cross-branch isolation',
    }, indent=2))
    print(f'PASS RLS cross-branch: {len(checks)} check(s)')
finally:
    subprocess.run(BASE + ['rm', '-f', NAME], capture_output=True)
