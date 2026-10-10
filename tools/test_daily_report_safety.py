#!/usr/bin/env python3
from pathlib import Path
import json
import sys

ROOT=Path(__file__).resolve().parents[1]
report=(ROOT/'hemocura-core'/'daily-inventory.js').read_text(encoding='utf-8')
flow=(ROOT/'hemocura-core'/'daily-inventory-flow.js').read_text(encoding='utf-8')
layout=(ROOT/'hemocura-core'/'layout.js').read_text(encoding='utf-8')
version=json.loads((ROOT/'VERSION.json').read_text(encoding='utf-8'))

checks=[]
def check(name,condition): checks.append((name,bool(condition)))
def vt(v):
    try:return tuple(int(x) for x in str(v).split('.')[:3])
    except:return (0,0,0)

check('version_at_least_0456',vt(version.get('version'))>=(0,45,6))
check('daily_report_mount_preserved',"dailyinventory:mountDailyInventory" in layout)
check('ergonomics_after_mount',"if(route==='dailyinventory') enhanceDailyInventoryFlow(root);" in layout)
check('explicit_previous_inventory_click',"addEventListener('click',()=>copyPreviousInventory" in flow)
check('physical_verification_required','verificar físicamente' in flow.lower() and 'requiere verificación física' in flow.lower())
check('confirmation_before_copy','confirm(`Se copiará el inventario' in flow)
check('no_previous_inventory_autoload',"copyPreviousInventory(root,button)" in flow and "addEventListener('click'" in flow)
check('no_localstorage_in_daily_flow','localStorage' not in flow)
check('no_direct_rpc_in_daily_flow','.rpc(' not in flow)
check('no_service_role','service_role' not in flow.lower() and 'service_role' not in report.lower())
check('no_screening_interpretation','No interpreta resultados ni decide liberación.' in report)
check('close_is_report_only','no libera componentes sanguíneos' in report.lower())
check('save_forces_draft',"p_status:'BORRADOR'" in (ROOT/'hemocura-core'/'command-data.js').read_text(encoding='utf-8'))
check('empty_activity_hides_without_erasing','body.hidden=checkbox.checked' in flow and '.remove()' not in flow)
check('escaped_dynamic_error','esc(error?.message||error)' in flow)

failed=[name for name,ok in checks if not ok]
for name,ok in checks: print(f"{'PASS' if ok else 'FAIL'} {name}")
if failed:
    print('\nFAILED: '+', '.join(failed))
    sys.exit(1)
print(f"\nPASS {len(checks)}/{len(checks)} daily-report safety checks")
