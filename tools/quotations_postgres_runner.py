"""Quotation and paginated-read regressions in disposable PostgreSQL only."""
import subprocess,pathlib,time,os
root=pathlib.Path(__file__).resolve().parents[1]
name='hemocura-quotes-'+str(os.getpid());base=['docker','--host=unix:///var/run/docker.sock']
try:
 subprocess.run(base+['run','-d','--name',name,'--network','none','-e','POSTGRES_HOST_AUTH_METHOD=trust','postgres:17'],check=True,capture_output=True)
 for _ in range(100):
  if subprocess.run(base+['exec',name,'pg_isready','-h','127.0.0.1','-U','postgres'],capture_output=True).returncode==0:break
  time.sleep(.2)
 else:raise RuntimeError('PostgreSQL not ready')
 files=['tests/donors/database-bootstrap.sql','tests/procurement/setup.sql','sql/37_SUPPLIERS_PROCUREMENT_v0_37.sql','supabase/migrations/20261016201356_purchase_receiving.sql','tests/quotations/database.sql','supabase/migrations/20261107000948_supplier_quotations.sql','tests/web-performance/setup.sql','supabase/migrations/20261107181249_web_performance_security.sql','tests/quotations/business.sql','tests/web-performance/business.sql']
 for file in files:
  r=subprocess.run(base+['exec','-i',name,'psql','-h','127.0.0.1','-U','postgres','-v','ON_ERROR_STOP=1'],input=(root/file).read_text(),capture_output=True,text=True)
  if r.returncode:raise RuntimeError(file+': '+r.stderr)
  print('\n'.join(line for line in r.stderr.splitlines() if 'PASS' in line))
 print('PASS quotation PostgreSQL checks')
finally:subprocess.run(base+['rm','-f',name],capture_output=True)
