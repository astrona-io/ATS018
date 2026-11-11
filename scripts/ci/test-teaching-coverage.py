#!/usr/bin/env python3
"""Reject missing, late and unrelated preparation in course coverage maps."""
import importlib.util
from pathlib import Path
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('coverage_map', ROOT / 'scripts/ci/lab-coverage.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class CoverageTests(unittest.TestCase):
    def setUp(self):
        self.course = yaml.safe_load((ROOT / 'astrona.yaml').read_text())
        self.coverage = yaml.safe_load((ROOT / 'TEACHING-COVERAGE.yaml').read_text())
        self.lab = next(iter(self.coverage['labs']))

    def test_current_map(self):
        module.validate(self.course, self.coverage)

    def test_missing_lab(self):
        del self.coverage['labs'][self.lab]
        with self.assertRaisesRegex(ValueError, 'every registered lab'):
            module.validate(self.course, self.coverage)

    def test_unknown_preparation(self):
        self.coverage['labs'][self.lab]['preparation'] = ['missing.md']
        with self.assertRaisesRegex(ValueError, 'unknown technical reading'):
            module.validate(self.course, self.coverage)

    def test_late_preparation(self):
        prep = self.coverage['labs'][self.lab]['preparation'][0]
        for section in self.course['modules']:
            content = section.get('content', [])
            reading = next((e for e in content if e['path'] == prep), None)
            if reading:
                content.remove(reading)
                content.append(reading)
                break
        with self.assertRaisesRegex(ValueError, 'must precede'):
            module.validate(self.course, self.coverage)

    def test_unmapped_reading_hidden(self):
        self.coverage['additional_readings'].append('missing.md')
        with self.assertRaisesRegex(ValueError, 'additional_readings'):
            module.validate(self.course, self.coverage)


    def stack_first_two_labs(self):
        for section in self.course['modules']:
            content = section.get('content', [])
            labs = [e for e in content if e.get('type') == 'lab']
            if len(labs) < 2:
                continue
            first, second = labs[:2]
            start, end = content.index(first), content.index(second)
            between = content[start + 1:end]
            content[start:end + 1] = between + [first, second]
            return content, first, second
        self.fail('fixture needs two labs in one section')

    def test_stacked_labs_rejected_even_when_preparation_is_earlier(self):
        self.stack_first_two_labs()
        with self.assertRaisesRegex(ValueError, 'after the previous lab'):
            module.validate(self.course, self.coverage)

    def test_question_between_labs_is_not_teaching(self):
        content, first, second = self.stack_first_two_labs()
        question = next(e for e in content if e['path'] == second['path'] + '/question.md')
        content.remove(question)
        content.insert(content.index(first) + 1, question)
        with self.assertRaisesRegex(ValueError, 'after the previous lab'):
            module.validate(self.course, self.coverage)

    def test_unmapped_reading_between_labs_does_not_hide_gap(self):
        content, first, second = self.stack_first_two_labs()
        content.insert(content.index(first) + 1, {
            'type': 'reading', 'title': 'Unrelated reading',
            'path': 'sections/section-999/module-01/course-01-extra.md'})
        self.coverage['additional_readings'].append('sections/section-999/module-01/course-01-extra.md')
        with self.assertRaisesRegex(ValueError, 'after the previous lab'):
            module.validate(self.course, self.coverage)

    def test_capstone_needs_fresh_teaching(self):
        for path, mapping in self.coverage['labs'].items():
            if '/capstone/' in path:
                mapping['preparation'] = [p for p in mapping['preparation'] if '/capstone/' not in p]
                break
        with self.assertRaisesRegex(ValueError, 'after the previous lab'):
            module.validate(self.course, self.coverage)


if __name__ == '__main__':
    unittest.main()
