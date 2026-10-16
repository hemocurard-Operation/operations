"""Test planning in an isolated PostgreSQL container; never connects to production."""
import subprocess,pathlib,time,json,re,os
root=pathlib.Path(__file__).resolve().parents[1];out=pathlib.Path(os.environ.get('HEMOCURA_COORD_REPORT','/tmp/hemocura-coordination-postgres'));out.mkdir(parents=True,exist_ok=True)
name='hemocura-coordination-'+str(os.getpid());base=['docker','--host=unix:///var/run/docker.sock'];checks=[]
try:
 subprocess.run(base+['run','-d','--name',name,'--network','none','-e','POSTGRES_HOST_AUTH_METHOD=trust','postgres:17'],check=True,capture_output=True)
 for _ in range(100):
  if subprocess.run(base+['exec',name,'pg_isready','-h','127.0.0.1','-U','postgres'],capture_output=True).returncode==0:break
  time.sleep(.2)
 else:raise RuntimeError('Database not ready')
 def run(sql,label):
  r=subprocess.run(base+['exec','-i',name,'psql','-h','127.0.0.1','-U','postgres','-v','ON_ERROR_STOP=1'],input=sql,text=True,capture_output=True);(out/(label+'.log')).write_text(r.stdout+r.stderr)
  if r.returncode:raise RuntimeError(label+': '+r.stderr[-1800:])
  checks.extend(re.findall('NOTICE:  PASS ([^\n]+)',r.stderr));return r
 for label,path in [('bootstrap','tests/donors/database-bootstrap.sql'),('donors','supabase/migrations/20261013183215_donor_management.sql'),('provenance','supabase/migrations/20261013190249_donor_import_provenance.sql'),('agenda','supabase/migrations/20261013194849_donor_twelve_week_agenda.sql'),('identity','supabase/migrations/20261013200735_donor_identity_capture.sql'),('setup','tests/coordination/setup.sql'),('coordination','supabase/migrations/20261016190414_operations_coordination.sql'),('business','tests/coordination/business-rules.sql')]:run((root/path).read_text(),label)
 # Two competing reservations: exactly one may use the only slot.
 run("set role authenticated;select set_config('test.actor','e2000000-0000-0000-0000-000000000001',false);update donor_visits set status='CANCELADA' where status in ('POR_CONFIRMAR','CONFIRMADA') and donor_id in ('e3000000-0000-0000-0000-000000000001','e3000000-0000-0000-0000-000000000003');",'race-setup')
 def command(donor):return "begin;set role authenticated;select set_config('test.actor','e2000000-0000-0000-0000-000000000001',true);insert into donor_visits(donor_id,branch_id,starts_at) values('"+donor+"','e1000000-0000-0000-0000-000000000001',((current_date+100)::text||' 12:00:00-04')::timestamptz);select pg_sleep(0.5);commit;"
 cmd=base+['exec','-i',name,'psql','-h','127.0.0.1','-U','postgres','-v','ON_ERROR_STOP=1']
 processes=[subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True) for _ in range(2)]
 for p,d in zip(processes,['e3000000-0000-0000-0000-000000000001','e3000000-0000-0000-0000-000000000003']):p.stdin.write(command(d));p.stdin.close();p.stdin=None
 results=[p.communicate(timeout=20) for p in processes]
 assert sorted(p.returncode for p in processes)==[0,3],results
 assert any('No quedan cupos' in err for _,err in results),results
 checks.append('concurrent reservations cannot overbook a slot')
 (out/'report.json').write_text(json.dumps({'status':'PASS','checks':checks,'production_verified':False,'schema':'donor authorization fixture + actual migrations'},indent=2));print('PASS coordination PostgreSQL:',len(checks),'checks')
finally:subprocess.run(base+['rm','-f',name],capture_output=True)
