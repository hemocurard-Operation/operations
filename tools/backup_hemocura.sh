#!/usr/bin/env bash
# No plaintext logs, exports or keys are retained in the checkout. Run on an isolated trusted runner.
set -Eeuo pipefail
umask 077
: "${HC_BACKUP_DB_URL:?Configure HC_BACKUP_DB_URL as a secret}"
: "${HC_BACKUP_REMOTE:?Configure a private rclone destination}"
: "${HC_BACKUP_AGE_RECIPIENT:?Configure the public age recipient; retain the private identity separately}"
: "${HC_BACKUP_DIR:?Choose a private output directory outside the repository}"
: "${HC_RCLONE_CONFIG:?Configure the rclone credential file outside the repository}"
HC_SUPABASE_BIN="${HC_SUPABASE_BIN:-supabase}"
for tool in age rclone tar sha256sum; do command -v "$tool" >/dev/null; done
command -v "$HC_SUPABASE_BIN" >/dev/null
backup_tmp="$(mktemp -d)"
trap 'backup_status=$?; rm -rf "$backup_tmp"; if [ "$backup_status" -ne 0 ]; then echo "FAIL backup: no successful copy recorded; inspect the private runner configuration." >&2; fi' EXIT
backup_root="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
python3 - "$backup_root" "$HC_BACKUP_DIR" "$HC_RCLONE_CONFIG" <<'PY'
import pathlib,sys
root=pathlib.Path(sys.argv[1]).resolve()
for value in sys.argv[2:]:
 if pathlib.Path(value).resolve().is_relative_to(root):raise SystemExit('Private backup data and credentials must remain outside the published repository')
PY
# Keep CLI diagnostics private: failure logs may contain connection information.
"$HC_SUPABASE_BIN" db dump --db-url "$HC_BACKUP_DB_URL" -f "$backup_tmp/roles.sql" --role-only >"$backup_tmp/dump.log" 2>&1
"$HC_SUPABASE_BIN" db dump --db-url "$HC_BACKUP_DB_URL" -f "$backup_tmp/schema.sql" >>"$backup_tmp/dump.log" 2>&1
"$HC_SUPABASE_BIN" db dump --db-url "$HC_BACKUP_DB_URL" -f "$backup_tmp/data.sql" --use-copy --data-only -x storage.buckets_vectors -x storage.vector_indexes >>"$backup_tmp/dump.log" 2>&1
"$HC_SUPABASE_BIN" db dump --db-url "$HC_BACKUP_DB_URL" -f "$backup_tmp/history-schema.sql" --schema supabase_migrations >>"$backup_tmp/dump.log" 2>&1
"$HC_SUPABASE_BIN" db dump --db-url "$HC_BACKUP_DB_URL" -f "$backup_tmp/history-data.sql" --schema supabase_migrations --use-copy --data-only >>"$backup_tmp/dump.log" 2>&1
for file in roles.sql schema.sql data.sql history-schema.sql history-data.sql; do test -s "$backup_tmp/$file"; done
python3 - "$backup_tmp" "$backup_root" <<'PY'
import pathlib,sys,json,subprocess,datetime,hashlib
folder=pathlib.Path(sys.argv[1]);root=pathlib.Path(sys.argv[2])
files={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in folder.glob('*.sql')}
metadata={'created_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'sha256':files,'restore_verified':False,'scope':'logical database export; storage objects and platform secrets require separate recovery procedures'}
(folder/'manifest.json').write_text(json.dumps(metadata,indent=2))
PY
mkdir -p "$HC_BACKUP_DIR"
backup_file="$HC_BACKUP_DIR/hemocura-$(date -u +%Y%m%dT%H%M%SZ).tar.age"
tar -C "$backup_tmp" -cf - roles.sql schema.sql data.sql history-schema.sql history-data.sql manifest.json |
 age -r "$HC_BACKUP_AGE_RECIPIENT" -o "$backup_file"
test -s "$backup_file"
(cd "$HC_BACKUP_DIR"; sha256sum "$(basename "$backup_file")") > "$backup_file.sha256"
rclone --config "$HC_RCLONE_CONFIG" copyto "$backup_file" "${HC_BACKUP_REMOTE%/}/$(basename "$backup_file")" >/dev/null 2>&1
rclone --config "$HC_RCLONE_CONFIG" copyto "$backup_file.sha256" "${HC_BACKUP_REMOTE%/}/$(basename "$backup_file").sha256" >/dev/null 2>&1
# Read back the encrypted object, compare the hash, and never print raw data.
backup_expected="$(sha256sum "$backup_file" | cut -d' ' -f1)"
backup_received="$(rclone --config "$HC_RCLONE_CONFIG" cat "${HC_BACKUP_REMOTE%/}/$(basename "$backup_file")" 2>/dev/null | sha256sum | cut -d' ' -f1)"
test "$backup_expected" = "$backup_received"
printf '%s\n' 'PASS encrypted off-site export verified; isolated restoration still required.'
