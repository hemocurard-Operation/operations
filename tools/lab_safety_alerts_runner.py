"""Ejercita alertas de laboratorio en PostgreSQL desechable.

Prompt maestro HemoCura v11 §17 escenarios críticos:
  #2 "Un equipo con temperatura fuera de rango genera una alerta."
  #3 "Una lectura inválida no se acepta" (enum/dominio).
  #4 "Un mantenimiento vencido se identifica."

Verifica las vistas vw_cold_chain_excursions y vw_equipment_alerts con
casos positivos y negativos, más CHECKs sobre lab_equipment.

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
        'HEMOCURA_LAB_SAFETY_ALERTS_REPORT',
        '/tmp/hemocura-lab-safety-alerts',
    )
)
OUT.mkdir(parents=True, exist_ok=True)

NAME = f'hemocura-lab-safety-alerts-{os.getpid()}'
BASE = ['docker']

MIGRATIONS = [
    ('auth_bootstrap', 'tests/wave50/auth-bootstrap.sql'),
    ('baseline', 'sql/00_IMPLEMENT_SUPABASE_ALL_FIXED_v7_2.sql'),
    ('planning_forecast', 'sql/12_planning_forecast_v7_FIXED.sql'),
    ('operations_qms', 'sql/22_OPERATIONS_QMS_COMPLIANCE_v0_22.sql'),
    ('blood_operations', 'sql/23_BLOOD_OPERATIONS_BI_PM_v0_23.sql'),
    ('resources_control', 'sql/35_RESOURCES_CONTROL_v0_35.sql'),
    ('cold_chain', 'sql/39_COLD_CHAIN_v0_39.sql'),
    ('rules', 'tests/lab-safety-alerts/business-rules.sql'),
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
        'scenario': 'HemoCura v11 §17 critical scenarios #2 #3 #4 — lab safety alerts',
    }, indent=2))
    print(f'PASS lab safety alerts: {len(checks)} check(s)')
finally:
    subprocess.run(BASE + ['rm', '-f', NAME], capture_output=True)
