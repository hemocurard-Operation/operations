#!/usr/bin/env python3
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
capture = (ROOT / "hemocura-core" / "quick-capture.js").read_text(encoding="utf-8")
flow = (ROOT / "hemocura-core" / "quick-capture-flow.js").read_text(encoding="utf-8")
layout = (ROOT / "hemocura-core" / "layout.js").read_text(encoding="utf-8")
data = (ROOT / "hemocura-core" / "quick-capture-data.js").read_text(encoding="utf-8")
version_raw = (ROOT / "VERSION.json").read_text(encoding="utf-8")
version = json.loads(version_raw)

checks = []

def check(name, condition):
    checks.append((name, bool(condition)))

def version_tuple(value):
    try:
        parts = str(value or '').split('.')
        return tuple(int(x) for x in parts[:3])
    except (TypeError, ValueError):
        return (0, 0, 0)

check("version_at_least_0454", version_tuple(version.get("version")) >= (0, 45, 4))
check("blank_screening_result_option", '<option value="" selected>Seleccionar resultado…</option>' in capture)
check("screening_results_disabled_until_selected", 'class="qc-test-result" data-i="${i}" disabled' in capture)
check("explicit_result_validation", 'missing=selected.filter(x=>!x.result)' in capture)
check("no_screening_checkbox_default_checked", not re.search(r'class="qc-test-check"[^>]*\bchecked\b', capture))
check("donor_defaults_pending", '<option selected>PENDIENTE</option><option>ACEPTADO</option><option>DIFERIDO</option>' in capture)
check("deferred_disables_effective", "effective.disabled=true" in flow and "effective.checked=false" in flow)
check("deferred_reason_required", "reason.required=true" in flow and "if(optional) optional.open=true" in flow)
check("deferred_effective_submit_guard", "status.value==='DIFERIDO'&&effective.checked" in flow and "stopImmediatePropagation" in flow)
check("duplicate_requisition_guard", "duplicateValues(lines.map(x=>x.item_name))" in capture)
check("duplicate_dispatch_guard", "duplicateValues(lines.map(x=>x.product_id))" in capture)
check("dispatch_forced_draft", "status:'BORRADOR'" in data)
check("clinical_guardrail_copy", "No confirma, libera ni determina compatibilidad transfusional." in capture)
check("single_panel_launcher", "¿Qué vas a registrar?" in flow and "data-qc-open" in flow)
check("single_panel_accordion", "p.details.open=p.key===target.key" in flow)
check("last_panel_remembered", "localStorage.setItem(PANEL_KEY,target.key)" in flow)
check("role_default_panel", "ENCARGADA_LABORATORIO:'screening'" in flow and "ASISTENTE_OPERACIONES:'requisition'" in flow and "MEDICO_GERENTE_TECNICO:'incident'" in flow)
check("single_branch_preselection", "candidates.length!==1" in flow and "branch.dispatchEvent(new Event('change'" in flow)
check("incident_progressive_disclosure", "affected.checked||followup.checked||Number(severity.value)>=4" in flow)
check("panel_focus_assist", "focusFirstField(target)" in flow)
check("no_clinical_result_persistence", "qc-test-result" not in flow and "SCREEN_KEY" not in flow and "screening_defaults" not in flow)
check("flow_integrated_after_mount", "if(route==='quickcapture') enhanceQuickCaptureFlow(root,primaryRole);" in layout)
check("protected_config_not_referenced", "js/config.js" not in capture and "js/config.js" not in flow)

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'} {name}")
if failed:
    print(f"\nFAILED: {', '.join(failed)}")
    sys.exit(1)
print(f"\nPASS {len(checks)}/{len(checks)} quick-capture safety checks")
