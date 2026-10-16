"""Competing edits on synthetic agenda records in the disposable database."""
import subprocess,re,json

def verify(name,out,root):
 base=['docker','exec','-i',name,'psql','-h','127.0.0.1','-U','postgres','-v','ON_ERROR_STOP=1','-At']
 def run(q,label):
  r=subprocess.run(base,input=q,text=True,capture_output=True);(out/(label+'.log')).write_text(r.stdout+r.stderr)
  if r.returncode:raise RuntimeError(r.stderr[-1500:])
  return r.stdout
 seed=(root/'tests/area-agenda/business-rules.sql').read_text().split('create function pg_temp.ag_ok')[0]+'commit;'
 run(seed,'area-concurrency-seed')
 claims="select set_config('request.jwt.claim.sub','ea200000-0000-0000-0000-000000000001',true);select set_config('request.jwt.claim.role','authenticated',true);set local role authenticated;"
 payload="jsonb_build_object('branch_id','ea100000-0000-0000-0000-000000000001','area_code','OPERACIONES','title','Edición concurrente sintética','owner_id','ea200000-0000-0000-0000-000000000001','due_at',now()+interval '1 day','priority','NORMAL','request_id',gen_random_uuid())"
 result=run('begin;'+claims+"select work_task_action('CREATE',"+payload+");commit;",'area-concurrency-create')
 matches=re.findall(r'\{"ids"[^\n]+',result);task=json.loads(matches[0])['ids'][0]
 command='begin;'+claims+"select work_task_action('START',jsonb_build_object('id','"+task+"','revision',1));select pg_sleep(0.4);commit;"
 procs=[subprocess.Popen(base,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True) for _ in range(2)]
 for p in procs:p.stdin.write(command);p.stdin.close();p.stdin=None
 results=[p.communicate(timeout=20) for p in procs]
 if sorted(p.returncode for p in procs)!=[0,3] or not any('La tarea cambió' in err for _,err in results):raise RuntimeError('Concurrent agenda edits not serialized: '+str(results))
 return [{'name':'concurrent task edits preserve one revision and reject stale execution','pass':True}]
