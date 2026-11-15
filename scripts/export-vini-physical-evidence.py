"""Export ONLY allowlisted manual observations. Never ingest raw app/system logs."""
import argparse
import datetime as dt
import json
from pathlib import Path
import re

COMMIT = '7864fc3ff5c06d81b05e67fa6a94c40813d4109e'
FIELDS = {'case_id', 'observed_at', 'account_alias', 'result', 'state', 'plan',
          'remaining_minutes', 'elapsed_seconds', 'http_status', 'error_code', 'identity_matches'}
STATES = {'unknown', 'app_started', 'active', 'signed_out', 'paused', 'denied', 'expired',
          'offline', 'unverified', 'waiting', 'verified_download', 'unchanged'}
ERRORS = {'unknown', 'none', 'signedOut', 'paused', 'denied', 'expired', 'offline',
          'rateLimited', 'invalidResponse', 'integrity', 'keychain', 'stale'}
RESULTS = {'pending', 'pass', 'fail', 'blocked', 'not_observable'}

def no_duplicates(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate_fields')
        result[key] = value
    return result

def timestamp(value):
    if value is None:
        return None
    if not isinstance(value, str) or len(value) > 35:
        raise ValueError('invalid_time')
    parsed = dt.datetime.fromisoformat(value.replace('Z', '+00:00'))
    if parsed.utcoffset() is None:
        raise ValueError('timezone_required')
    return parsed.isoformat()

def export(payload):
    if not isinstance(payload, dict) or set(payload) != {'device', 'ios', 'events'}:
        raise ValueError('invalid_schema')
    if payload['device'] not in {'iPhone 13 Pro Max', 'unknown'}:
        raise ValueError('invalid_device')
    ios = payload['ios']
    if not isinstance(ios, str) or not re.fullmatch(r'(unknown|[0-9]{1,2}\.[0-9]{1,2}(?:\.[0-9]{1,2})?)', ios):
        raise ValueError('invalid_version')
    events = payload['events']
    if not isinstance(events, list) or not 1 <= len(events) <= 200:
        raise ValueError('invalid_event_count')
    safe = []
    for event in events:
        if not isinstance(event, dict) or set(event) != FIELDS:
            raise ValueError('unexpected_or_missing_fields')
        case = event['case_id']
        if case not in {'P%02d' % n for n in range(1, 20)}:
            raise ValueError('invalid_case')
        if event['account_alias'] not in {'NONE', 'BASIC-A', 'PRO-A', 'DIST-A'}:
            raise ValueError('invalid_alias')
        if event['result'] not in RESULTS or event['state'] not in STATES:
            raise ValueError('invalid_state')
        if event['plan'] not in {'unknown', 'basic', 'pro'} or event['error_code'] not in ERRORS:
            raise ValueError('invalid_code')
        observed = timestamp(event['observed_at'])
        if event['result'] in {'pass', 'fail'} and observed is None:
            raise ValueError('observation_time_required')
        for name, low, high in [('remaining_minutes', 0, 5_256_000), ('elapsed_seconds', 0, 86_400), ('http_status', 100, 599)]:
            value = event[name]
            if value is not None and (type(value) is not int or not low <= value <= high):
                raise ValueError('invalid_metric')
        if event['identity_matches'] is not None and type(event['identity_matches']) is not bool:
            raise ValueError('invalid_identity_comparison')
        safe.append({**event, 'observed_at': observed})
    # Does not certify the origin of manually supplied observations.
    return {'schema': 1, 'source': 'user_reported_manual_observations', 'reviewed': False,
            'source_commit': COMMIT, 'environment': 'staging', 'device': payload['device'],
            'ios': ios, 'events': safe}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    if args.input.stat().st_size > 131_072:
        raise ValueError('input_too_large')
    result = export(json.loads(args.input.read_text(encoding='utf-8-sig'), object_pairs_hook=no_duplicates))
    # Refuse to overwrite originals or existing exports.
    with args.output.open('x', encoding='utf-8') as target:
        json.dump(result, target, ensure_ascii=False, indent=2)
    print('Exported allowlisted observations. Physical results still require review.')

if __name__ == '__main__':
    try:
        main()
    except (ValueError, TypeError, KeyError, OSError):
        raise SystemExit('Export rejected: invalid schema, unsafe fields, inaccessible file or output already exists. No raw input echoed.')
