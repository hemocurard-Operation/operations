import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('backup_bundle', Path(__file__).with_name('verify_backup_bundle.py'))
bundle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bundle)


class BackupIntegrityTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        hashes = {}
        for name in bundle.SQL_FILES:
            content = ('-- Synthetic export: ' + name + '\n').encode()
            (self.root / name).write_bytes(content)
            hashes[name] = hashlib.sha256(content).hexdigest()
        self.manifest = {'sha256': hashes, 'restore_verified': False}
        self.write_manifest()

    def write_manifest(self):
        (self.root / 'manifest.json').write_text(json.dumps(self.manifest))

    def test_complete_export_checks_integrity_without_certifying_restore(self):
        self.manifest['restore_verified'] = True
        self.write_manifest()
        result = bundle.verify(self.root)
        self.assertTrue(result['integrity_verified'])
        self.assertFalse(result['restoration_verified'])
        self.assertEqual(result['sql_files'], 5)

    def test_modified_export_is_rejected(self):
        (self.root / 'data.sql').write_text('changed after manifest creation')
        with self.assertRaises(bundle.InvalidBundle):
            bundle.verify(self.root)

    def test_missing_file_is_rejected(self):
        (self.root / 'history-data.sql').unlink()
        with self.assertRaises(OSError):
            bundle.verify(self.root)

    def test_empty_export_is_rejected_even_with_matching_hash(self):
        (self.root / 'data.sql').write_bytes(b'')
        self.manifest['sha256']['data.sql'] = hashlib.sha256(b'').hexdigest()
        self.write_manifest()
        with self.assertRaises(bundle.InvalidBundle):
            bundle.verify(self.root)

    def test_manifest_path_injection_is_rejected(self):
        self.manifest['sha256']['../private.sql'] = '0' * 64
        self.write_manifest()
        with self.assertRaises(bundle.InvalidBundle):
            bundle.verify(self.root)

    def test_symbolic_link_is_rejected(self):
        path = self.root / 'data.sql'
        path.rename(self.root / 'outside.sql')
        path.symlink_to(self.root / 'outside.sql')
        with self.assertRaises(bundle.InvalidBundle):
            bundle.verify(self.root)

    def test_oversized_manifest_is_rejected(self):
        (self.root / 'manifest.json').write_bytes(b' ' * (bundle.MANIFEST_LIMIT + 1))
        with self.assertRaises(bundle.InvalidBundle):
            bundle.verify(self.root)

    def test_cli_failure_does_not_expose_sql_or_private_paths(self):
        (self.root / 'data.sql').write_text('PRIVATE-PATIENT-CONTENT')
        output = io.StringIO()
        with patch.object(sys, 'argv', ['verify', str(self.root)]), contextlib.redirect_stdout(output):
            self.assertEqual(bundle.main(), 1)
        self.assertNotIn('PRIVATE-PATIENT-CONTENT', output.getvalue())
        self.assertNotIn(str(self.root), output.getvalue())
        self.assertFalse(json.loads(output.getvalue())['restoration_verified'])


if __name__ == '__main__':
    unittest.main()
