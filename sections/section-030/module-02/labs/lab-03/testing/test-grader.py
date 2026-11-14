"""Reject missing work, stale rollouts and infrastructure failures distinctly."""
import contextlib
import io
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'validation'))
import common
import check as grader

class GradingContract(unittest.TestCase):
    def test_missing_resource_is_incomplete(self):
        with patch.object(common, 'command', return_value=''):
            with self.assertRaises(common.Incomplete):
                common.get('deployment', 'scout', 'starfleet')

    def test_api_denial_is_error(self):
        denied = subprocess.CompletedProcess([], 1, '', 'Forbidden')
        with patch.object(common.subprocess, 'run', return_value=denied):
            with self.assertRaisesRegex(SystemExit, '^ERROR:'):
                common.run(lambda: common.get('deployment', 'scout', 'starfleet'))

    def test_old_ready_condition_is_not_ready(self):
        obj = {'metadata': {'generation': 3}, 'status': {'observedGeneration': 2,
               'conditions': [{'type': 'Ready', 'status': 'True'}]}}
        with self.assertRaises(common.Incomplete):
            common.ready(obj)

    def test_available_old_replicas_do_not_prove_rollout(self):
        obj = {'metadata': {'generation': 3}, 'spec': {'replicas': 2},
               'status': {'observedGeneration': 3, 'availableReplicas': 2, 'updatedReplicas': 1}}
        with self.assertRaises(common.Incomplete):
            common.deployed(obj, 2)

    def test_unfinished_work_reports_fail(self):
        def unfinished():
            raise common.Incomplete('missing work')
        with self.assertRaisesRegex(SystemExit, '^FAIL:'):
            common.run(unfinished)


if __name__ == "__main__":
    unittest.main()
