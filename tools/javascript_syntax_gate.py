"""Parse browser ES modules explicitly; Node's file autodetection can hide errors."""
from pathlib import Path
import argparse
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def check_module(path):
    result = subprocess.run(
        ['node', '--input-type=module', '--check'],
        input=Path(path).read_text(encoding='utf-8'), capture_output=True, text=True,
    )
    # Do not dump source lines: configuration modules can contain public keys.
    diagnostic = ('SyntaxError: invalid ES module syntax' if 'SyntaxError:' in result.stderr
                  else 'Node parser failed') if result.returncode else ''
    return {'file': str(path), 'pass': result.returncode == 0, 'diagnostic': diagnostic}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('paths', nargs='*', type=Path)
    parser.add_argument('--json-out', type=Path)
    args = parser.parse_args()
    paths = args.paths or sorted([*ROOT.glob('*.js'), *ROOT.joinpath('js').glob('*.js'),
                                 *ROOT.joinpath('hemocura-core').glob('*.js')])
    results = [check_module(path) for path in paths]
    report = {'files': len(results), 'failed': sum(not x['pass'] for x in results),
              'checks': results}
    if args.json_out:
        args.json_out.write_text(json.dumps(report, indent=2), encoding='utf-8')
    for result in results:
        if not result['pass']:
            print(f"FAIL {result['file']}: {result['diagnostic']}")
    print(f"ES MODULE SYNTAX: {len(results)-report['failed']}/{len(results)} PASS")
    return 0 if results and not report['failed'] else 1


if __name__ == '__main__':
    sys.exit(main())
