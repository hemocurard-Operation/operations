"""Regression invariants for the bounded legacy-access repair."""
import pathlib,re,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class SuperAccessMigration(unittest.TestCase):
 def setUp(self):
  paths=list((ROOT/'supabase/migrations').glob('*_superuser_operational_access.sql'))
  self.assertEqual(len(paths),1)
  self.sql=paths[0].read_text()
 def test_seven_function_bodies_preserve_workflow_checks(self):
  sources={
   '20261102160000_inspection_findings_capa_link.sql':['inspection_finding_to_nonconformity','inspection_finding_create_capa'],
   '20261103130000_iso_compliance_checklist.sql':['iso_clause_assessment_upsert','iso_clause_assessment_create_nc'],
  }
  pairs=[(ROOT/'supabase/migrations'/file,name) for file,names in sources.items() for name in names]
  pairs.append((ROOT/'sql/C13C_02_CONTROLLED_RPC_WRAPPERS_CANDIDATE.sql','hc_generate_management_alerts'))
  pairs.extend((ROOT/'sql/33_INTERNAL_AUDITS_v0_33.sql',name) for name in ['audit_finding_to_nonconformity','audit_finding_create_capa'])
  pattern=lambda name:r'create or replace function public\.'+name+r'\([\s\S]+?\n\$\$;'
  for file,name in pairs:
   with self.subTest(function=name):
    original=re.search(pattern(name),file.read_text()).group(0)
    candidate=re.search(pattern(name),self.sql).group(0)
    prefix="(public.wf_active_actor() and public.has_role('SUPER_USUARIO')) or "
    self.assertEqual(candidate.replace(prefix,''),original)
    self.assertIn('security definer' if name=='hc_generate_management_alerts' else 'security invoker',candidate)
 def test_policy_repair_is_a_fixed_allowlist_and_preserves_expression_terms(self):
  block=self.sql.split('do $legacy_admin$')[1]
  targets=re.findall(r"\('([a-z_]+)','([a-z_]+)'\)",block)
  self.assertEqual(len(targets),34)
  self.assertFalse(any(table.startswith('monthly_') or table in ['daily_sales','daily_sale_lines','screening_tests','donations','blood_inventory_units'] for table,_ in targets))
  self.assertIn("tablename=item.table_name and policyname=item.policy_name",block)
  self.assertIn("raise exception 'Legacy ADMIN guard changed",block)
  self.assertIn('replace(current_policy.qual,old_gate,new_gate)',block)
  self.assertIn('replace(current_policy.with_check,old_gate,new_gate)',block)
  self.assertNotRegex(self.sql.lower(),r'grant\s+(all|insert|update|delete)|disable\s+row\s+level')
 def test_new_modules_do_not_automatically_activate_other_roles(self):
  self.assertEqual(self.sql.lower().count('security definer'),1)
  self.assertIn("select r.id,m.route_key,r.code='SUPER_USUARIO'",self.sql)
  self.assertIn("('maintenance'",self.sql)
  self.assertIn("('congresses'",self.sql)
  self.assertIn("('supplytransfers'",self.sql)
if __name__=='__main__':unittest.main()
