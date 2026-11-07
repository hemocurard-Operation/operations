"""Bound complete static module graphs, rather than a hand-picked set of source files."""
from pathlib import Path
import re,json
ROOT=Path(__file__).resolve().parents[1]
IMPORT=re.compile(r"(?:\bimport\s+(?:[^;]*?\s+from\s+)?|\bexport\s+[^;]*?\s+from\s+)[\"']([^\"']+)[\"']")
def graph(entry):
 seen=set()
 def visit(path):
  path=path.resolve()
  if path in seen:return
  if not path.is_relative_to(ROOT) or not path.is_file():raise RuntimeError('Missing or invalid module: '+str(path))
  seen.add(path)
  for spec in IMPORT.findall(path.read_text()):
   if spec.startswith('.'):visit(path.parent/spec)
 visit(ROOT/entry)
 return {'modules':len(seen),'bytes':sum(p.stat().st_size for p in seen)}
checks=[('anonymous_boot','hemocura-core/bootstrap.js',20,300000),('authorized_shell','hemocura-core/layout.js',30,350000)]
for name,path,max_modules,max_bytes in checks:
 result=graph(path);print(json.dumps({'check':name,**result,'max_modules':max_modules,'max_bytes':max_bytes}))
 if result['modules']>max_modules or result['bytes']>max_bytes:raise SystemExit('FAIL startup graph budget: '+name)
print('PASS complete startup graph budgets')
