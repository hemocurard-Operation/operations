"""Real age encryption + local rclone round-trip with synthetic exports, never production data."""
import unittest,tempfile,pathlib,subprocess,os,shutil,tarfile,io,json
ROOT=pathlib.Path(__file__).resolve().parents[2]
@unittest.skipUnless(shutil.which('age') and shutil.which('age-keygen') and shutil.which('rclone'),'age and rclone required for the real encryption test')
class BackupPipeline(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.folder=pathlib.Path(self.temp.name)
  self.key=self.folder/'identity.agekey'
  r=subprocess.run(['age-keygen','-o',str(self.key)],capture_output=True,text=True,check=True)
  self.recipient=subprocess.check_output(['age-keygen','-y',str(self.key)],text=True).strip()
  self.cli=self.folder/'supabase-fixture'
  self.cli.write_text('#!/usr/bin/env python3\nimport pathlib,sys\nargs=sys.argv;pathlib.Path(args[args.index("-f")+1]).write_text("-- SYNTHETIC_PRIVATE_EXPORT\\n")\nprint("synthetic diagnostic that must stay private",file=sys.stderr)\n');self.cli.chmod(0o700)
  self.config=self.folder/'rclone.conf';self.config.write_text('')
  self.env=dict(os.environ,HC_BACKUP_DB_URL='postgresql://test.invalid/synthetic',HC_BACKUP_AGE_RECIPIENT=self.recipient,HC_BACKUP_DIR=str(self.folder/'encrypted'),HC_BACKUP_REMOTE=str(self.folder/'remote'),HC_RCLONE_CONFIG=str(self.config),HC_SUPABASE_BIN=str(self.cli))
 def tearDown(self):self.temp.cleanup()
 def test_encrypt_roundtrip_and_manifest(self):
  r=subprocess.run(['bash',str(ROOT/'tools/backup_hemocura.sh')],env=self.env,capture_output=True,text=True)
  self.assertEqual(r.returncode,0,r.stderr);self.assertNotIn('SYNTHETIC_PRIVATE_EXPORT',r.stdout+r.stderr);self.assertNotIn('synthetic diagnostic',r.stdout+r.stderr)
  files=list((self.folder/'remote').glob('*.tar.age'));self.assertEqual(len(files),1)
  cipher=files[0].read_bytes();self.assertNotIn(b'SYNTHETIC_PRIVATE_EXPORT',cipher)
  raw=subprocess.check_output(['age','--decrypt','-i',str(self.key),str(files[0])])
  with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
   manifest=json.load(archive.extractfile('manifest.json'));self.assertFalse(manifest['restore_verified']);self.assertEqual(len(manifest['sha256']),5)
   self.assertIn(b'SYNTHETIC_PRIVATE_EXPORT',archive.extractfile('data.sql').read());self.assertNotIn('dump.log',archive.getnames())
 def test_failure_never_uploads_plaintext_or_reports_success(self):
  self.cli.write_text('#!/bin/sh\necho "synthetic private error" >&2\nexit 42\n')
  r=subprocess.run(['bash',str(ROOT/'tools/backup_hemocura.sh')],env=self.env,capture_output=True,text=True)
  self.assertNotEqual(r.returncode,0);self.assertNotIn('PASS',r.stdout);self.assertNotIn('synthetic private error',r.stdout+r.stderr);self.assertFalse((self.folder/'remote').exists())
 def test_export_cannot_target_the_published_repository(self):
  self.env['HC_BACKUP_DIR']=str(ROOT/'backups')
  r=subprocess.run(['bash',str(ROOT/'tools/backup_hemocura.sh')],env=self.env,capture_output=True,text=True)
  self.assertNotEqual(r.returncode,0);self.assertFalse((self.folder/'remote').exists())
if __name__=='__main__':unittest.main()
