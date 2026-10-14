import subprocess,pathlib,time,re,json,os
root=pathlib.Path(__file__).resolve().parents[1];p=root/'tests/roles';name='hemocura-super-test-'+str(os.getpid());base=['docker','--host=unix:///var/run/docker.sock'];checks=[]
try:
 subprocess.run(base+['run','-d','--name',name,'--network','none','-e','POSTGRES_HOST_AUTH_METHOD=trust','postgres:17'],check=True,capture_output=True)
 for _ in range(80):
  if subprocess.run(base+['exec',name,'pg_isready','-h','127.0.0.1','-U','postgres'],capture_output=True).returncode==0:break
  time.sleep(.2)
 for label in ['bootstrap','super_user_access','branch_access','rules','branch-rules','super_user_access','branch_access']:
  r=subprocess.run(base+['exec','-i',name,'psql','-h','127.0.0.1','-U','postgres','-v','ON_ERROR_STOP=1'],input=((root/'supabase/migrations/20261013230050_super_user_total_access.sql') if label=='super_user_access' else ((root/'supabase/migrations/20261014135910_assigned_role_branch_access.sql') if label=='branch_access' else (p/(label+'.sql')))).read_text(),text=True,capture_output=True)
  (p/(label+'-test.log')).write_text(r.stdout+r.stderr)
  if r.returncode:raise RuntimeError(label+': '+r.stderr[-1800:])
  checks+=re.findall('NOTICE:  PASS ([^\n]+)',r.stderr)
 print('PASS PostgreSQL:',len(checks),'checks; migration candidate reapplied successfully')
 (p/'database-report.json').write_text(json.dumps({'status':'PASS','environment':'isolated PostgreSQL 17; representative schema and legacy branch fixture','checks':checks,'production_verified':False},indent=2))
finally:subprocess.run(base+['rm','-f',name],capture_output=True)
