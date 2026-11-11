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

class ApprovalEvidence(unittest.TestCase):
    def event(self, uid='current', message='waiting for promotion approval scout-approval'):
        return {'metadata': {'uid': 'event-1'}, 'involvedObject': {'uid': uid}, 'message': message}

    def test_live_waiting_event_is_accepted(self):
        event = self.event()
        grader.waiting_evidence([event], [event], 'current')

    def test_previous_canary_event_is_rejected(self):
        event = self.event(uid='old-canary')
        with self.assertRaises(common.Incomplete):
            grader.waiting_evidence([event], [event], 'current')

    def test_invented_event_is_rejected(self):
        with self.assertRaises(common.Incomplete):
            grader.waiting_evidence([self.event()], [], 'current')

    def test_snapshot_taken_after_approval_is_rejected(self):
        waiting = self.event()
        approved = self.event(message='Confirm-promotion check scout-approval passed')
        approved['metadata']['uid'] = 'event-2'
        with self.assertRaises(common.Incomplete):
            grader.waiting_evidence([waiting, approved], [waiting, approved], 'current')

class PromotionEvidence(unittest.TestCase):
    def saved(self):
        return [{'message': 'waiting for promotion approval scout-approval',
                 'firstTimestamp': '2026-11-11T12:00:00Z'}]

    def logs(self, approval='2026-11-11T12:00:15Z', target='scout.starfleet'):
        import json
        return '\n'.join(json.dumps({'ts': ts, 'canary': target, 'msg': message}) for ts, message in [
            (approval, 'Confirm-promotion check scout-approval passed'),
            ('2026-11-11T12:00:30Z', 'Promotion completed! Scaling down scout.starfleet')])

    def test_controller_records_prove_approval_after_wait(self):
        grader.promotion_evidence(self.logs(), self.saved())

    def test_old_approval_does_not_prove_this_promotion(self):
        with self.assertRaises(common.Incomplete):
            grader.promotion_evidence(self.logs(approval='2026-11-11T11:59:00Z'), self.saved())

    def test_other_canary_cannot_prove_approval(self):
        with self.assertRaises(common.Incomplete):
            grader.promotion_evidence(self.logs(target='other.starfleet'), self.saved())

    def test_completed_promotion_without_approval_fails(self):
        with self.assertRaises(common.Incomplete):
            grader.promotion_evidence(self.logs().splitlines()[1], self.saved())


if __name__ == "__main__":
    unittest.main()
