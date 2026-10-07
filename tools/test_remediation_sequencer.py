import copy
import json
import tempfile
import unittest
from pathlib import Path

from remediation_sequencer import summarize, validate_graph

ROOT = Path(__file__).resolve().parents[1]
PLAN = ROOT / 'contracts' / 'remediation-plan-v0.44.19.json'
STATE = ROOT / 'contracts' / 'remediation-state-v0.44.19.json'


class RemediationSequencerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan = json.loads(PLAN.read_text(encoding='utf-8'))
        cls.state = json.loads(STATE.read_text(encoding='utf-8'))

    def test_plan_graph_has_no_cycles(self):
        self.assertEqual(validate_graph(copy.deepcopy(self.plan)), [])

    def test_current_next_action_is_c11_smoke_merge(self):
        result = summarize(copy.deepcopy(self.plan), copy.deepcopy(self.state), ROOT)
        self.assertTrue(result['valid'])
        self.assertEqual(result['next_action']['id'], 'S01_C11_2_FRONTEND_SMOKE_MERGE')

    def test_after_s01_next_action_is_c12(self):
        state = copy.deepcopy(self.state)
        state['manual_complete'] = ['S01_C11_2_FRONTEND_SMOKE_MERGE']
        result = summarize(copy.deepcopy(self.plan), state, ROOT)
        self.assertTrue(result['valid'])
        self.assertEqual(result['next_action']['id'], 'S02_C12_SECURITY_HARDENING')

    def test_out_of_order_database_version_is_rejected(self):
        state = copy.deepcopy(self.state)
        state['applied_versions'] = ['0.44.3']
        result = summarize(copy.deepcopy(self.plan), state, ROOT)
        self.assertFalse(result['valid'])
        self.assertTrue(any('completed before dependency' in e for e in result['errors']))

    def test_missing_artifact_is_rejected(self):
        plan = copy.deepcopy(self.plan)
        plan['stages'][1]['candidate'] = 'sql/DOES_NOT_EXIST.sql'
        result = summarize(plan, copy.deepcopy(self.state), ROOT)
        self.assertFalse(result['valid'])
        self.assertTrue(any('missing artifact' in e for e in result['errors']))


if __name__ == '__main__':
    unittest.main()
