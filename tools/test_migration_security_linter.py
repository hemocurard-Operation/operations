import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("hc_lint", Path(__file__).with_name("migration_security_linter.py"))
hc = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = hc
SPEC.loader.exec_module(hc)

class MigrationSecurityLinterTests(unittest.TestCase):
    def lint(self, sql: str):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "x.sql"
            p.write_text(sql, encoding="utf-8")
            return hc.lint_file(p)

    def rules(self, sql: str):
        return {f.rule for f in self.lint(sql)}

    def test_secure_table_passes(self):
        sql = """
        create table public.demo(id uuid primary key);
        alter table public.demo enable row level security;
        create policy demo_select on public.demo for select to authenticated using (true);
        """
        self.assertEqual(self.lint(sql), [])

    def test_missing_rls_fails(self):
        self.assertIn("HC001", self.rules("create table public.demo(id int);"))

    def test_grant_all_fails(self):
        self.assertIn("HC002", self.rules("grant all privileges on table public.demo to authenticated;"))

    def test_security_definer_without_search_path_fails(self):
        sql = """create or replace function public.demo() returns int
        language sql security definer as $$ select 1 $$;"""
        self.assertIn("HC003", self.rules(sql))

    def test_security_definer_with_search_path_passes_hc003(self):
        sql = """create or replace function public.demo() returns int
        language sql security definer set search_path='' as $$ select 1 $$;"""
        self.assertNotIn("HC003", self.rules(sql))

    def test_anon_execute_fails(self):
        self.assertIn("HC004", self.rules("grant execute on function public.demo() to anon;"))

    def test_disable_rls_fails(self):
        self.assertIn("HC006", self.rules("alter table public.demo disable row level security;"))

    def test_broad_policy_fails(self):
        sql = """create policy p on public.demo for all
        using(auth.role()='authenticated')
        with check(auth.role()='authenticated');"""
        self.assertIn("HC007", self.rules(sql))

    def test_view_without_security_invoker_fails(self):
        self.assertIn("HC008", self.rules("create view public.v_demo as select 1 as x;"))

    def test_view_security_invoker_passes(self):
        sql = "create view public.v_demo with (security_invoker=true) as select 1 as x;"
        self.assertNotIn("HC008", self.rules(sql))

    def test_truncate_can_be_waived_with_reason(self):
        sql = """-- hc-lint: allow=HC009 reason=\"Controlled cleanup of ephemeral staging rows\"
        truncate table public.stage_demo;"""
        self.assertNotIn("HC009", self.rules(sql))

    def test_short_waiver_reason_fails(self):
        sql = """-- hc-lint: allow=HC009 reason=\"cleanup\"
        truncate table public.stage_demo;"""
        self.assertIn("HC000", self.rules(sql))

if __name__ == "__main__":
    unittest.main()
