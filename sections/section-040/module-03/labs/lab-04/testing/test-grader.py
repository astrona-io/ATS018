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

class WorkflowInputs(unittest.TestCase):
    def template(self):
        return {'templates': [{'name': 'deploy', 'inputs': {'parameters': [
            {'name': name} for name in ['image', 'name', 'namespace', 'task']]},
            'resource': {'action': 'create', 'successCondition': 'status.availableReplicas > 0',
            'manifest': ' '.join('{{inputs.parameters.' + name + '}}' for name in ['image', 'name', 'namespace', 'task'])}}]}

    def test_hardcoded_image_is_rejected(self):
        spec = self.template()
        spec['templates'][0]['resource']['manifest'] = spec['templates'][0]['resource']['manifest'].replace('{{inputs.parameters.image}}', 'podinfo:6.15.0')
        with self.assertRaises(common.Incomplete):
            grader.resource_template(spec)

    def test_unused_task_is_rejected(self):
        spec = self.template()
        spec['templates'][0]['resource']['manifest'] = spec['templates'][0]['resource']['manifest'].replace('{{inputs.parameters.task}}', '')
        with self.assertRaises(common.Incomplete):
            grader.resource_template(spec)

    def test_no_readiness_wait_is_rejected(self):
        spec = self.template()
        spec['templates'][0]['resource'].pop('successCondition')
        with self.assertRaises(common.Incomplete):
            grader.resource_template(spec)

    def test_manual_deployment_without_workflow_is_rejected(self):
        spec = self.template()
        spec['arguments'] = {'parameters': [{'name': n} for n in ['image', 'name', 'namespace', 'task']]}
        deployment = {'metadata': {'generation': 1}, 'spec': {'replicas': 1},
                      'status': {'observedGeneration': 1, 'availableReplicas': 1, 'updatedReplicas': 1}}
        with patch.object(grader, 'get', side_effect=[{'spec': spec}, {'items': []}, deployment]):
            with self.assertRaises(common.Incomplete):
                grader.check()


if __name__ == "__main__":
    unittest.main()
