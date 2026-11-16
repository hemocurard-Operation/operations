"""Verify a private logical-export directory without executing SQL or exposing data.

Integrity verification is independent of, and never certifies, database restoration.
"""
import argparse
import hashlib
import json
import re
import stat
from pathlib import Path

SQL_FILES = ('roles.sql', 'schema.sql', 'data.sql', 'history-schema.sql', 'history-data.sql')
MANIFEST_LIMIT = 256 * 1024


class InvalidBundle(ValueError):
    pass


def regular_file(path):
    if not stat.S_ISREG(path.lstat().st_mode):
        raise InvalidBundle('Backup members must be regular files, not links or devices.')
    return path


def verify(directory):
    directory = Path(directory)
    if directory.is_symlink() or not directory.is_dir():
        raise InvalidBundle('Choose a private export directory, not a symbolic link.')
    manifest = regular_file(directory / 'manifest.json')
    with manifest.open('rb') as stream:
        content = stream.read(MANIFEST_LIMIT + 1)
    if len(content) > MANIFEST_LIMIT:
        raise InvalidBundle('The backup manifest exceeds the allowed size.')
    try:
        data = json.loads(content)
    except (ValueError, UnicodeDecodeError):
        raise InvalidBundle('The backup manifest is not valid JSON.') from None
    hashes = data.get('sha256') if isinstance(data, dict) else None
    if not isinstance(hashes, dict) or set(hashes) != set(SQL_FILES):
        raise InvalidBundle('The manifest must cover exactly the five required SQL exports.')
    total_bytes = 0
    for name in SQL_FILES:
        expected = hashes[name]
        if not isinstance(expected, str) or not re.fullmatch(r'[0-9a-f]{64}', expected):
            raise InvalidBundle('The manifest contains an invalid SHA256 checksum.')
        path = regular_file(directory / name)
        digest = hashlib.sha256()
        file_bytes = 0
        with path.open('rb') as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b''):
                file_bytes += len(block)
                digest.update(block)
        if not file_bytes or digest.hexdigest() != expected:
            raise InvalidBundle('An SQL export is empty or does not match its manifest.')
        total_bytes += file_bytes
    return {'status': 'PASS', 'integrity_verified': True, 'sql_files': len(SQL_FILES),
            'total_bytes': total_bytes, 'restoration_verified': False,
            'scope': 'SQL file presence and SHA256 only; SQL was not executed.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path, help='Private directory containing the exports and manifest.')
    args = parser.parse_args()
    try:
        result = verify(args.directory)
    except (InvalidBundle, OSError):
        # Files and paths can contain private information; never echo their contents or OS errors.
        print(json.dumps({'status': 'FAIL', 'integrity_verified': False,
                          'restoration_verified': False,
                          'error': 'Backup integrity verification failed. Review the private export and its manifest.'}))
        return 1
    print(json.dumps(result))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
