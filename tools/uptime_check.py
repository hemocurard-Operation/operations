"""Public web/Auth checks only. Never authenticates a person or reads application records."""
from pathlib import Path
import urllib.request,urllib.error,json,re,sys,datetime
ROOT=Path(__file__).resolve().parents[1]
BASE='https://hemocurard-operation.github.io/operations/'
config=(ROOT/'js/config.js').read_text()
project=re.search(r"SUPABASE_URL:\s*'([^']+)'",config).group(1)
public_key=re.search(r"SUPABASE_PUBLISHABLE_KEY:\s*'([^']+)'",config).group(1)
checks=[('web',BASE,{}),('login',BASE+'login.html',{}),('bootstrap',BASE+'hemocura-core/bootstrap.js',{}),('auth',project+'/auth/v1/health',{'apikey':public_key})]
report={'checked_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'checks':[]}
for name,url,headers in checks:
 try:
  req=urllib.request.Request(url,headers=headers)
  with urllib.request.urlopen(req,timeout=15) as response:
   status=response.status;body=response.read(256000)
  valid=status==200 and bool(body)
  if name=='auth':valid=valid and isinstance(json.loads(body),dict)
  report['checks'].append({'name':name,'http':status,'ok':valid})
 except Exception as error:
  report['checks'].append({'name':name,'ok':False,'error_type':type(error).__name__,'http':getattr(error,'code',None)})
print(json.dumps(report,indent=2))
raise SystemExit(0 if all(c['ok'] for c in report['checks']) else 1)
