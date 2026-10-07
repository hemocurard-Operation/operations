import json
import tempfile
import unittest
from pathlib import Path

from runtime_contract_gate import extract_frontend_refs, check_code, check_snapshot


class RuntimeContractGateTests(unittest.TestCase):
    def test_extracts_relations_and_rpcs(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td); (root/'hemocura-core').mkdir()
            (root/'hemocura-core'/'x.js').write_text("sb.from('incidents').select('*'); sb.rpc('hc_demo',{});",encoding='utf-8')
            result=extract_frontend_refs(root)
            self.assertEqual(result['relations'],['incidents'])
            self.assertEqual(result['rpcs'],['hc_demo'])

    def test_code_contract_pass(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td); (root/'js').mkdir()
            (root/'js'/'x.js').write_text("sb.from('incidents'); sb.rpc('hc_demo');",encoding='utf-8')
            c={'relations':['incidents'],'optional_relations':[],'rpcs':['hc_demo'],'optional_rpcs':[],'ignored_relations':[],'ignored_rpcs':[]}
            self.assertTrue(check_code(root,c)['ok'])

    def test_code_contract_detects_undeclared(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td); (root/'js').mkdir()
            (root/'js'/'x.js').write_text("sb.from('unknown_table');",encoding='utf-8')
            c={'relations':[],'optional_relations':[],'rpcs':[],'optional_rpcs':[],'ignored_relations':[],'ignored_rpcs':[]}
            self.assertEqual(check_code(root,c)['undeclared_relations'],['unknown_table'])

    def test_runtime_pass(self):
        c={'relations':['incidents'],'rpcs':['hc_demo'],'critical_columns':{'incidents':['id','requires_quality_followup']},'forbidden_columns':{'incidents':['status']},'required_migration_versions':['0.44'],'required_migration_codes':[]}
        s={'relations':[{'object_name':'incidents'}],'functions':[{'proname':'hc_demo'}],'columns':[{'table_name':'incidents','column_name':'id'},{'table_name':'incidents','column_name':'requires_quality_followup'}],'migrations':[{'version':'0.44','migration_code':'M44'}]}
        self.assertTrue(check_snapshot(c,s)['ok'])

    def test_runtime_missing_relation(self):
        c={'relations':['incidents'],'rpcs':[],'critical_columns':{},'forbidden_columns':{},'required_migration_versions':[],'required_migration_codes':[]}
        r=check_snapshot(c,{'relations':[],'functions':[],'columns':[],'migrations':[]})
        self.assertEqual(r['missing_relations'],['incidents'])

    def test_runtime_missing_rpc(self):
        c={'relations':[],'rpcs':['hc_demo'],'critical_columns':{},'forbidden_columns':{},'required_migration_versions':[],'required_migration_codes':[]}
        r=check_snapshot(c,{'relations':[],'functions':[],'columns':[],'migrations':[]})
        self.assertEqual(r['missing_rpcs'],['hc_demo'])

    def test_runtime_missing_column(self):
        c={'relations':['incidents'],'rpcs':[],'critical_columns':{'incidents':['id']},'forbidden_columns':{},'required_migration_versions':[],'required_migration_codes':[]}
        r=check_snapshot(c,{'relations':['incidents'],'functions':[],'columns':[],'migrations':[]})
        self.assertEqual(r['missing_columns'],['incidents.id'])

    def test_runtime_forbidden_column(self):
        c={'relations':['incidents'],'rpcs':[],'critical_columns':{},'forbidden_columns':{'incidents':['status']},'required_migration_versions':[],'required_migration_codes':[]}
        r=check_snapshot(c,{'relations':['incidents'],'functions':[],'columns':[{'table_name':'incidents','column_name':'status'}],'migrations':[]})
        self.assertEqual(r['forbidden_columns_present'],['incidents.status'])

    def test_runtime_missing_migration_version(self):
        c={'relations':[],'rpcs':[],'critical_columns':{},'forbidden_columns':{},'required_migration_versions':['0.44'],'required_migration_codes':[]}
        r=check_snapshot(c,{'relations':[],'functions':[],'columns':[],'migrations':[]})
        self.assertEqual(r['missing_migration_versions'],['0.44'])


if __name__=='__main__':
    unittest.main()
