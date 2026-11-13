"""Ejercita idempotency en PostgreSQL desechable.

Prompt maestro HemoCura v11 §17 escenario crítico #7: "Una donación no
puede duplicarse por reintentos." Verifica que los UNIQUE constraints
(incluyendo UNIQUE parciales sobre estados activos) protegen contra
doble-escritura por retries de cliente o race de red.

Tablas cubiertas:
  - donations (donation_code, source_unit_code)
  - blood_inventory_units (unit_code)
  - donor_visits (donor_visit_active_unique partial)

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
        'HEMOCURA_IDEMPOTENCY_REPORT',
        '/tmp/hemocura-idempotency',
    )
)
OUT.mkdir(parents=True, exist_ok=True)

NAME = f'hemocura-idempotency-{os.getpid()}'
BASE = ['docker']

MIGRATIONS = [
    ('auth_bootstrap', 'tests/wave50/auth-bootstrap.sql'),
    ('baseline', 'sql/00_IMPLEMENT_SUPABASE_ALL_FIXED_v7_2.sql'),
    ('planning_forecast', 'sql/12_planning_forecast_v7_FIXED.sql'),
    ('operations_qms', 'sql/22_OPERATIONS_QMS_COMPLIANCE_v0_22.sql'),
    ('blood_operations', 'sql/23_BLOOD_OPERATIONS_BI_PM_v0_23.sql'),
    ('donor_identity', 'supabase/migrations/20261013183215_donor_management.sql'),
    ('rules', 'tests/idempotency/business-rules.sql'),
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
        'scenario': 'HemoCura v11 §17 critical scenario #7 — idempotency against retries',
    }, indent=2))
    print(f'PASS idempotency: {len(checks)} check(s)')
finally:
    subprocess.run(BASE + ['rm', '-f', NAME], capture_output=True)
