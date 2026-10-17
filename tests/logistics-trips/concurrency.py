"""Race tests against the disposable local PostgreSQL container only."""
import concurrent.futures,json,subprocess,threading,uuid

def verify(container,out,root):
 def sql(text):return subprocess.run(['docker','exec','-i',container,'psql','-h','127.0.0.1','-U','postgres','-v','ON_ERROR_STOP=1','-At'],input=text,capture_output=True,text=True,timeout=40)
 seed=(root/'tests/logistics-trips/business-rules.sql').read_text().split('create function pg_temp.ok')[0]+'\ncommit;'
 r=sql(seed)
 if r.returncode:raise RuntimeError('Trip concurrency seed failed: '+r.stderr)
 def session(actor,body):return "begin;set local role authenticated;select set_config('request.jwt.claim.sub','"+actor+"',true);select set_config('request.jwt.claim.role','authenticated',true);"+body+';commit;'
 worker='da200000-0000-0000-0000-000000000001'
 def race(bodies):
  barrier=threading.Barrier(2)
  def run(body):barrier.wait(timeout=10);return sql(body)
  with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(run,bodies))
  return results
 base={'branch_id':'da100000-0000-0000-0000-000000000001','origin':'Origen ficticio','destination':'Destino ficticio','purpose':'ENTREGA','departure_local':'2026-10-12T18:30','arrival_local':'2026-10-12T19:30'}
 bodies=[session(worker,"select logistics_trip_action('CREATE',"+"'"+json.dumps(dict(base,request_id=str(uuid.uuid4())))+"'::jsonb)") for _ in range(2)]
 results=race(bodies)
 (out/'trip-duplicate-race.log').write_text('\n'.join(r.stdout+r.stderr for r in results))
 if sorted(r.returncode==0 for r in results)!=[False,True]:raise RuntimeError('Concurrent duplicate trip creation did not serialize')
 r=sql("select id from logistics_trips where worker_id='"+worker+"';")
 if r.returncode or len(r.stdout.strip().splitlines())!=1:raise RuntimeError('Expected one surviving trip')
 trip_id=r.stdout.strip();data={'id':trip_id,'revision':1,'amount':500,'review_note':'Verificación ficticia concurrente'}
 reviewers=['da200000-0000-0000-0000-000000000003','f9200000-0000-0000-0000-000000000001']
 results=race([session(actor,"select logistics_trip_action('APPROVE','"+json.dumps(data)+"'::jsonb)") for actor in reviewers])
 (out/'trip-review-race.log').write_text('\n'.join(r.stdout+r.stderr for r in results))
 if sorted(r.returncode==0 for r in results)!=[False,True]:raise RuntimeError('Concurrent reviews did not preserve revision control')
 r=sql("select status||':'||revision from logistics_trips where id='"+trip_id+"';")
 if r.returncode or r.stdout.strip()!='APROBADO:2':raise RuntimeError('Concurrent review changed final award incorrectly')
 return [{'name':'concurrent overlapping trip claims create exactly one record','pass':True},{'name':'concurrent incentive reviews preserve one authorized decision and revision','pass':True}]
