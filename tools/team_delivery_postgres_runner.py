import subprocess,time,pathlib,json,re
root=pathlib.Path(__file__).resolve().parents[1];name='hemo-team-delivery-validation-'+str(__import__('os').getpid());out=pathlib.Path('/tmp/hemocura-team-delivery-postgres');out.mkdir(parents=True,exist_ok=True)
def cmd(args,**kw):return subprocess.run(['docker']+args,capture_output=True,text=True,**kw)
checks=[]
try:
 r=cmd(['run','-d','--name',name,'--network','none','--tmpfs','/var/lib/postgresql/data:rw,size=160m','-e','POSTGRES_HOST_AUTH_METHOD=trust','postgres:17-alpine']);r.check_returncode()
 for _ in range(60):
  if cmd(['exec',name,'pg_isready','-h','127.0.0.1','-U','postgres']).returncode==0:break
  time.sleep(.2)
 for label,file in [('bootstrap','tests/team-deliveries/bootstrap.sql'),('migration','supabase/migrations/20261105155451_team_delivery_coordination.sql'),('business','tests/team-deliveries/business.sql')]:
  r=cmd(['exec','-i',name,'psql','-h','127.0.0.1','-X','-U','postgres','-v','ON_ERROR_STOP=1'],input=(root/file).read_text());(out/(label+'.log')).write_text(r.stdout+r.stderr)
  if r.returncode:raise RuntimeError(label+': '+r.stderr[-2200:])
  checks.extend(re.findall('NOTICE:  PASS ([^\n]+)',r.stderr))
 # A second delivery allows two supervisors' competing revisions to race.
 setup="""update profiles set active=true;set role authenticated;select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000001',false);select team_delivery_action('CREATE',test_payload(30,'{"transport_id":"30000000-0000-0000-0000-000000000002","destination_branch_id":"10000000-0000-0000-0000-000000000002","driver_id":"20000000-0000-0000-0000-000000000002"}'));"""
 r=cmd(['exec','-i',name,'psql','-h','127.0.0.1','-X','-U','postgres','-v','ON_ERROR_STOP=1'],input=setup)
 if r.returncode:raise RuntimeError(r.stderr)
 processes=[]
 for n in (31,32):
  sql="set role authenticated;select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000001',false);select team_delivery_action('REASSIGN',test_payload("+str(n)+",jsonb_build_object('id',(select id from team_deliveries where transport_id='30000000-0000-0000-0000-000000000002'),'revision',1,'driver_id','20000000-0000-0000-0000-000000000003','reason','Relevo concurrente ficticio')));"
  p=subprocess.Popen(['docker','exec','-i',name,'psql','-h','127.0.0.1','-X','-U','postgres','-v','ON_ERROR_STOP=1'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
  p.stdin.write(sql);p.stdin.close();p.stdin=None;processes.append(p)
 results=[p.communicate(timeout=20) for p in processes]
 assert sorted(p.returncode for p in processes)==[0,3],results
 checks.append('competing revisions allow exactly one reassignment')
 (out/'concurrency.log').write_text('\n'.join(err for _,err in results))
 (out/'database.json').write_text(json.dumps({'status':'PASS','checks':checks,'production_data_used':False},indent=2));print('PASS:',len(checks),'PostgreSQL checks')
finally:cmd(['rm','-f',name])
