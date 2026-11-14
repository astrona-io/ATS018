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
        return {'serviceAccountName': 'deployment-writer',
                'arguments': {'parameters': [{'name': n} for n in ['image', 'name', 'namespace', 'msg']]},
                'templates': [{'name': 'deploy', 'resource': {'action': 'create',
                    'successCondition': 'status.availableReplicas > 0', 'manifest': ' '.join('{{inputs.parameters.' + n + '}}' for n in ['image', 'name', 'namespace', 'msg'])}}]}

    def test_complete_template_passes(self):
        with patch.object(grader, 'get', return_value={'spec': self.template()}):
            grader.check_template()

    def test_apply_action_is_rejected(self):
        spec = self.template()
        spec['templates'][0]['resource']['action'] = 'apply'
        with self.assertRaises(common.Incomplete):
            grader.resource_template(spec)

    def test_fixed_image_is_rejected(self):
        spec = self.template()
        resource = spec['templates'][0]['resource']
        resource['manifest'] = resource['manifest'].replace('{{inputs.parameters.image}}', 'alpine:3.23')
        with self.assertRaises(common.Incomplete):
            grader.resource_template(spec)

    def test_no_readiness_wait_is_rejected(self):
        spec = self.template()
        spec['templates'][0]['resource'].pop('successCondition')
        with self.assertRaises(common.Incomplete):
            grader.resource_template(spec)

    def test_missing_parameter_is_rejected(self):
        spec = self.template()
        spec['arguments']['parameters'].pop()
        with patch.object(grader, 'get', return_value={'spec': spec}):
            with self.assertRaises(common.Incomplete):
                grader.check_template()

    def test_manual_deployment_without_workflow_is_rejected(self):
        with patch.object(grader, 'get', return_value={'items': []}):
            with self.assertRaises(common.Incomplete):
                grader.check_deployments()

    def test_deployment_created_outside_run_is_rejected(self):
        workflow = {'spec': {'workflowTemplateRef': {'name': 'deploy-workload'}, 'arguments': {'parameters': [
            {'name': 'name', 'value': 'scout'}, {'name': 'namespace', 'value': 'outpost'},
            {'name': 'image', 'value': 'alpine:3.23'},
            {'name': 'msg', 'value': 'scout is running'}]}},
            'status': {'phase': 'Succeeded', 'startedAt': '2026-11-14T10:00:00Z', 'finishedAt': '2026-11-14T10:00:30Z'}}
        deployment = {'metadata': {'generation': 1, 'creationTimestamp': '2026-11-14T09:59:00Z'}, 'spec': {'replicas': 1},
                      'status': {'observedGeneration': 1, 'availableReplicas': 1, 'updatedReplicas': 1}}
        with patch.object(grader, 'get', side_effect=[{'items': [workflow]}, deployment]):
            with self.assertRaisesRegex(common.Incomplete, 'not created by its workflow'):
                grader.check_deployments()


if __name__ == "__main__":
    unittest.main()
