"""Protect access/identity sources and assert absence of refresh presentation."""
from pathlib import Path
import hashlib, json
root = Path(__file__).resolve().parents[1]
expected = json.loads((root/'scripts/silent-refresh-protected.json').read_text())
for name, digest in expected.items():
    actual = hashlib.sha256((root/name).read_bytes().replace(b'\r\n', b'\n')).hexdigest()
    assert actual == digest, f'protected functionality changed: {name}'
swift = (root/'ThreeOneOSFive/views/AppDataBrowserView.swift').read_text()
view, model = swift.split('private final class SilentAppDataRefresh', 1)
for forbidden in ['ProgressView(', 'scanActivity', 'browser.retry', 'browser.loading',
                  'browser.mha_scanning', 'WQScanPresentationChanged', 'WQScanRetryRequested']:
    assert forbidden not in view, f'refresh presentation remains: {forbidden}'
embedded = (root/'Vendor/WQFiles/WQEmbedded.m').read_text()
for forbidden in ['scanBanner', 'UIAlertController', 'UIProgressView', 'presentViewController']:
    assert forbidden not in embedded, f'embedded refresh presentation remains: {forbidden}'
policy = (root/'Vendor/WQFiles/WQScanPresentation.inc').read_text().split('#ifdef WQ_SCAN_UI_TESTING')[0]
assert 'forKey:WQScanConsentKey' not in policy, 'automatic code must not grant or renew consent'
assert 'delays[] = {2, 8, 30}' in policy and 'attempt < 3' in policy
assert 'WQScanBusy || !WQScanForeground' in policy
assert '@Published private(set) var apps' in model and 'pendingRetry' in model
print(f'PASS: {len(expected)} protected files unchanged; silent view, bounded retries and no consent writes')
