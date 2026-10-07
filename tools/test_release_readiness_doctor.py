import copy
import json
import unittest
from pathlib import Path

from release_readiness_doctor import validate_snapshot

ROOT = Path(__file__).resolve().parents[1]
SNAPSHOT = ROOT / 'contracts' / 'release-readiness-snapshot-v0.44.18.json'


class ReleaseReadinessDoctorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base = json.loads(SNAPSHOT.read_text(encoding='utf-8'))

    def test_verified_snapshot_is_valid_but_not_ready(self):
        result = validate_snapshot(copy.deepcopy(self.base))
        self.assertTrue(result['valid'])
        self.assertEqual(result['final_release_gate'], 'NOT_READY')

    def test_ready_requires_all_components_pass(self):
        s = copy.deepcopy(self.base)
        c = s['counts']
        c.update({
            'rls_no_policy_tables': 0,
            'broad_authenticated_policies': 0,
            'anon_dml_grants': 0,
            'anon_dml_tables': 0,
            'anon_executable_security_definer': 0,
            'callable_without_fixed_search_path': 0,
            'missing_required_roles': 0,
        })
        s['missing_required_roles'] = []
        s['clinical']['c14_registered'] = True
        s['uat'].update({'runs': 1, 'passed_runs': 1, 'results': 8, 'critical_failures': 0})
        s['signoffs'].update({'total': 4, 'approved': 4, 'rejected': 0, 'approved_types': 4})
        s['components'] = {
            'database': 'PASS',
            'schema_drift': 'PASS',
            'rls': 'PASS',
            'rpc_security': 'PASS',
            'anon_surface': 'PASS',
            'role_model': 'PASS',
            'clinical_guardrails': 'PASS',
            'uat': 'PASS',
            'signoffs': 'PASS',
        }
        s['final_release_gate'] = 'READY'
        result = validate_snapshot(s)
        self.assertTrue(result['valid'])
        self.assertEqual(result['final_release_gate'], 'READY')

    def test_tampered_component_is_rejected(self):
        s = copy.deepcopy(self.base)
        s['components']['rls'] = 'PASS'
        result = validate_snapshot(s)
        self.assertFalse(result['valid'])
        self.assertTrue(any('component rls' in e for e in result['errors']))

    def test_clinical_automation_enabled_is_stop(self):
        s = copy.deepcopy(self.base)
        s['clinical']['clinical_dispatch'] = True
        s['components']['clinical_guardrails'] = 'STOP'
        result = validate_snapshot(s)
        self.assertTrue(result['valid'])
        self.assertEqual(result['components']['clinical_guardrails'], 'STOP')

    def test_schema_drift_breaks_gate(self):
        s = copy.deepcopy(self.base)
        s['counts']['missing_relations'] = 1
        s['components']['schema_drift'] = 'STOP'
        result = validate_snapshot(s)
        self.assertTrue(result['valid'])
        self.assertEqual(result['final_release_gate'], 'NOT_READY')


if __name__ == '__main__':
    unittest.main()
