#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
capture = (ROOT / "hemocura-core" / "quick-capture.js").read_text(encoding="utf-8")
data = (ROOT / "hemocura-core" / "quick-capture-data.js").read_text(encoding="utf-8")
version = (ROOT / "VERSION.json").read_text(encoding="utf-8")

checks = []

def check(name, condition):
    checks.append((name, bool(condition)))

check("version_0452", '"version": "0.45.2"' in version)
check("blank_screening_result_option", '<option value="" selected>Seleccionar resultado…</option>' in capture)
check("screening_results_disabled_until_selected", 'class="qc-test-result" data-i="${i}" disabled' in capture)
check("explicit_result_validation", 'missing=selected.filter(x=>!x.result)' in capture)
check("no_screening_checkbox_default_checked", not re.search(r'class="qc-test-check"[^>]*\bchecked\b', capture))
check("donor_defaults_pending", '<option selected>PENDIENTE</option><option>ACEPTADO</option><option>DIFERIDO</option>' in capture)
check("duplicate_requisition_guard", "duplicateValues(lines.map(x=>x.item_name))" in capture)
check("duplicate_dispatch_guard", "duplicateValues(lines.map(x=>x.product_id))" in capture)
check("dispatch_forced_draft", "status:'BORRADOR'" in data)
check("clinical_guardrail_copy", "No confirma, libera ni determina compatibilidad transfusional." in capture)
check("protected_config_not_referenced", "js/config.js" not in capture)

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'} {name}")
if failed:
    print(f"\nFAILED: {', '.join(failed)}")
    sys.exit(1)
print(f"\nPASS {len(checks)}/{len(checks)} quick-capture safety checks")
