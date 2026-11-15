"""Run v11 checks against the complete isolated operational schema, never production.
The previous minimal fixtures did not reproduce deployed constraints and triggers.
"""
import os, subprocess, sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
raise SystemExit(subprocess.call([sys.executable,str(root/'tools/workflow_postgres_runner.py'),
 '--allow-external-prerequisite-fixture','--report-dir',os.environ.get('HEMOCURA_V11_REPORT','/tmp/hemocura-cleaning-module')]))
