"""Test role-specific window controls in a local disposable database only."""
import subprocess,pathlib,time,json,re,os
root=pathlib.Path(__file__).resolve().parents[1];out=pathlib.Path(os.environ.get('HEMOCURA_MODULE_DB_REPORT','/tmp/hemocura-module-views-postgres'));out.mkdir(parents=True,exist_ok=True)
name='hemocura-module-views-'+str(os.getpid());base=['docker','--host=unix:///var/run/docker.sock'];checks=[]
try:
 subprocess.run(base+['run','-d','--name',name,'--network','none','-e','POSTGRES_HOST_AUTH_METHOD=trust','postgres:17'],check=True,capture_output=True)
 for _ in range(100):
  if subprocess.run(base+['exec',name,'pg_isready','-h','127.0.0.1','-U','postgres'],capture_output=True).returncode==0:break
  time.sleep(.2)
 else:raise RuntimeError('Database not ready')
 def run(sql,label):
  r=subprocess.run(base+['exec','-i',name,'psql','-h','127.0.0.1','-U','postgres','-v','ON_ERROR_STOP=1'],input=sql,text=True,capture_output=True);(out/(label+'.log')).write_text(r.stdout+r.stderr)
  if r.returncode:raise RuntimeError(label+': '+r.stderr[-2200:])
  checks.extend(re.findall('NOTICE:  PASS ([^\n]+)',r.stderr));return r
 config=json.loads((root/'contracts/role-module-defaults.json').read_text());q=lambda s:"'"+s.replace("'","''")+"'"
 run((root/'tests/module-views/setup.sql').read_text(),'bootstrap')
 sql='insert into roles(code,name) values '+','.join('('+q(r)+','+q(r)+')' for r in config['profiles'])+';'
 sql+='insert into app_permissions(permission_code) values '+','.join('('+q(p)+')' for p in sorted({m['permission_code'] for m in config['modules']}))+';'
 sql+='insert into role_permissions select r.id,p.permission_code from roles r cross join app_permissions p;delete from role_permissions where role_id=(select id from roles where code=\'LABORATORIO\') and permission_code=\'SALES_VIEW\';'
 for n,role in [(1,'SUPER_USUARIO'),(2,'ASISTENTE_OPERACIONES'),(3,'ASISTENTE_OPERACIONES'),(4,'LABORATORIO'),(5,'ASISTENTE_OPERACIONES'),(5,'FINANZAS'),(6,'ADMIN')]:sql+="insert into user_roles select 'e2000000-0000-0000-0000-00000000000"+str(n)+"',id from roles where code="+q(role)+';'
 run(sql,'seed')
 run(next((root/'supabase/migrations').glob('*_role_module_views.sql')).read_text(),'migration')
 run((root/'tests/module-views/business-rules.sql').read_text(),'business')
 (out/'report.json').write_text(json.dumps({'status':'PASS','checks':checks,'production_verified':False,'schema':'minimal authorization fixture + actual module migration'},indent=2));print('PASS role module PostgreSQL:',len(checks),'checks')
finally:subprocess.run(base+['rm','-f',name],capture_output=True)
