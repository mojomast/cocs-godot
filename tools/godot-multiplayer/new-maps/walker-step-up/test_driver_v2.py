"""Static source admission checks; no GDScript parse or physics execution."""
import ast
import unittest
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
class DriverContract(unittest.TestCase):
    def test_python_entrypoints_compile_without_execution(self):
        for name in ['prepare_v2.py','run_group_v2.py']:
            ast.parse((HERE/name).read_text(),filename=name)
    def test_driver_has_fixed_profiles_and_explicit_continuation(self):
        source=(ROOT/'godot/tests/walker_step_up/driver_v2.gd').read_text()
        for required in ['Candidate.new() if experimental else Baseline.new()',
                         '--continue-after-known-baseline-failure','missing_or_unbound_predecessor',
                         'candidate_baseline_not_fixed','experimental_stall_or_no_landing',
                         'query_mutated_body','rejected_candidate_changed_ordinary_response',
                         'get_physics_process_delta_time','candidate_proof_or_reset_fault']:
            self.assertIn(required,source)
    def test_supervisor_has_nonwaiting_lock_and_owned_group_audits(self):
        source=(HERE/'run_group_v2.py').read_text()
        for required in ['LOCK_EX|fcntl.LOCK_NB','start_new_session=True','timeout=180','range(3)',
                         'identity(process.pid)==owned',"g.get('expiresUnix',0)","g.get('engineSha256')"]:
            self.assertIn(required,source)
        self.assertNotIn('shell=True',source)
if __name__=='__main__':unittest.main()
