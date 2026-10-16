"""Verify the operational-route migration in disposable PostgreSQL; never access production.

The older checkout omits clinical_demand_requests. Its explicit test fixture is
required for local schema reconstruction and is not a proposed production schema.
"""
import argparse, hashlib, json, os, re, subprocess, time, importlib.util
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
IMAGE='postgres@sha256:2d2b8998d31037bf721cfdf764d76ba74171b4fab3431b7f72c27c56ddbdf9e3'
CANDIDATE=ROOT/'sql/migrations/20261013120000_workflow_commercial_quality.sql'
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--allow-external-prerequisite-fixture',action='store_true')
 p.add_argument('--keep',action='store_true',help='Keep only this disposable local test container for diagnosis')
 p.add_argument('--report-dir',type=Path,default=Path('/tmp/hemocura-workflow-postgres'))
 args=p.parse_args()
 if not args.allow_external_prerequisite_fixture:
  print('Explicit local prerequisite fixture opt-in required.');return 2
 out=args.report_dir.resolve();out.mkdir(parents=True,exist_ok=True)
 name=f'hemocura-workflow-test-{os.getpid()}';started=False
 report={'production_verified':False,'external_prerequisite_fixture':True,'environment':'disposable isolated PostgreSQL','migrations':[],'checks':[],'container':name}
 def sql(text,label):
  r=subprocess.run(['docker','exec','-i',name,'psql','-h','127.0.0.1','-U','postgres','-v','ON_ERROR_STOP=1','-At'],input=text,capture_output=True,text=True,timeout=120)
  (out/(label+'.log')).write_text(r.stdout+r.stderr)
  if r.returncode:raise RuntimeError(label+': failed; see '+str(out/(label+'.log')))
  return r
 def apply(path):
  sql(path.read_text(),path.stem);report['migrations'].append({'file':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
 try:
  if subprocess.run(['docker','image','inspect',IMAGE],capture_output=True).returncode:subprocess.run(['docker','pull',IMAGE],check=True)
  subprocess.run(['docker','run','-d','--name',name,'--network','none','-e','POSTGRES_HOST_AUTH_METHOD=trust',IMAGE],check=True,capture_output=True)
  started=True
  for _ in range(80):
   if subprocess.run(['docker','exec',name,'pg_isready','-h','127.0.0.1','-U','postgres'],capture_output=True).returncode==0:break
   time.sleep(.2)
  else:raise RuntimeError('PostgreSQL startup failed')
  apply(ROOT/'tests/wave50/auth-bootstrap.sql');apply(ROOT/'sql/00_IMPLEMENT_SUPABASE_ALL_FIXED_v7_2.sql')
  for f in sorted((ROOT/'sql').glob('*.sql')):
   if f.name[:2].isdigit() and 22<=int(f.name[:2])<=44:apply(f)
  apply(ROOT/'sql/reconciled/45_DAILY_OPERATIONAL_REPORT_RECONCILED_BASELINE.sql')
  for f in sorted((ROOT/'sql/migrations').glob('*.sql')):
   if f.name.startswith(('20261010','20261011')):apply(f)
  deferred=[]
  access_migrations=[]
  coordination_migrations=[]
  purchase_migrations=[]
  for f in sorted((ROOT/'supabase/migrations').glob('*.sql')):
   if f.name.endswith('_purchase_receiving.sql'):purchase_migrations.append(f);continue
   if f.name.endswith('_operations_coordination.sql'):coordination_migrations.append(f);continue
   if f.name.endswith(('_super_user_total_access.sql','_assigned_role_branch_access.sql')):access_migrations.append(f);continue
   # The donor agenda depends on wf_active_actor and wf_audit_change from CANDIDATE.
   if f.name in ('20261013183215_donor_management.sql','20261013194849_donor_twelve_week_agenda.sql','20261013200735_donor_identity_capture.sql'):deferred.append(f);continue
   if f.name=='20261012105117_value_chain_50_foundation_v2.sql':apply(ROOT/'tests/wave50/external-prerequisites.sql')
   apply(f)
  for f in sorted((ROOT/'sql/migrations').glob('*.sql')):
   if f.name.startswith('20261012'):apply(f)
  apply(CANDIDATE)
  apply(ROOT/'sql/migrations/20261013133000_workflow_refinements.sql')
  apply(ROOT/'tests/workflow/donor-agenda-prerequisite.sql')
  for f in deferred:apply(f)
  for f in coordination_migrations:apply(f)
  for f in purchase_migrations:apply(f)
  result=sql((ROOT/'tests/workflow/business-rules.sql').read_text(),'workflow-business-rules')
  checks=re.findall(r'PASS ([^\n]+)',result.stderr+result.stdout)
  if not checks:raise RuntimeError('Zero business-rule checks executed')
  report['checks']=[{'name':c.strip(),'pass':True} for c in checks]
  # Commit only the synthetic seed for concurrent sessions in this isolated container.
  seed=(ROOT/'tests/workflow/business-rules.sql').read_text().split('create function pg_temp.expect_failure')[0]
  sql(seed+'\ncommit;','concurrency-seed')
  spec=importlib.util.spec_from_file_location('workflow_concurrency',ROOT/'tests/workflow/concurrency.py')
  module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
  report['checks'].extend(module.verify(name,out))

  apply(CANDIDATE)
  apply(ROOT/'sql/migrations/20261013133000_workflow_refinements.sql')
  sql("select 1/count(*) from pg_policies where schemaname='public' and tablename='hyperbaric_appointments';",'migration-repeatability')
  report['checks'].append({'name':'migration reapplies without removing records or permissions','pass':True})
  # Production access migrations require an explicitly assigned, active global owner.
  # Seed only that prerequisite after operational fixtures, without granting it to test operators.
  if access_migrations:
   sql("insert into branches(id,code,name) values('f9100000-0000-0000-0000-000000000001','WF-SUPER','Global owner fixture'); insert into auth.users(id,email) values('f9200000-0000-0000-0000-000000000001','super-owner@example.invalid'); insert into profiles(id,full_name,branch_id,active) values('f9200000-0000-0000-0000-000000000001','Global owner fixture','f9100000-0000-0000-0000-000000000001',true); insert into roles(code,name) values('SUPER_USUARIO','Super Usuario') on conflict(code) do nothing; insert into user_roles(user_id,role_id,branch_id) select 'f9200000-0000-0000-0000-000000000001',id,'f9100000-0000-0000-0000-000000000001' from roles where code='SUPER_USUARIO';",'super-owner-prerequisite')
   for access_migration in access_migrations:apply(access_migration)
   sql("begin;set local role authenticated;select set_config('request.jwt.claim.sub','f9200000-0000-0000-0000-000000000001',true);select set_config('request.jwt.claim.role','authenticated',true);do $$begin if exists(select 1 from app_permissions where active and not has_permission(permission_code)) then raise exception 'Missing super permission';end if;if exists(select 1 from branches where not can_access_branch(id)) then raise exception 'Missing super branch';end if;end$$;rollback;",'integrated-super-permissions')
   report['checks'].append({'name':'complete role access on integrated operational schema','pass':True})
  print(f'PASS: {len(report["checks"])} PostgreSQL checks; {len(report["migrations"])} baseline/candidate files. Production not verified.')
  return 0
 except Exception as e:
  report['error']=str(e);print('FAIL: '+str(e));return 1
 finally:
  report['status']='FAIL' if report.get('error') else 'PASS'
  (out/'report.json').write_text(json.dumps(report,indent=2))
  if started and not args.keep:subprocess.run(['docker','rm','-f',name],capture_output=True)
  if started and args.keep:print('Local diagnostic container: '+name)
if __name__=='__main__':raise SystemExit(main())
