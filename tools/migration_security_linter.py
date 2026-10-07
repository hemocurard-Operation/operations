#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, re, subprocess
from dataclasses import dataclass
from pathlib import Path

RULES = {
    "HC001": "CREATE TABLE in public must enable RLS in the same migration.",
    "HC002": "GRANT ALL/ALL PRIVILEGES to PUBLIC, anon or authenticated is forbidden.",
    "HC003": "SECURITY DEFINER functions must declare SET search_path.",
    "HC004": "Browser EXECUTE must not be granted to PUBLIC or anon.",
    "HC005": "ALTER DEFAULT PRIVILEGES must not grant to PUBLIC, anon or authenticated.",
    "HC006": "DISABLE ROW LEVEL SECURITY is forbidden.",
    "HC007": "Broad authenticated FOR ALL policy is forbidden.",
    "HC008": "New public views must be security_invoker=true.",
    "HC009": "TRUNCATE requires an explicit lint waiver with reason.",
    "HC010": "Known clinical feature flags must not be activated in ordinary migrations.",
}

@dataclass
class Finding:
    rule: str
    severity: str
    path: str
    line: int
    message: str

ALLOW_RE = re.compile(r"--\s*hc-lint:\s*allow=([A-Z0-9_, -]+)\s+reason=(.+)$", re.I)
CREATE_TABLE_RE = re.compile(r"\bcreate\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?([a-zA-Z_][\w$]*)", re.I)
ENABLE_RLS_RE = re.compile(r"\balter\s+table\s+(?:only\s+)?(?:public\.)?([a-zA-Z_][\w$]*)\s+enable\s+row\s+level\s+security\b", re.I)
CREATE_VIEW_RE = re.compile(r"\bcreate\s+(?:or\s+replace\s+)?view\s+(?:public\.)?([a-zA-Z_][\w$]*)\b", re.I)
SECURITY_DEFINER_RE = re.compile(r"\bsecurity\s+definer\b", re.I)
SET_SEARCH_PATH_RE = re.compile(r"\bset\s+search_path\s*=", re.I)
GRANT_ALL_RE = re.compile(r"\bgrant\s+all(?:\s+privileges)?\b[\s\S]{0,500}?\bto\s+(public|anon|authenticated)\b", re.I)
GRANT_EXECUTE_RE = re.compile(r"\bgrant\s+execute\b[\s\S]{0,500}?\bto\s+(public|anon)\b", re.I)
ALTER_DEFAULT_GRANT_RE = re.compile(r"\balter\s+default\s+privileges\b[\s\S]{0,800}?\bgrant\b[\s\S]{0,500}?\bto\s+(public|anon|authenticated)\b", re.I)
DISABLE_RLS_RE = re.compile(r"\bdisable\s+row\s+level\s+security\b", re.I)
BROAD_POLICY_RE = re.compile(
    r"\bcreate\s+policy\b[\s\S]{0,1000}?\bfor\s+all\b[\s\S]{0,1000}?"
    r"(?:auth\.role\s*\(\s*\)\s*=\s*'authenticated'|'authenticated'\s*=\s*auth\.role\s*\(\s*\))",
    re.I,
)
TRUNCATE_RE = re.compile(r"\btruncate(?:\s+table)?\b", re.I)
CLINICAL_RE = re.compile(
    r"(clinical_fefo|cold_chain_auto_block|donor_to_recipient_traceability)[\s\S]{0,180}?"
    r"(?:'LIVE'|'LIVE_LIMITED'|enabled\s*=\s*true|,\s*true\b)",
    re.I,
)

def line_of(text: str, pos: int) -> int:
    return text.count("\n", 0, pos) + 1

def waivers(text: str) -> dict[str, str]:
    out = {}
    for line in text.splitlines():
        m = ALLOW_RE.search(line)
        if not m:
            continue
        reason = m.group(2).strip().strip('"').strip("'")
        for rid in re.split(r"[\s,]+", m.group(1).upper().strip()):
            if rid:
                out[rid] = reason
    return out

def add(findings, waived, rule, sev, path, text, pos, message):
    if rule in waived:
        return
    findings.append(Finding(rule, sev, path, line_of(text, pos), message))

def lint_file(path: Path) -> list[Finding]:
    text = path.read_text(encoding="utf-8")
    waived = waivers(text)
    findings: list[Finding] = []

    created = {m.group(1).lower(): m.start() for m in CREATE_TABLE_RE.finditer(text)}
    enabled = {m.group(1).lower() for m in ENABLE_RLS_RE.finditer(text)}
    for table, pos in created.items():
        if table not in enabled:
            add(findings, waived, "HC001", "ERROR", str(path), text, pos,
                f"public.{table}: CREATE TABLE without ENABLE ROW LEVEL SECURITY in this migration.")

    for m in GRANT_ALL_RE.finditer(text):
        add(findings, waived, "HC002", "ERROR", str(path), text, m.start(),
            f"GRANT ALL to {m.group(1)} is not allowed.")

    fn_starts = [m.start() for m in re.finditer(r"\bcreate\s+(?:or\s+replace\s+)?function\b", text, re.I)]
    for i, start in enumerate(fn_starts):
        end = fn_starts[i+1] if i+1 < len(fn_starts) else len(text)
        block = text[start:end]
        sec = SECURITY_DEFINER_RE.search(block)
        if sec and not SET_SEARCH_PATH_RE.search(block):
            add(findings, waived, "HC003", "ERROR", str(path), text, start + sec.start(),
                "SECURITY DEFINER function found without SET search_path.")

    for m in GRANT_EXECUTE_RE.finditer(text):
        add(findings, waived, "HC004", "ERROR", str(path), text, m.start(),
            f"GRANT EXECUTE to {m.group(1)} is not allowed.")

    for m in ALTER_DEFAULT_GRANT_RE.finditer(text):
        add(findings, waived, "HC005", "ERROR", str(path), text, m.start(),
            f"ALTER DEFAULT PRIVILEGES grants future access to {m.group(1)}.")

    for m in DISABLE_RLS_RE.finditer(text):
        add(findings, waived, "HC006", "ERROR", str(path), text, m.start(),
            "DISABLE ROW LEVEL SECURITY is forbidden.")

    for m in BROAD_POLICY_RE.finditer(text):
        add(findings, waived, "HC007", "ERROR", str(path), text, m.start(),
            "FOR ALL policy based only on authenticated role is too broad.")

    for m in CREATE_VIEW_RE.finditer(text):
        start = m.start()
        window = text[start:min(len(text), start+700)]
        if not re.search(r"security_invoker\s*=\s*true", window, re.I):
            add(findings, waived, "HC008", "ERROR", str(path), text, start,
                f"public.{m.group(1)}: view should declare security_invoker=true.")

    for m in TRUNCATE_RE.finditer(text):
        add(findings, waived, "HC009", "ERROR", str(path), text, m.start(),
            "TRUNCATE requires -- hc-lint: allow=HC009 reason=\"...\".")

    for m in CLINICAL_RE.finditer(text):
        add(findings, waived, "HC010", "ERROR", str(path), text, m.start(),
            "Clinical feature activation requires a dedicated reviewed migration and explicit waiver.")

    for rid, reason in waived.items():
        if rid not in RULES:
            findings.append(Finding("HC000", "ERROR", str(path), 1, f"Unknown waiver rule: {rid}."))
        elif len(reason) < 12:
            findings.append(Finding("HC000", "ERROR", str(path), 1, f"Waiver {rid} reason is too short."))

    return findings

def git_changed(base: str) -> list[Path]:
    cp = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=ACMR", f"{base}...HEAD", "--", "sql/migrations"],
        check=True, text=True, capture_output=True
    )
    return [Path(x) for x in cp.stdout.splitlines() if x.strip().endswith(".sql") and Path(x).exists()]

def main():
    ap = argparse.ArgumentParser(description="HemoCura migration security linter")
    ap.add_argument("files", nargs="*", help="SQL files to lint")
    ap.add_argument("--git-base", help="Lint governed SQL changed since this git ref")
    ap.add_argument("--all", action="store_true", help="Lint all sql/migrations/**/*.sql")
    ap.add_argument("--json-out", help="Write JSON report")
    args = ap.parse_args()

    files = [Path(x) for x in args.files]
    if args.git_base:
        files += git_changed(args.git_base)
    if args.all:
        files += list(Path("sql/migrations").rglob("*.sql"))
    seen=set()
    dedup=[]
    for p in files:
        if str(p) not in seen:
            seen.add(str(p)); dedup.append(p)
    files=dedup

    if not files:
        print("HC-LINT PASS: no changed governed SQL migrations.")
        return 0

    findings=[]
    for p in files:
        findings.extend(lint_file(p))

    errors=[f for f in findings if f.severity=="ERROR"]
    for f in findings:
        level = "error" if f.severity=="ERROR" else "warning"
        print(f"::{level} file={f.path},line={f.line},title={f.rule}::{f.message}")

    report = {
        "status": "FAIL" if errors else "PASS",
        "files": [str(p) for p in files],
        "findings": [f.__dict__ for f in findings],
        "rules": RULES,
    }
    if args.json_out:
        Path(args.json_out).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    if errors:
        print(f"HC-LINT FAIL: {len(errors)} error(es) in {len(files)} file(s).")
        return 1
    print(f"HC-LINT PASS: {len(files)} file(s), 0 errors.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
