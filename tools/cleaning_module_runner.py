"""Ejercita el módulo de limpieza de equipos en PostgreSQL desechable.

HemoCura v11 Brecha L1 del PLAN_EJECUTIVO: §5.8 del prompt maestro.
Verifica la nueva migración 20261113120000_cleaning_module.sql contra
casos positivos y negativos: constraints, segregación de funciones en
verificación, vista de alertas, RLS por sucursal, audit a lab_event_log.

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
        'HEMOCURA_CLEANING_MODULE_REPORT',
        '/tmp/hemocura-cleaning-module',
    )
)
OUT.mkdir(parents=True, exist_ok=True)

NAME = f'hemocura-cleaning-module-{os.getpid()}'
BASE = ['docker']

MIGRATIONS = [
    ('auth_bootstrap', 'tests/wave50/auth-bootstrap.sql'),
    ('baseline', 'sql/00_IMPLEMENT_SUPABASE_ALL_FIXED_v7_2.sql'),
    ('planning_forecast', 'sql/12_planning_forecast_v7_FIXED.sql'),
    ('operations_qms', 'sql/22_OPERATIONS_QMS_COMPLIANCE_v0_22.sql'),
    ('blood_operations', 'sql/23_BLOOD_OPERATIONS_BI_PM_v0_23.sql'),
    ('resources_control', 'sql/35_RESOURCES_CONTROL_v0_35.sql'),
    ('cold_chain', 'sql/39_COLD_CHAIN_v0_39.sql'),
    ('super_user', 'supabase/migrations/20261013230050_super_user_total_access.sql'),
    ('branch_access', 'supabase/migrations/20261014135910_assigned_role_branch_access.sql'),
    ('lab_workspace', 'supabase/migrations/20261017084848_lab_management_workspace.sql'),
    ('cleaning_module', 'supabase/migrations/20261113120000_cleaning_module.sql'),
    ('rules', 'tests/cleaning/business-rules.sql'),
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
        'migration': '20261113120000_cleaning_module.sql',
        'brecha': 'L1 — §5.8 Limpieza de equipos',
    }, indent=2))
    print(f'PASS cleaning module: {len(checks)} check(s)')
finally:
    subprocess.run(BASE + ['rm', '-f', NAME], capture_output=True)
