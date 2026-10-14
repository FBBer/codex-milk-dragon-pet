"""Reject incomplete, stale and contradictory visual QA evidence."""
import copy
import hashlib
import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('quality_runner', ROOT / 'scripts/check_quality.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class EvidenceRegression(unittest.TestCase):
    def setUp(self):
        self.sha = hashlib.sha256((ROOT / 'spritesheet.webp').read_bytes()).hexdigest()
        self.semantic = json.loads((ROOT / 'qa/direction-semantics.json').read_text(encoding='utf8'))
        self.blind = json.loads((ROOT / 'qa/blind-direction-validation.json').read_text(encoding='utf8'))

    def validate(self):
        runner.validate_direction_evidence(self.semantic, self.blind, self.sha)

    def test_complete_current_evidence_passes(self):
        self.validate()

    def test_top_level_pass_without_pairs_is_rejected(self):
        self.blind = {'atlas_sha256': self.sha, 'ok': True, 'errors': [], 'unconfirmed': []}
        with self.assertRaises(ValueError):
            self.validate()

    def test_missing_status_fields_are_rejected(self):
        del self.blind['errors']
        with self.assertRaises(ValueError):
            self.validate()

    def test_missing_cardinal_pair_is_rejected(self):
        self.blind['pairs'] = [p for p in self.blind['pairs'] if p['pair'] != 'horizontal-4']
        with self.assertRaises(ValueError):
            self.validate()

    def test_wrong_cardinal_with_top_level_pass_is_rejected(self):
        pair = next(p for p in self.blind['pairs'] if p['pair'] == 'vertical-1')
        pair['A']['observed'] = 'down'
        with self.assertRaises(ValueError):
            self.validate()

    def test_downgraded_cardinal_gate_is_rejected(self):
        next(p for p in self.blind['pairs'] if p['pair'] == 'vertical-1')['gate'] = 'review'
        with self.assertRaises(ValueError):
            self.validate()

    def test_duplicate_pair_is_rejected(self):
        self.blind['pairs'][0] = copy.deepcopy(self.blind['pairs'][1])
        with self.assertRaises(ValueError):
            self.validate()

    def test_false_pass_flag_is_rejected(self):
        self.blind['pairs'][0]['A']['pass'] = True
        with self.assertRaises(ValueError):
            self.validate()

    def test_missing_warning_is_rejected(self):
        self.blind['warnings'] = []
        with self.assertRaises(ValueError):
            self.validate()

    def test_missing_semantic_review_is_rejected(self):
        self.semantic['directions'].pop()
        with self.assertRaises(ValueError):
            self.validate()

    def test_stale_hash_is_rejected(self):
        for report in (self.semantic, self.blind):
            original = report['atlas_sha256']
            report['atlas_sha256'] = '0' * 64
            with self.assertRaises(ValueError):
                self.validate()
            report['atlas_sha256'] = original


if __name__ == '__main__':
    unittest.main()
