"""Synchronized cross-agenda reservations in disposable PostgreSQL, never production.

verify(name,out,root) integrates with workflow_postgres_runner. The standalone CLI
requires --allow-disposable, a workflow-test container name and network isolation.
Only synthetic cf* fixtures created here are removed; this module never removes a
container owned by another caller.
"""
import argparse,json,re,subprocess,time,uuid
from pathlib import Path

BRANCH_A='cf100000-0000-0000-0000-000000000001'
BRANCH_B='cf100000-0000-0000-0000-000000000002'
ACTOR='cf200000-0000-0000-0000-000000000001'

def verify(name,out,root):
 out=Path(out);out.mkdir(parents=True,exist_ok=True);root=Path(root)
 if not re.fullmatch(r'hemocura-workflow-test-[0-9]+',name):raise RuntimeError('Only workflow disposable test containers are accepted')
 inspected=subprocess.run(['docker','inspect',name],capture_output=True,text=True,check=True)
 info=json.loads(inspected.stdout)[0]
 if info['HostConfig']['NetworkMode']!='none' or info['HostConfig'].get('PortBindings'):
  raise RuntimeError('Refuse container with network access or published ports')
 base=['docker','exec','-i',name,'psql','-X','-h','127.0.0.1','-U','postgres','-v','ON_ERROR_STOP=1','-At','--set=VERBOSITY=verbose']
 def run(q,label):
  r=subprocess.run(base,input=q,text=True,capture_output=True,timeout=30)
  (out/(label+'.log')).write_text(r.stdout+r.stderr)
  if r.returncode:raise RuntimeError(label+': '+r.stderr[-1800:])
  return r.stdout
 cleanup="""begin;select set_config('request.jwt.claim.sub','f9200000-0000-0000-0000-000000000001',true);
 delete from crm_weekly_visits where branch_id::text like 'cf100000-%';
 delete from commercial_visits where branch_id::text like 'cf100000-%';
 delete from crm_visit_rules where contact_id::text like 'cf500000-%';
 delete from crm_contact_branch_access where contact_id::text like 'cf500000-%';
 delete from crm_contact_sources where contact_id::text like 'cf500000-%';
 delete from crm_activities where contact_id::text like 'cf500000-%';
 delete from crm_history where contact_id::text like 'cf500000-%';
 delete from crm_contacts where id::text like 'cf500000-%';
 delete from commercial_locations where branch_id::text like 'cf100000-%';
 delete from customers where id::text like 'cf400000-%';
 delete from user_roles where user_id::text like 'cf200000-%';
 delete from audit_events where branch_id::text like 'cf100000-%' or user_id::text like 'cf200000-%';
 delete from workflow_audit where branch_id::text like 'cf100000-%' or actor_id::text like 'cf200000-%';
 delete from profiles where id::text like 'cf200000-%';
 delete from auth.users where id::text like 'cf200000-%';
 delete from audit_events where branch_id::text like 'cf100000-%' or user_id::text like 'cf200000-%';
 delete from branches where id::text like 'cf100000-%';commit;"""
 def quote(x):return "'"+str(x).replace("'","''")+"'"
 def claims(app):return "set application_name="+quote(app)+";begin isolation level read committed;set local statement_timeout='12s';select set_config('request.jwt.claim.sub',"+quote(ACTOR)+",true);select set_config('request.jwt.claim.role','authenticated',true);set local role authenticated;"
 def operation(kind,branch,when):
  if kind=='LEGACY':
   payload={'customer_id':'cf400000-0000-0000-0000-00000000000'+('1' if branch==BRANCH_A else '2'),'scheduled_at':when,'duration_minutes':30,'purpose':'Concurrent fictitious visit'}
   return 'select wf_save_visit('+quote(branch)+',null,'+quote(json.dumps(payload))+'::jsonb);'
  payload={'contact_id':'cf500000-0000-0000-0000-00000000000'+('1' if branch==BRANCH_A else '2'),'scheduled_at':when,'duration_minutes':30,'rule_revision':1,'objective':'Concurrent fictitious visit','exception_reason':'Confirmed only in synthetic test'}
  return 'select crm_plan_action('+quote(branch)+",'SAVE',"+quote(json.dumps(payload))+'::jsonb,'+quote(uuid.uuid4())+');'
 def wait_state(app,predicate,label):
  deadline=time.monotonic()+8
  while time.monotonic()<deadline:
   q="select state||'|'||coalesce(wait_event_type,'')||'|'||coalesce(wait_event,'') from pg_stat_activity where application_name="+quote(app)+';'
   value=run(q,label+'-observe').strip()
   if predicate(value):return value
   time.sleep(.05)
  raise RuntimeError(label+': expected synchronized database state, got '+value)
 checks=[];children=[];original_flag=None;failure=None;cleanup_errors=[]
 try:
  original_flag=run("select enabled::text from app_feature_flags where key='crm_weekly_planner';",'commercial-race-original-flag').strip()
  run(cleanup,'commercial-race-initial-cleanup')
  seed=(root/'tests/commercial-agenda/database.sql').read_text().split('-- END_SHARED_FIXTURE')[0]+'commit;'
  run(seed,'commercial-race-seed')
  run("select 'commercial_visit_reservation_guard'::text from pg_trigger where tgname='commercial_visit_reservation_guard';",'commercial-race-trigger')
  scenarios=[('CRM','LEGACY','23P01',False),('LEGACY','CRM','P0001',False),('LEGACY','LEGACY','23P01',False),('CRM','CRM','P0001',False),('LEGACY','CRM',None,True)]
  for idx,(first,second,expected,adjacent) in enumerate(scenarios):
   start=run("select (date_trunc('day',now())+interval '20 days 9 hours'+make_interval(mins=>"+str(idx*120)+"))::text;",'commercial-race-time-'+str(idx)).strip()
   other=run('select ('+quote(start)+'::timestamptz+interval '+quote('30 minutes' if adjacent else '10 minutes')+')::text;','commercial-race-time-b-'+str(idx)).strip()
   app_a='hemo_reservation_a_'+str(idx);app_b='hemo_reservation_b_'+str(idx)
   a=subprocess.Popen(base,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True);children.append(a)
   a.stdin.write(claims(app_a)+operation(first,BRANCH_A,start)+'\n');a.stdin.flush()
   wait_state(app_a,lambda s:s.startswith('idle in transaction|'),'commercial-race-a-ready-'+str(idx))
   b=subprocess.Popen(base,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True);children.append(b)
   b.stdin.write(claims(app_b)+operation(second,BRANCH_B,other)+'commit;\n');b.stdin.close();b.stdin=None
   wait_state(app_b,lambda s:'|Lock|advisory' in s,'commercial-race-b-blocked-'+str(idx))
   a.stdin.write('commit;\n');a.stdin.close();a.stdin=None
   first_result=a.communicate(timeout=20);second_result=b.communicate(timeout=20)
   (out/('commercial-race-'+str(idx)+'-a.log')).write_text(''.join(first_result))
   (out/('commercial-race-'+str(idx)+'-b.log')).write_text(''.join(second_result))
   if a.returncode:raise RuntimeError('First reservation failed: '+first_result[1][-1600:])
   if expected:
    if b.returncode!=3 or not re.search(r'ERROR:\s+'+expected+r':',second_result[1]):raise RuntimeError('Expected '+expected+' after synchronized lock wait: '+str(second_result))
    expected_count=1
   else:
    if b.returncode:raise RuntimeError('Adjacent interval was rejected: '+second_result[1][-1600:])
    expected_count=2
   actual=run("select (select count(*) from commercial_visits where agent_id="+quote(ACTOR)+'::uuid and scheduled_at>='+quote(start)+'::timestamptz and scheduled_at<'+quote(start)+"::timestamptz+interval '1 hour')+(select count(*) from crm_weekly_visits where agent_id="+quote(ACTOR)+'::uuid and scheduled_at>='+quote(start)+'::timestamptz and scheduled_at<'+quote(start)+"::timestamptz+interval '1 hour');",'commercial-race-count-'+str(idx)).strip()
   if actual!=str(expected_count):raise RuntimeError('Unexpected committed reservation count '+actual)
   checks.append({'name':first+' then concurrent '+second+(' adjacent intervals both succeed' if adjacent else ' overlap waits then rejects across branches with '+expected),'pass':True})
 except BaseException as exc:
  failure=exc
 finally:
  for p in children:
   if p.poll() is None:
    p.kill();p.communicate(timeout=5)
  try:
   run(cleanup,'commercial-race-final-cleanup')
  except Exception as exc:
   cleanup_errors.append(str(exc))
  if original_flag in ('true','false'):
   try:
    run("update app_feature_flags set enabled="+original_flag+" where key='crm_weekly_planner';",'commercial-race-restore-flag')
   except Exception as exc:
    cleanup_errors.append(str(exc))
  report={'status':'FAIL' if failure or cleanup_errors else 'PASS','checks':checks,'production_verified':False,'synchronization':'A idle in transaction, B blocked on advisory lock, then A commit','cleanup_complete':not cleanup_errors}
  if failure:report['error']=str(failure)
  if cleanup_errors:report['cleanup_errors']=cleanup_errors
  (out/'commercial-concurrency-report.json').write_text(json.dumps(report,indent=2))
 if failure:raise failure
 if cleanup_errors:raise RuntimeError('Synthetic fixture cleanup failed: '+'; '.join(cleanup_errors))
 return checks

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--container',required=True);p.add_argument('--report-dir',type=Path,default=Path('/tmp/hemocura-commercial-concurrency'));p.add_argument('--allow-disposable',action='store_true');args=p.parse_args()
 if not args.allow_disposable:p.error('Explicit --allow-disposable is required')
 root=Path(__file__).resolve().parents[2]
 result=verify(args.container,args.report_dir,root);print('PASS: '+str(len(result))+' synchronized commercial-agenda concurrency checks. Production not verified.')
if __name__=='__main__':main()
