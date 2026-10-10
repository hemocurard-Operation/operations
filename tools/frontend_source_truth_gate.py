#!/usr/bin/env python3
from pathlib import Path
import argparse
import json
import re
import sys

ROOT=Path(__file__).resolve().parents[1]
DEFAULT_CONTRACT=ROOT/'contracts'/'frontend-source-of-truth-v0.45.8.json'


def evaluate(contract_path):
    contract=json.loads(Path(contract_path).read_text(encoding='utf-8'))
    checks=[]
    metrics={}

    def check(name,ok,actual=None,limit=None):
        checks.append({'name':name,'pass':bool(ok),'actual':actual,'limit':limit})

    for rel in contract['runtime_chain']:
        check(f'runtime_file_exists:{rel}',(ROOT/rel).exists())

    for rel,marker in contract['required_entrypoint_markers'].items():
        path=ROOT/rel
        source=path.read_text(encoding='utf-8') if path.exists() else ''
        check(f'entrypoint_marker:{rel}',marker in source)

    index=(ROOT/'index.html').read_text(encoding='utf-8')
    app=(ROOT/'js'/'app.js').read_text(encoding='utf-8')
    check('index_no_root_js_script',not re.search(r'<script[^>]+src=["\']\./(?!js/)[^"\']+\.js',index,re.IGNORECASE))
    check('app_boots_only_core','../hemocura-core/bootstrap.js' in app and '../bootstrap.js' not in app)

    core=ROOT/'hemocura-core'
    root_js={p.name:p for p in ROOT.glob('*.js') if p.is_file()}
    core_js={p.name:p for p in core.glob('*.js') if p.is_file()}
    shadows=sorted(set(root_js)&set(core_js))
    metrics['root_shadow_modules']=shadows
    metrics['root_shadow_count']=len(shadows)
    max_shadows=int(contract['legacy_policy']['max_root_shadow_modules'])
    check('root_shadow_budget',len(shadows)<=max_shadows,len(shadows),max_shadows)

    accidental=[]
    for name in root_js:
        for pattern in contract['legacy_policy']['forbidden_root_name_patterns']:
            if re.search(pattern,name):
                accidental.append(name)
                break
    metrics['forbidden_root_names']=sorted(accidental)
    check('no_accidental_root_module_names',not accidental,sorted(accidental),0)

    root_names=set(root_js)
    legacy_refs=[]
    import_re=re.compile(r"(?:import|from)\s*(?:[^'\"]*?\sfrom\s*)?['\"]([^'\"]+)['\"]")
    for path in core.glob('*.js'):
        source=path.read_text(encoding='utf-8')
        for spec in import_re.findall(source):
            if spec.startswith('../') and '/' not in spec[3:] and Path(spec).name in root_names:
                legacy_refs.append({'file':str(path.relative_to(ROOT)),'import':spec})
    metrics['core_to_root_legacy_imports']=legacy_refs
    check('core_does_not_import_root_legacy_modules',not legacy_refs,legacy_refs,0)

    protected=contract.get('protected',[])
    for rel in protected:
        check(f'protected_file_exists:{rel}',(ROOT/rel).exists())
    check('no_core_config_shadow',not (core/'config.js').exists())

    failed=[x for x in checks if not x['pass']]
    return {
        'contract_version':contract['contract_version'],
        'status':'PASS' if not failed else 'FAIL',
        'metrics':metrics,
        'checks':checks,
        'failed':[x['name'] for x in failed]
    }


def main():
    parser=argparse.ArgumentParser(description='HemoCura frontend source-of-truth gate')
    parser.add_argument('contract',nargs='?',default=str(DEFAULT_CONTRACT))
    parser.add_argument('--json-out')
    args=parser.parse_args()
    result=evaluate(args.contract)
    for item in result['checks']:
        detail=''
        if item['actual'] is not None: detail+=f" actual={item['actual']}"
        if item['limit'] is not None: detail+=f" limit={item['limit']}"
        print(f"{'PASS' if item['pass'] else 'FAIL'} {item['name']}{detail}")
    print(f"\n{result['status']} frontend source-of-truth · root shadows={result['metrics'].get('root_shadow_count',0)}")
    if args.json_out:
        Path(args.json_out).write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    if result['status']!='PASS': sys.exit(1)

if __name__=='__main__':
    main()
