"""Purchasing rules in disposable PostgreSQL. Never connects to production."""
import subprocess,pathlib,time,json,re,os
root=pathlib.Path(__file__).resolve().parents[1];out=pathlib.Path(os.environ.get('HEMOCURA_PURCHASE_REPORT','/tmp/hemocura-purchase-postgres'));out.mkdir(parents=True,exist_ok=True)
name='hemocura-purchase-'+str(os.getpid());base=['docker','--host=unix:///var/run/docker.sock'];checks=[]
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
 migration=next((root/'supabase/migrations').glob('*_purchase_receiving.sql'))
 for label,path in [('bootstrap',root/'tests/donors/database-bootstrap.sql'),('setup',root/'tests/procurement/setup.sql'),('baseline',root/'sql/37_SUPPLIERS_PROCUREMENT_v0_37.sql'),('purchasing',migration),('business',root/'tests/procurement/business-rules.sql')]:run(path.read_text(),label)
 # Competing deliveries serialized on the same order: only one may accept the last unit.
 result=run("set role authenticated;select set_config('test.actor','e2000000-0000-0000-0000-000000000001',false);select procurement_action('CREATE',jsonb_build_object('branch_id','e1000000-0000-0000-0000-000000000001','supplier_id',(select id from suppliers limit 1),'lines',jsonb_build_array(jsonb_build_object('description','Concurrency','quantity',1,'unit_price',1,'requires_lot',false,'requires_expiry',false))))->>'id';",'race-seed')
 oid=re.findall(r'\b[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\b',result.stdout)[-1]
 run("set role authenticated;select set_config('test.actor','e2000000-0000-0000-0000-000000000001',false);select procurement_action('APPROVE',jsonb_build_object('id','"+oid+"','revision',1));",'race-approve')
 cmd=base+['exec','-i',name,'psql','-h','127.0.0.1','-U','postgres','-v','ON_ERROR_STOP=1'];procs=[]
 for _ in range(2):
  p=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True);p.stdin.write("begin;set role authenticated;select set_config('test.actor','e2000000-0000-0000-0000-000000000001',true);select procurement_action('RECEIVE',jsonb_build_object('id','"+oid+"','revision',2,'request_id',gen_random_uuid(),'received_at',now(),'delivery_reference','RACE','condition','CONFORME','packaging','INTEGRO','documents','COMPLETA','lines',jsonb_build_array(jsonb_build_object('line_id',(select id from purchase_order_lines where purchase_order_id='"+oid+"'),'quantity',1,'accepted_quantity',1,'unit_price',1))));select pg_sleep(0.3);commit;");p.stdin.close();p.stdin=None;procs.append(p)
 results=[p.communicate(timeout=20) for p in procs];assert sorted(p.returncode for p in procs)==[0,3],results
 assert any('La orden cambió' in err for _,err in results),results
 checks.append('concurrent receptions cannot over fulfill or double accept')
 (out/'report.json').write_text(json.dumps({'status':'PASS','checks':checks,'production_verified':False,'schema':'existing purchasing schema + actual migration'},indent=2));print('PASS purchasing PostgreSQL:',len(checks),'checks')
finally:subprocess.run(base+['rm','-f',name],capture_output=True)
