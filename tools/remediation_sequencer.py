#!/usr/bin/env python3
"""HemoCura C13-L dependency-aware remediation sequencer.

Validates the planned remediation graph, checks required repository artifacts,
compares the verified Supabase state snapshot, detects out-of-order execution,
and reports exactly one next safe action. This tool never mutates Supabase.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
from typing import Any, Dict, List, Set

GATE = "C13-L"
VERSION = "0.44.19"


def load(path: str) -> Dict[str, Any]:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def stage_map(plan: Dict[str, Any]) -> Dict[str, Dict[str, Any]]:
    return {s["id"]: s for s in plan.get("stages", [])}


def validate_graph(plan: Dict[str, Any]) -> List[str]:
    errors: List[str] = []
    stages = plan.get("stages", [])
    ids = [s.get("id") for s in stages]
    if len(ids) != len(set(ids)):
        errors.append("duplicate stage id")
    m = stage_map(plan)
    for s in stages:
        for dep in s.get("depends_on", []):
            if dep not in m:
                errors.append(f"{s['id']}: missing dependency {dep}")

    visiting: Set[str] = set()
    visited: Set[str] = set()

    def dfs(node: str) -> None:
        if node in visiting:
            errors.append(f"cycle detected at {node}")
            return
        if node in visited or node not in m:
            return
        visiting.add(node)
        for dep in m[node].get("depends_on", []):
            dfs(dep)
        visiting.remove(node)
        visited.add(node)

    for sid in ids:
        dfs(sid)
    return errors


def artifact_paths(stage: Dict[str, Any]) -> List[str]:
    keys = ("candidate", "followup_candidate", "validator", "evidence_path")
    return [stage[k] for k in keys if stage.get(k)]


def validate_artifacts(plan: Dict[str, Any], repo_root: Path) -> List[str]:
    errors: List[str] = []
    for stage in plan.get("stages", []):
        for rel in artifact_paths(stage):
            if not (repo_root / rel).exists():
                errors.append(f"{stage['id']}: missing artifact {rel}")
    return errors


def is_complete(stage: Dict[str, Any], state: Dict[str, Any]) -> bool:
    typ = stage.get("type")
    if typ == "database":
        return stage.get("expected_version") in set(state.get("applied_versions", []))
    return stage["id"] in set(state.get("manual_complete", []))


def detect_out_of_order(plan: Dict[str, Any], state: Dict[str, Any]) -> List[str]:
    m = stage_map(plan)
    problems: List[str] = []
    for stage in plan.get("stages", []):
        if not is_complete(stage, state):
            continue
        for dep in stage.get("depends_on", []):
            if not is_complete(m[dep], state):
                problems.append(f"{stage['id']} completed before dependency {dep}")
    return problems


def next_safe_stage(plan: Dict[str, Any], state: Dict[str, Any]) -> Dict[str, Any] | None:
    m = stage_map(plan)
    for stage in plan.get("stages", []):
        if is_complete(stage, state):
            continue
        if all(is_complete(m[d], state) for d in stage.get("depends_on", [])):
            return stage
    return None


def summarize(plan: Dict[str, Any], state: Dict[str, Any], repo_root: Path) -> Dict[str, Any]:
    errors: List[str] = []
    if plan.get("gate") != GATE or plan.get("version") != VERSION:
        errors.append("plan gate/version mismatch")
    if state.get("gate") != GATE or state.get("version") != VERSION:
        errors.append("state gate/version mismatch")

    errors += validate_graph(plan)
    errors += validate_artifacts(plan, repo_root)
    out_of_order = detect_out_of_order(plan, state)
    errors += out_of_order

    nxt = next_safe_stage(plan, state) if not errors else None
    completed = [s["id"] for s in plan.get("stages", []) if is_complete(s, state)]
    pending = [s["id"] for s in plan.get("stages", []) if not is_complete(s, state)]

    return {
        "valid": not errors,
        "errors": errors,
        "gate": GATE,
        "version": VERSION,
        "completed_count": len(completed),
        "pending_count": len(pending),
        "completed": completed,
        "next_action": None if nxt is None else {
            "id": nxt["id"],
            "type": nxt["type"],
            "candidate": nxt.get("candidate"),
            "validator": nxt.get("validator"),
            "pr": nxt.get("pr"),
            "completion_rule": nxt.get("completion_rule"),
        },
        "release_doctor": state.get("release_doctor", {}),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("plan")
    parser.add_argument("state")
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()

    result = summarize(load(args.plan), load(args.state), Path(args.repo_root))
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["valid"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
