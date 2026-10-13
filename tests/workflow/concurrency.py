"""Concurrency assertions for the disposable test database, called by its runner."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime,timedelta
from zoneinfo import ZoneInfo
import subprocess,uuid

def verify(container,output):
 checks=[]
 def run(query,label,actor='e1000000-0000-0000-0000-000000000001'):
  prefix="set role authenticated;select set_config('request.jwt.claim.role','authenticated',false);select set_config('request.jwt.claim.sub','"+actor+"',false);"
  r=subprocess.run(['docker','exec','-i',container,'psql','-U','postgres','-v','ON_ERROR_STOP=1','-At'],input=prefix+query,capture_output=True,text=True,timeout=60)
  (output/(label+'.log')).write_text(r.stdout+r.stderr);return r
 def scalar(query,label,actor='e1000000-0000-0000-0000-000000000001'):
  r=run(query,label,actor)
  if r.returncode:raise RuntimeError(label+' failed')
  return r.stdout.strip().splitlines()[-1]
 branch='e2000000-0000-0000-0000-000000000001'
 resource=scalar("select wf_create_resource('"+branch+"','{\"name\":\"Race chamber\",\"capacity\":1,\"procedure_reference\":\"PROC-RACE\"}');",'race-resource')
 day=(datetime.now(ZoneInfo('America/Santo_Domingo')).date()+timedelta(days=1)).isoformat()
 booking=f"select wf_save_appointment('{branch}',null,jsonb_build_object('resource_id','{resource}','patient_name','Local race fixture','patient_phone','000','starts_at','{day}T13:00:00-04:00','ends_at','{day}T14:00:00-04:00','operational_date','{day}','shift','DIURNO','price',100,'currency','USD','session_label','1','referrer_name','Local fixture'));"
 with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda i:run(booking,'race-booking-'+str(i)),range(2)))
 if sum(r.returncode==0 for r in results)!=1 or not any('Capacidad ocupada' in r.stderr for r in results):raise RuntimeError('Concurrent booking did not enforce capacity')
 checks.append({'name':'concurrent chamber reservations serialize capacity and accept one booking','pass':True})
 past_booking=f"select wf_save_appointment('{branch}',null,jsonb_build_object('resource_id','{resource}','patient_name','Local performed fixture','patient_phone','000','starts_at',now()-interval '3 hours','ends_at',now()-interval '2 hours','operational_date',((now()-interval '3 hours') at time zone 'America/Santo_Domingo')::date,'shift','DIURNO','price',100,'currency','USD','session_label','1','referrer_name','Local fixture'));"
 appointment=scalar(past_booking,'race-performed-appointment')
 session=scalar(f"select wf_record_session('{appointment}',jsonb_build_object('clinical_authorization','AUTH-RACE','consent_reference','CONS-RACE','evidence','EVID-RACE','performed_at',now()-interval '2 hours','operational_date',((now()-interval '2 hours') at time zone 'America/Santo_Domingo')::date,'shift','DIURNO','status','REALIZADA'));",'race-session','e1000000-0000-0000-0000-000000000004')
 charge=scalar(f"select wf_invoice_session('{session}','RACE-INVOICE',(now() at time zone 'America/Santo_Domingo')::date);",'race-invoice')
 def pay(i):
  return run(f"select wf_pay_session('{charge}','{uuid.uuid4()}',jsonb_build_object('amount',60,'currency','USD','receipt_number','RACE-PAY-{i}','payment_date',(now() at time zone 'America/Santo_Domingo')::date));",'race-payment-'+str(i))
 with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(pay,range(2)))
 if sum(r.returncode==0 for r in results)!=1 or scalar(f"select paid from vw_hyperbaric_finance where id='{charge}';",'race-paid')!='60.00':raise RuntimeError('Concurrent payments exceeded invoice balance')
 checks.append({'name':'concurrent receipts cannot overpay a hyperbaric invoice','pass':True})
 def transfer(i):
  return run(f"select wf_send_transfer('{branch}','e2000000-0000-0000-0000-000000000002','RACE-TRANSFER-{i}',array['e5000000-0000-0000-0000-000000000001']::uuid[],'TRANSPORT-RACE');",'race-transfer-'+str(i))
 with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(transfer,range(2)))
 if sum(r.returncode==0 for r in results)!=1 or scalar("select count(*) from blood_transfer_lines where unit_id='e5000000-0000-0000-0000-000000000001' and received_at is null;",'race-transfer-count')!='1':raise RuntimeError('Concurrent transfer duplicated a blood unit')
 checks.append({'name':'concurrent transfers reserve the same blood unit only once','pass':True})
 return checks
