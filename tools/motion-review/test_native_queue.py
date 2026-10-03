import fcntl
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('motion_queue',Path(__file__).with_name('native_queue.py'))
queue=importlib.util.module_from_spec(spec)
spec.loader.exec_module(queue)

class QueuePolicies(unittest.TestCase):
    def test_planning_launches_nothing_and_all_scripts_exist(self):
        with patch.object(queue.subprocess,'Popen',side_effect=AssertionError('planning launched a process')):
            for scope in ['contracts','graphics','live-kick']:
                jobs=queue.plan(scope=scope)
                self.assertEqual(len(jobs),len({j['id'] for j in jobs}))
                for job in jobs:
                    self.assertTrue(0<job['timeout']<=1800)
                    for source in job['requires']: self.assertTrue((queue.ROOT/source).is_file(),source)
                if scope!='live-kick': self.assertEqual(jobs[0]['id'],'native-import')

    def test_missing_marker_zero_exit_and_false_payload_fail(self):
        for text,reason in [('quiet zero exit','missing-success-marker'),
                            ('OK {"passed":false}','fixture-failures'),
                            ('OK {"failures":["bad grip"]}','fixture-failures'),
                            ('OK failures=2','fixture-failures'),
                            ('OK ObjectDB instances leaked','native-resource-leak')]:
            result=queue.assess({'status':'passed'},text,{'marker':'OK'})
            self.assertEqual(result['failure_reason'],reason)
        self.assertEqual(queue.assess({'status':'passed'},'OK {"passed":true,"failures":[]}',{'marker':'OK'})['status'],'passed')
        self.assertEqual(queue.assess({'status':'failed','failure_reason':'timeout'},'',{'marker':'OK'})['failure_reason'],'timeout')

    def test_pointer_gate_has_display_and_child_output_is_fresh(self):
        jobs={j['id']:j for j in queue.plan()}
        self.assertIn('tools/godot-dev/xvfb_run.py',jobs['fp-binding']['argv'])
        self.assertNotIn('--headless',jobs['fp-binding']['argv'])
        job=queue.plan(scope='live-kick')[0]
        self.assertEqual(Path(job['argv'][job['argv'].index('--output')+1]).name,'producer')
        self.assertEqual(job['lock_owner'],'child')

    def test_single_lock_for_direct_gate_and_no_nested_lock_for_child(self):
        with tempfile.TemporaryDirectory() as tmp:
            lock=Path(tmp)/'acceptance.lock'
            seen=[]
            def bounded(argv,cwd,env,log,timeout):
                with lock.open('a') as probe:
                    try:
                        fcntl.flock(probe,fcntl.LOCK_EX|fcntl.LOCK_NB)
                        held=False
                    except BlockingIOError: held=True
                seen.append(held)
                log.write_text('OK')
                return {'status':'passed','cleanup':{'remaining':[]}}
            with patch.object(queue,'COHORT_LOCK',lock),patch.object(queue,'run_bounded',bounded):
                for owner in ['queue','child']:
                    result=queue.execute_job({'id':owner,'argv':['fake'],'timeout':1,'marker':'OK','lock_owner':owner},Path(tmp),{})
                    self.assertEqual(result['status'],'passed')
            self.assertEqual(seen,[True,False])

    def test_busy_lock_launches_no_direct_child(self):
        with tempfile.TemporaryDirectory() as tmp:
            lock=Path(tmp)/'acceptance.lock'
            with lock.open('a') as held:
                fcntl.flock(held,fcntl.LOCK_EX|fcntl.LOCK_NB)
                with patch.object(queue,'COHORT_LOCK',lock),patch.object(queue,'run_bounded') as run:
                    with self.assertRaises(BlockingIOError):
                        queue.execute_job({'id':'busy','argv':['fake'],'timeout':1,'marker':'OK','lock_owner':'queue'},Path(tmp),{})
                    run.assert_not_called()

if __name__=='__main__': unittest.main()
