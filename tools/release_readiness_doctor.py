#!/usr/bin/env python3
"""HemoCura C13-K composite release readiness doctor.

This tool validates a captured read-only Supabase snapshot and recomputes the
release decision. It does not connect to Supabase and does not mutate anything.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
from typing import Any, Dict, List

VERSION = "0.44.18"
GATE = "C13-K"

REQUIRED_COMPONENTS = (
    "database",
    "schema_drift",
    "rls",
    "rpc_security",
    "anon_surface",
    "role_model",
    "clinical_guardrails",
    "uat",
    "signoffs",
)

def expected_components(snapshot: Dict[str, Any]) -> Dict[str, str]:
    c = snapshot["counts"]
    db = snapshot["database"]
    clinical = snapshot["clinical"]
    uat = snapshot["uat"]
    signoffs = snapshot["signoffs"]

    database = "PASS" if (
        db["migration_0_44_0"]
        and db["legacy_backend_ready"]
        and db["legacy_release_objects_ready"]
    ) else "STOP"

    schema_drift = "PASS" if (
        c["missing_relations"] == 0
        and c["missing_rpcs"] == 0
        and c["missing_critical_columns"] == 0
        and c["forbidden_columns_present"] == 0
    ) else "STOP"

    rls = "PASS" if (
        c["rls_off_tables"] == 0
        and c["rls_no_policy_tables"] == 0
        and c["broad_authenticated_policies"] == 0
    ) else "STOP"

    rpc_security = "PASS" if (
        c["missing_rpcs"] == 0
        and c["anon_executable_security_definer"] == 0
        and c["callable_without_fixed_search_path"] == 0
    ) else "STOP"

    anon_surface = "PASS" if c["anon_dml_grants"] == 0 else "STOP"
    role_model = "PASS" if c["missing_required_roles"] == 0 else "STOP"

    if (
        clinical["any_clinical_automation_flag_enabled"]
        or clinical["clinical_dispatch"]
        or clinical["temperature_blocking"]
        or clinical["donor_recipient_traceability"]
    ):
        clinical_guardrails = "STOP"
    elif clinical.get("c14_registered", False):
        clinical_guardrails = "PASS"
    elif clinical["mode"] == "LIVE_LIMITED":
        clinical_guardrails = "SAFE_LIMITED"
    else:
        clinical_guardrails = "REVIEW"

    uat_status = "PASS" if (
        uat["runs"] > 0
        and uat["passed_runs"] > 0
        and uat["results"] >= uat["active_cases"]
        and uat["critical_failures"] == 0
    ) else "STOP"

    signoffs_status = "PASS" if (
        signoffs["approved"] == 4
        and signoffs["approved_types"] == 4
        and signoffs["rejected"] == 0
    ) else "STOP"

    return {
        "database": database,
        "schema_drift": schema_drift,
        "rls": rls,
        "rpc_security": rpc_security,
        "anon_surface": anon_surface,
        "role_model": role_model,
        "clinical_guardrails": clinical_guardrails,
        "uat": uat_status,
        "signoffs": signoffs_status,
    }

def expected_final(components: Dict[str, str]) -> str:
    return "READY" if all(components[k] == "PASS" for k in REQUIRED_COMPONENTS) else "NOT_READY"

def validate_snapshot(snapshot: Dict[str, Any]) -> Dict[str, Any]:
    errors: List[str] = []
    if snapshot.get("gate") != GATE:
        errors.append(f"gate must be {GATE}")
    if snapshot.get("version") != VERSION:
        errors.append(f"version must be {VERSION}")

    for key in ("counts", "database", "clinical", "uat", "signoffs", "components"):
        if key not in snapshot or not isinstance(snapshot[key], dict):
            errors.append(f"missing object: {key}")

    if errors:
        return {"valid": False, "errors": errors}

    recomputed = expected_components(snapshot)
    declared = snapshot["components"]
    for key in REQUIRED_COMPONENTS:
        if declared.get(key) != recomputed[key]:
            errors.append(
                f"component {key}: declared={declared.get(key)!r}, expected={recomputed[key]!r}"
            )

    recomputed_final = expected_final(recomputed)
    if snapshot.get("final_release_gate") != recomputed_final:
        errors.append(
            "final_release_gate: "
            f"declared={snapshot.get('final_release_gate')!r}, expected={recomputed_final!r}"
        )

    return {
        "valid": not errors,
        "errors": errors,
        "gate": GATE,
        "version": VERSION,
        "components": recomputed,
        "final_release_gate": recomputed_final,
        "blocker_count": len(snapshot.get("blockers", [])),
    }

def load(path: str) -> Dict[str, Any]:
    return json.loads(Path(path).read_text(encoding="utf-8"))

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("snapshot")
    parser.add_argument("--enforce-ready", action="store_true",
                        help="Exit non-zero unless the validated snapshot is READY.")
    args = parser.parse_args()

    result = validate_snapshot(load(args.snapshot))
    print(json.dumps(result, ensure_ascii=False, indent=2))

    if not result["valid"]:
        return 2
    if args.enforce_ready and result["final_release_gate"] != "READY":
        return 3
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
