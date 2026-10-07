#!/usr/bin/env python3
"""HemoCura S06 · Frontend RPC Cutover Gate.

Fail closed when canonical browser code still calls the three legacy RPCs
replaced by C13-C2A wrappers. This is a static repository gate; it does not
connect to Supabase and does not replace runtime smoke/UAT.
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]

CHECKS = {
    "hemocura-core/sales-data.js": ("adjust_sale_line", "hc_adjust_sale_line"),
    "hemocura-core/costs-data.js": ("calculate_monthly_product_costs", "hc_calculate_monthly_product_costs"),
    "hemocura-core/settings-data.js": ("production_healthcheck", "hc_production_healthcheck"),
}

RPC_RE = re.compile(r"\.rpc\(\s*['\"]([^'\"]+)['\"]")


def main() -> int:
    errors = []
    for rel, (legacy, wrapper) in CHECKS.items():
        path = ROOT / rel
        text = path.read_text(encoding="utf-8")
        calls = RPC_RE.findall(text)
        if wrapper not in calls:
            errors.append(f"{rel}: missing wrapper RPC {wrapper}")
        if legacy in calls:
            errors.append(f"{rel}: legacy RPC still active: {legacy}")

    # Global fail-closed check across active browser source trees.
    forbidden = {legacy for legacy, _ in CHECKS.values()}
    global_hits = []
    for folder in (ROOT / "hemocura-core", ROOT / "js"):
        for path in folder.rglob("*.js"):
            for rpc in RPC_RE.findall(path.read_text(encoding="utf-8")):
                if rpc in forbidden:
                    global_hits.append(f"{path.relative_to(ROOT)} -> {rpc}")
    if global_hits:
        errors.append("Legacy RPC calls remain: " + "; ".join(sorted(global_hits)))

    if errors:
        print("S06 FRONTEND RPC CUTOVER: STOP")
        for err in errors:
            print(f"- {err}")
        return 1

    print("S06 FRONTEND RPC CUTOVER: PASS")
    for rel, (_, wrapper) in CHECKS.items():
        print(f"- {rel}: {wrapper}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
