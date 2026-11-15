"""Desktop exporter tests only; never evidence of an iPhone test."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('exporter', Path(__file__).with_name('export-vini-physical-evidence.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

def sample():
    return {'device': 'iPhone 13 Pro Max', 'ios': 'unknown', 'events': [{
        'case_id': 'P02', 'observed_at': None, 'account_alias': 'NONE', 'result': 'pending',
        'state': 'unknown', 'plan': 'unknown', 'remaining_minutes': None, 'elapsed_seconds': None,
        'http_status': None, 'error_code': 'unknown', 'identity_matches': None}]}

class Tests(unittest.TestCase):
    def test_pending_is_not_approved(self):
        result = module.export(sample())
        self.assertFalse(result['reviewed'])
        self.assertEqual(result['events'][0]['result'], 'pending')
    def test_observation_is_explicitly_user_reported(self):
        value = sample(); value['events'][0].update(result='pass', observed_at='2026-11-15T16:00:00-05:00', state='app_started')
        self.assertEqual(module.export(value)['source'], 'user_reported_manual_observations')
    def test_sensitive_extra_fields_rejected(self):
        for field in ['token', 'licenseKey', 'hwid', 'password', 'content_key', 'raw_log', 'username']:
            value = sample(); value['events'][0][field] = 'SYNTHETIC-SECRET'
            with self.assertRaises(ValueError): module.export(value)
    def test_secret_in_allowed_string_rejected(self):
        for field in ['state', 'error_code', 'account_alias', 'plan', 'case_id', 'result', 'observed_at']:
            value = sample(); value['events'][0][field] = 'SYNTHETIC-SECRET'
            with self.assertRaises(ValueError): module.export(value)
    def test_unbounded_identifiers_rejected(self):
        for field in ['ios', 'device']:
            value = sample(); value[field] = 'SYNTHETIC-SECRET'
            with self.assertRaises(ValueError): module.export(value)
    def test_pass_requires_timestamp(self):
        value = sample(); value['events'][0]['result'] = 'pass'
        with self.assertRaises(ValueError): module.export(value)
    def test_unknown_http_is_preserved(self):
        self.assertIsNone(module.export(sample())['events'][0]['http_status'])
    def test_duplicate_json_fields_rejected(self):
        with self.assertRaises(ValueError): json.loads('{"state": "unknown", "state": "SYNTHETIC"}', object_pairs_hook=module.no_duplicates)
    def test_free_text_metrics_rejected(self):
        value = sample(); value['events'][0]['elapsed_seconds'] = 'SYNTHETIC-SECRET'
        with self.assertRaises(ValueError): module.export(value)

if __name__ == '__main__':
    unittest.main()
