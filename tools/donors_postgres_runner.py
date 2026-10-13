import subprocess,pathlib,time,json,re
import argparse,os
parser=argparse.ArgumentParser(description='Test donor management in disposable PostgreSQL. Never accesses hosted databases.');parser.add_argument('--report-dir',type=pathlib.Path,default=pathlib.Path('/tmp/hemocura-donors-postgres'));args=parser.parse_args()
root=pathlib.Path(__file__).resolve().parents[1];out=args.report_dir.resolve();out.mkdir(parents=True,exist_ok=True);name='hemocura-donors-test-'+str(os.getpid())
base=['docker','--host=unix:///var/run/docker.sock']
report={'environment':'isolated local PostgreSQL 17; authorization helper stubs','checks':[]}
try:
 subprocess.run(base+['run','-d','--name',name,'--network','none','-e','POSTGRES_HOST_AUTH_METHOD=trust','postgres:17'],check=True,capture_output=True)
 for i in range(60):
  if subprocess.run(base+['exec',name,'pg_isready','-h','127.0.0.1','-U','postgres'],capture_output=True).returncode==0:break
  time.sleep(.2)
 else:raise RuntimeError('PostgreSQL did not become ready')
 for label,path in [('bootstrap',root/'tests/donors/database-bootstrap.sql'),('migration',root/'supabase/migrations/20261013183215_donor_management.sql'),('provenance',root/'supabase/migrations/20261013190249_donor_import_provenance.sql'),('agenda',root/'supabase/migrations/20261013194849_donor_twelve_week_agenda.sql'),('identity',root/'supabase/migrations/20261013200735_donor_identity_capture.sql'),('business',root/'tests/donors/business-rules.sql'),('agenda-rules',root/'tests/donors/agenda-rules.sql')]:
  r=subprocess.run(base+['exec','-i',name,'psql','-h','127.0.0.1','-U','postgres','-v','ON_ERROR_STOP=1'],input=path.read_text(),text=True,capture_output=True)
  (out/(label+'.log')).write_text(r.stdout+r.stderr)
  if r.returncode:raise RuntimeError(label+': '+r.stderr[-1500:])
  report['checks']+=re.findall('NOTICE:  PASS ([^\n]+)',r.stderr)
 report['status']='PASS';print('PASS PostgreSQL:',len(report['checks']),'checks')
except Exception as e:report['status']='FAIL';report['error']=str(e);print(str(e));raise
finally:
 (out/'database-report.json').write_text(json.dumps(report,indent=2));subprocess.run(base+['rm','-f',name],capture_output=True)
