#!/usr/bin/env python3
from pathlib import Path
import argparse
import json
import re
import sys

ROOT=Path(__file__).resolve().parents[1]
DEFAULT_CONTRACT=ROOT/'contracts'/'ux-budget-v0.45.7.json'


def count_tag(source,tag):
    return len(re.findall(rf'<{tag}\b',source,re.IGNORECASE))


def evaluate(contract_path):
    contract=json.loads(Path(contract_path).read_text(encoding='utf-8'))
    checks=[]
    metrics={'files':{},'aggregate_bytes':0,'capture_complexity':{}}

    def check(name,ok,actual=None,limit=None):
        checks.append({'name':name,'pass':bool(ok),'actual':actual,'limit':limit})

    for rel,max_bytes in contract['files'].items():
        path=ROOT/rel
        exists=path.exists()
        size=path.stat().st_size if exists else None
        metrics['files'][rel]=size
        if exists:
            metrics['aggregate_bytes']+=size
        check(f'file_exists:{rel}',exists,size,max_bytes)
        if exists:
            check(f'file_budget:{rel}',size<=max_bytes,size,max_bytes)

    aggregate_limit=int(contract['aggregate_max_bytes'])
    check('aggregate_frontend_budget',metrics['aggregate_bytes']<=aggregate_limit,metrics['aggregate_bytes'],aggregate_limit)

    report=(ROOT/'hemocura-core'/'daily-inventory.js').read_text(encoding='utf-8')
    flow=(ROOT/'hemocura-core'/'daily-inventory-flow.js').read_text(encoding='utf-8')
    daily_scope=report+'\n'+flow

    counts={
        'input':count_tag(report,'input'),
        'select':count_tag(report,'select'),
        'textarea':count_tag(report,'textarea'),
        'button':count_tag(report,'button')
    }
    counts['total']=sum(counts.values())
    metrics['capture_complexity']=counts
    limits=contract['capture_complexity']
    check('capture_inputs',counts['input']<=limits['daily_inventory_source_input_tags_max'],counts['input'],limits['daily_inventory_source_input_tags_max'])
    check('capture_selects',counts['select']<=limits['daily_inventory_source_select_tags_max'],counts['select'],limits['daily_inventory_source_select_tags_max'])
    check('capture_textareas',counts['textarea']<=limits['daily_inventory_source_textarea_tags_max'],counts['textarea'],limits['daily_inventory_source_textarea_tags_max'])
    check('capture_buttons',counts['button']<=limits['daily_inventory_source_button_tags_max'],counts['button'],limits['daily_inventory_source_button_tags_max'])
    check('capture_total_controls',counts['total']<=limits['daily_inventory_source_total_controls_max'],counts['total'],limits['daily_inventory_source_total_controls_max'])

    for marker in contract.get('required_markers',[]):
        check(f'required_marker:{marker}',marker.lower() in report.lower())

    privacy=contract['privacy']
    lower_scope=daily_scope.lower()
    for token in privacy.get('forbidden_tokens_in_daily_report_ui',[]):
        check(f'privacy_forbidden:{token}',token.lower() not in lower_scope)
    if privacy.get('forbid_direct_supabase_rpc_in_flow'):
        check('privacy_no_direct_rpc_in_flow','.rpc(' not in flow)
    if privacy.get('forbid_service_role'):
        check('privacy_no_service_role','service_role' not in lower_scope)

    check('no_production_telemetry_endpoint',not re.search(r'https?://[^\s\"\']+',flow,re.IGNORECASE))

    failed=[c for c in checks if not c['pass']]
    return {
        'contract_version':contract['contract_version'],
        'status':'PASS' if not failed else 'FAIL',
        'metrics':metrics,
        'checks':checks,
        'failed':[c['name'] for c in failed]
    }


def main():
    parser=argparse.ArgumentParser(description='HemoCura privacy-safe UX/performance budget gate')
    parser.add_argument('contract',nargs='?',default=str(DEFAULT_CONTRACT))
    parser.add_argument('--json-out')
    args=parser.parse_args()
    result=evaluate(args.contract)
    for check in result['checks']:
        detail=''
        if check['actual'] is not None:
            detail=f" actual={check['actual']}"
        if check['limit'] is not None:
            detail+=f" limit={check['limit']}"
        print(f"{'PASS' if check['pass'] else 'FAIL'} {check['name']}{detail}")
    print(f"\n{result['status']} UX budget · {result['metrics']['aggregate_bytes']} bytes")
    if args.json_out:
        Path(args.json_out).write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    if result['status']!='PASS':
        sys.exit(1)

if __name__=='__main__':
    main()
