#!/usr/bin/env python3
"""HemoCura C13-J · Schema Drift & Runtime Contract Gate.

Stdlib-only tool. It has three jobs:
  1) extract Supabase relation/RPC references from frontend JavaScript;
  2) verify that code references are declared in a runtime contract manifest;
  3) compare that manifest with a read-only Supabase catalog snapshot.

It never connects to Supabase by itself and never mutates a database.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, List, Set, Tuple

FROM_RE = re.compile(r"\.from\(\s*['\"]([^'\"]+)['\"]\s*\)")
RPC_RE = re.compile(r"\.rpc\(\s*['\"]([^'\"]+)['\"]")


def js_files(root: Path) -> Iterable[Path]:
    for folder in (root / "hemocura-core", root / "js"):
        if folder.exists():
            yield from sorted(folder.rglob("*.js"))


def extract_frontend_refs(root: Path) -> Dict[str, List[str]]:
    relations: Set[str] = set()
    rpcs: Set[str] = set()
    files_scanned = 0
    for path in js_files(root):
        text = path.read_text(encoding="utf-8")
        files_scanned += 1
        relations.update(FROM_RE.findall(text))
        rpcs.update(RPC_RE.findall(text))
    return {
        "relations": sorted(relations),
        "rpcs": sorted(rpcs),
        "files_scanned": files_scanned,
    }


def load_json(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as fh:
        value = json.load(fh)
    if not isinstance(value, dict):
        raise ValueError(f"{path}: JSON root must be an object")
    return value


def relation_names(snapshot: Dict[str, Any]) -> Set[str]:
    values: Set[str] = set()
    for item in snapshot.get("relations", []):
        if isinstance(item, str):
            values.add(item)
        elif isinstance(item, dict):
            name = item.get("object_name") or item.get("table_name") or item.get("name")
            if name:
                values.add(str(name))
    return values


def function_names(snapshot: Dict[str, Any]) -> Set[str]:
    values: Set[str] = set()
    for item in snapshot.get("functions", []):
        if isinstance(item, str):
            values.add(item)
        elif isinstance(item, dict):
            name = item.get("proname") or item.get("function_name") or item.get("name")
            if name:
                values.add(str(name))
    return values


def column_pairs(snapshot: Dict[str, Any]) -> Set[Tuple[str, str]]:
    values: Set[Tuple[str, str]] = set()
    for item in snapshot.get("columns", []):
        if not isinstance(item, dict):
            continue
        table = item.get("table_name") or item.get("object_name")
        column = item.get("column_name") or item.get("name")
        if table and column:
            values.add((str(table), str(column)))
    return values


def migration_versions(snapshot: Dict[str, Any]) -> Set[str]:
    values: Set[str] = set()
    for item in snapshot.get("migrations", []):
        if isinstance(item, dict) and item.get("version") is not None:
            values.add(str(item["version"]))
    return values


def migration_codes(snapshot: Dict[str, Any]) -> Set[str]:
    values: Set[str] = set()
    for item in snapshot.get("migrations", []):
        if isinstance(item, dict) and item.get("migration_code"):
            values.add(str(item["migration_code"]))
    return values


def declared_set(contract: Dict[str, Any], key: str) -> Set[str]:
    raw = contract.get(key, [])
    if not isinstance(raw, list):
        raise ValueError(f"contract.{key} must be an array")
    return {str(x) for x in raw}


def check_code(root: Path, contract: Dict[str, Any]) -> Dict[str, Any]:
    refs = extract_frontend_refs(root)
    declared_relations = declared_set(contract, "relations") | declared_set(contract, "optional_relations")
    declared_rpcs = declared_set(contract, "rpcs") | declared_set(contract, "optional_rpcs")
    ignored_relations = declared_set(contract, "ignored_relations")
    ignored_rpcs = declared_set(contract, "ignored_rpcs")

    missing_rel = sorted(set(refs["relations"]) - declared_relations - ignored_relations)
    missing_rpc = sorted(set(refs["rpcs"]) - declared_rpcs - ignored_rpcs)
    return {
        "ok": not missing_rel and not missing_rpc,
        "files_scanned": refs["files_scanned"],
        "frontend_relations": refs["relations"],
        "frontend_rpcs": refs["rpcs"],
        "undeclared_relations": missing_rel,
        "undeclared_rpcs": missing_rpc,
    }


def check_snapshot(contract: Dict[str, Any], snapshot: Dict[str, Any]) -> Dict[str, Any]:
    rels = relation_names(snapshot)
    funcs = function_names(snapshot)
    cols = column_pairs(snapshot)
    versions = migration_versions(snapshot)
    codes = migration_codes(snapshot)

    required_rel = declared_set(contract, "relations")
    required_rpc = declared_set(contract, "rpcs")
    missing_rel = sorted(required_rel - rels)
    missing_rpc = sorted(required_rpc - funcs)

    missing_columns: List[str] = []
    critical_columns = contract.get("critical_columns", {})
    if not isinstance(critical_columns, dict):
        raise ValueError("contract.critical_columns must be an object")
    for table, required in critical_columns.items():
        if not isinstance(required, list):
            raise ValueError(f"critical_columns.{table} must be an array")
        for column in required:
            if (str(table), str(column)) not in cols:
                missing_columns.append(f"{table}.{column}")

    forbidden_present: List[str] = []
    forbidden_columns = contract.get("forbidden_columns", {})
    if not isinstance(forbidden_columns, dict):
        raise ValueError("contract.forbidden_columns must be an object")
    for table, forbidden in forbidden_columns.items():
        for column in forbidden:
            if (str(table), str(column)) in cols:
                forbidden_present.append(f"{table}.{column}")

    req_versions = declared_set(contract, "required_migration_versions")
    req_codes = declared_set(contract, "required_migration_codes")
    missing_versions = sorted(req_versions - versions)
    missing_codes = sorted(req_codes - codes)

    ok = not any((missing_rel, missing_rpc, missing_columns, forbidden_present, missing_versions, missing_codes))
    return {
        "ok": ok,
        "missing_relations": missing_rel,
        "missing_rpcs": missing_rpc,
        "missing_columns": sorted(missing_columns),
        "forbidden_columns_present": sorted(forbidden_present),
        "missing_migration_versions": missing_versions,
        "missing_migration_codes": missing_codes,
    }


def emit(value: Dict[str, Any]) -> None:
    print(json.dumps(value, indent=2, ensure_ascii=False, sort_keys=True))


def main(argv: List[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("extract")

    p_code = sub.add_parser("check-code")
    p_code.add_argument("contract")

    p_runtime = sub.add_parser("check-runtime")
    p_runtime.add_argument("contract")
    p_runtime.add_argument("snapshot")

    args = parser.parse_args(argv)
    root = Path(args.root).resolve()

    try:
        if args.command == "extract":
            emit(extract_frontend_refs(root))
            return 0
        contract = load_json(Path(args.contract))
        if args.command == "check-code":
            result = check_code(root, contract)
        else:
            result = check_snapshot(contract, load_json(Path(args.snapshot)))
        emit(result)
        return 0 if result["ok"] else 1
    except Exception as exc:
        print(f"C13-J ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
