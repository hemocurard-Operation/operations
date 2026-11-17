"""Check literal hash destinations; runtime role/module checks are tested in browsers."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
core=ROOT/'hemocura-core'
routes=set(re.findall(r'^\s*(\w+):\{title:',(core/'router.js').read_text(),re.M))
permission_block=(core/'access-control.js').read_text().split('export const ROUTE_PERMISSION={',1)[1].split('};',1)[0]
permissions=set(re.findall(r"(\w+):'[^']+'",permission_block))
mounted=set()
for filename,marker in [('route-mounts.js','export const MOUNTS={'),('workflow-mounts.js','export const WORKFLOW_MOUNTS={')]:
 source=(core/filename).read_text().split(marker,1)[1].split('};',1)[0]
 mounted.update(re.findall(r'(\w+)\s*:\s*\w+',source))
issues=[];links=[]
for file in sorted(core.glob('*.js')):
 for number,line in enumerate(file.read_text().splitlines(),1):
  for key in re.findall(r'''href=["']#([A-Za-z][\w-]*)["']''',line):
   links.append((file.name,number,key))
   missing=[name for name,keys in [('route',routes),('mount',mounted),('permission',permissions)] if key not in keys]
   if missing:issues.append(f'{file.name}:{number}: {key}: missing {", ".join(missing)}')
if issues:raise SystemExit('\n'.join(issues))
print(f'PASS {len(links)} literal navigation links resolve to a registered, mounted, permission-mapped route; runtime access is checked separately.')
