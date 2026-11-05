"""Same-code concurrent retries in a disposable Docker database, never production."""
import concurrent.futures
import json
import subprocess
from pathlib import Path

def verify(container, out, root):
    def sql(text, check=True):
        p = subprocess.run(['docker', 'exec', '-i', container, 'psql', '-U', 'postgres',
                            '-d', 'hemovigilance_retry_test', '-v', 'ON_ERROR_STOP=1', '-At'],
                           input=text, capture_output=True, text=True, timeout=60)
        if check and p.returncode:
            raise RuntimeError(p.stderr)
        return p
    subprocess.run(['docker', 'exec', container, 'createdb', '-U', 'postgres',
                    '-T', 'postgres', 'hemovigilance_retry_test'], check=True, capture_output=True)
    seed = (root / 'tests/security/hemovigilance-access.sql').read_text().split('create function pg_temp.hv_ok')[0]
    sql(seed + '\ncommit;')
    payload = json.dumps(dict(event_code='HV-CONCURRENT', description='Synthetic retry',
        patient_name='Synthetic patient', health_center='Synthetic center', reporter_name='Synthetic reporter',
        reporter_role='Laboratory', reporter_phone='000', component_type='PLASMA', units=1,
        abo='O', rh='POSITIVO', nc_category='transporte', nc_subtype='Synthetic', product_returned=True))
    statement = """begin;set local role authenticated;
select set_config('request.jwt.claim.sub','ad200000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);
select public.hemovig_delivery_nc_create('ad100000-0000-0000-0000-000000000001',%s::jsonb);
commit;""" % ("'" + payload.replace("'", "''") + "'")
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda _: sql(statement, False), range(2)))
    if sum(p.returncode == 0 for p in results) != 1 or not any('duplicate key' in p.stderr for p in results):
        raise RuntimeError('Expected one committed event and one same-code conflict: ' + repr([(p.returncode,p.stderr) for p in results]))
    counts = sql("select jsonb_build_object('events',(select count(*) from public.hemovigilance_events where event_code='HV-CONCURRENT'),'details',(select count(*) from public.hemovigilance_delivery_details d join public.hemovigilance_events e on e.id=d.event_id where e.event_code='HV-CONCURRENT'),'audit',(select count(*) from public.audit_events a join public.hemovigilance_events e on a.metadata->>'event_id'=e.id::text where e.event_code='HV-CONCURRENT'));")
    actual = json.loads(counts.stdout.strip())
    if actual != dict(events=1, details=1, audit=2):
        raise RuntimeError('Concurrent retry produced partial or duplicate records: '+repr(actual))
    checks = [{'name':'concurrent delivery retries preserve one event, one detail and atomic audit', 'pass':True}]
    (out / 'hemovigilance-concurrency.json').write_text(json.dumps({'checks':checks,'counts':actual},indent=2))
    return checks
