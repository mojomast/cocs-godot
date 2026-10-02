"""Receipt integrity fixtures only: none of these files is native/art/release proof."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from finish_receipts import accept_reference, sha, validate_artifact_checks, validate_output_checks, validate_map_journeys
from finish_runner import ROOT, load_matrix, summarize


class FinalReceiptTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='finish-receipt-test-', dir='/tmp/opencode')
        self.root = Path(self.temp.name)
        self.identity = {'sha256': 'a' * 64, 'environment': {'GODOT_BIN': 'test-only-not-executed'}}
        self.report = {'input_identity': self.identity, 'attempts': {}}
        self.job = {'id': 'example', 'cohort': 'source', 'criteria': 'test only',
                    'evidence_kind': 'actual-source-oracle', 'requires': ['source.txt'],
                    'command': ['never-execute-this-fixture']}
        (self.root / 'source.txt').write_text('source fixture')

    def tearDown(self):
        self.temp.cleanup()

    def put(self, name, value):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value))
        return path

    def reference(self, producer, adapter='finish-job'):
        path = self.put('producer.json', producer)
        return self.put('reference.json', {'gate': self.job['id'], 'adapter': adapter,
                                         'report': {'path': str(path), 'sha256': sha(path)}})

    def executed(self):
        scope = self.root / 'attempt'
        scope.mkdir()
        (scope / 'output.log').write_text('synthetic receipt test; never native evidence')
        return {'input_identity': copy.deepcopy(self.identity), 'queue': [copy.deepcopy(self.job)],
                'attempts': {self.job['id']: [{'status': 'passed', 'exit_code': 0, 'failure_reason': None,
                    'cleanup': {'remaining': []}, 'scope': str(scope),
                    'artifact_hashes': {'output.log': sha(scope / 'output.log')}}]}}

    def test_exact_anchor_reuses_one_executed_receipt_without_running_inventory(self):
        reference = self.reference(self.executed())
        self.report['attempts']['example'] = [{'status': 'failed', 'failure_reason': 'retained earlier failure'}]
        accept_reference(reference, self.report, [self.job], self.root, self.root / 'archive')
        self.assertEqual([r['status'] for r in self.report['attempts']['example']], ['failed', 'passed'])
        self.assertIn('receipt_reference', self.report['attempts']['example'][-1])
        archived = Path(self.report['attempts']['example'][-1]['receipt_reference']['archived_report'])
        self.assertEqual(archived.read_bytes(), (self.root / 'producer.json').read_bytes())

    def test_changed_report_or_artifact_or_input_anchor_is_rejected(self):
        producer = self.executed()
        reference = self.reference(producer)
        (self.root / 'producer.json').write_text('{}')
        with self.assertRaisesRegex(ValueError, 'bytes changed'):
            accept_reference(reference, self.report, [self.job], self.root)
        reference = self.reference(producer)
        (self.root / 'attempt/output.log').write_text('tampered')
        with self.assertRaisesRegex(ValueError, 'bytes changed'):
            accept_reference(reference, self.report, [self.job], self.root)
        producer['input_identity']['sha256'] = 'b' * 64
        reference = self.reference(producer)
        with self.assertRaisesRegex(ValueError, 'Different exact input'):
            accept_reference(reference, self.report, [self.job], self.root)
        self.assertEqual(self.report['attempts'], {})

    def test_resource_class_and_job_contract_cannot_be_relabelled(self):
        producer = self.executed()
        producer['queue'][0]['cohort'] = 'engine'
        with self.assertRaisesRegex(ValueError, 'classification differs'):
            accept_reference(self.reference(producer), self.report, [self.job], self.root)

    def test_unrun_failed_and_legacy_unhashed_evidence_cannot_pass(self):
        producer = self.executed()
        for status in ('unrun', 'skipped', 'ready-to-run', 'failed', 'running'):
            producer['attempts']['example'][-1]['status'] = status
            with self.subTest(status=status), self.assertRaises(ValueError):
                accept_reference(self.reference(producer), self.report, [self.job], self.root)
        producer['attempts']['example'][-1]['status'] = 'passed'
        producer['attempts']['example'][-1].pop('artifact_hashes')
        with self.assertRaisesRegex(ValueError, 'execution-time artifact hashes'):
            accept_reference(self.reference(producer), self.report, [self.job], self.root)

    def owner(self, cohort='engine'):
        self.job.update(cohort=cohort, receipt_only=True, units=['real-model'], output_kind='glb',
                        evidence_kind='native-production-asset')
        execution = self.put('native-fixture.json', {'status': 'passed', 'checks': ['synthetic test only'], 'unrun': []})
        return {'input_identity': self.identity, 'gate': 'example', 'resource_class': cohort,
                'evidence_kind': self.job['evidence_kind'], 'owner': 'test fixture', 'executed': True,
                'status': 'passed', 'units': {'real-model': 'passed'}, 'execution_report': 'native',
                'artifacts': {'native': {'path': str(execution), 'sha256': sha(execution)}},
                'resources': {'real-model': [{'path': 'absent.glb', 'sha256': '0' * 64}]}}

    def test_absent_or_recipe_only_asset_is_not_a_production_pass(self):
        producer = self.owner()
        with self.assertRaisesRegex(ValueError, 'Missing real production'):
            accept_reference(self.reference(producer, 'owner-closure'), self.report, [self.job], self.root)
        model = self.root / 'absent.glb'
        model.write_text('{"recipe": "not an export"}')
        producer['resources']['real-model'][0]['sha256'] = sha(model)
        with self.assertRaisesRegex(ValueError, 'actual exported GLB'):
            accept_reference(self.reference(producer, 'owner-closure'), self.report, [self.job], self.root)

    def test_owner_ready_or_wrong_class_or_missing_units_cannot_close_native(self):
        producer = self.owner()
        for key, value in [('executed', False), ('status', 'ready'), ('units', {}),
                           ('resource_class', 'source'), ('evidence_kind', 'source-only')]:
            changed = {**producer, key: value}
            with self.subTest(key=key), self.assertRaises(ValueError):
                accept_reference(self.reference(changed, 'owner-closure'), self.report, [self.job], self.root)
        self.assertFalse(self.report['attempts'])

    def test_receipt_dependencies_and_current_files_are_required(self):
        producer = self.executed()
        (self.root / 'source.txt').unlink()
        with self.assertRaisesRegex(ValueError, 'Required real input'):
            accept_reference(self.reference(producer), self.report, [self.job], self.root)
        (self.root / 'source.txt').write_text('source fixture')
        self.job['after'] = ['actual-production']
        with self.assertRaisesRegex(ValueError, 'prerequisite incomplete'):
            accept_reference(self.reference(producer), self.report, [self.job], self.root)

    def windows(self):
        producer = self.owner('external')
        self.job.pop('output_kind')
        self.job['receipt_policy'] = 'windows-release'
        self.job['units'] = ['windows-fixture']
        producer['units'] = {'windows-fixture': 'passed'}
        inputs = {}
        for name in ('godot/project.godot', 'tools/godot-package/verify_windows.mjs'):
            p = self.root / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text('synthetic closure fixture')
            inputs[name] = sha(p)
        for name in ('cocs.pck', 'cocs.exe', 'release.zip'):
            (self.root / name).write_bytes(b'test fixture, not a usable release')
        manifest = {'target': 'windows', 'port_commit': 'commit-fixture', 'inputs': inputs,
                    'files': {n: sha(self.root / n) for n in ('cocs.pck', 'cocs.exe')}}
        manifest_path = self.put('package-manifest.json', manifest)
        native = {'platform': 'win32', 'status': 'passed', 'port_commit': 'commit-fixture',
                  'manifest_sha256': sha(manifest_path), 'cases': [{'passed': True}]}
        visual = {'platform': 'win32', 'status': 'passed', 'graphical': True, 'port_commit': 'commit-fixture',
                  'cases': [{'unit': n, 'passed': True} for n in ('fighting-Home-and-nine-rigs',
                    'three-map-and-operator-finishes', 'replay-runtime', 'main-menu')]}
        ci = {'conclusion': 'success', 'platform': 'win32', 'clean_extraction': True,
              'used_checkout_runtime': False, 'run_url': 'https://example.invalid/not-real-CI',
              'port_commit': 'commit-fixture', 'archive_sha256': sha(self.root / 'release.zip')}
        roles = {'package_manifest': manifest_path, 'windows_report': self.put('windows.json', native),
                 'windows_graphical': self.put('graphical.json', visual), 'windows_ci': self.put('ci.json', ci),
                 'manifest_validation': self.put('validated.json', {'status': 'passed', 'target': 'windows', 'port_commit': 'commit-fixture'}),
                 'pck': self.root / 'cocs.pck', 'executable': self.root / 'cocs.exe', 'archive': self.root / 'release.zip'}
        producer['roles'] = {role: role for role in roles}
        producer['artifacts'].update({role: {'path': str(path), 'sha256': sha(path)} for role, path in roles.items()})
        producer['package_inputs'] = inputs
        return producer

    def test_windows_adapter_binds_actual_platform_archive_manifest_and_graphical_scope(self):
        producer = self.windows()
        accept_reference(self.reference(producer, 'owner-closure'), self.report, [self.job], self.root)
        self.report['attempts'].clear()
        for role, key, wrong in [('windows_report', 'platform', 'linux'), ('windows_ci', 'clean_extraction', False),
                                  ('windows_ci', 'used_checkout_runtime', True), ('windows_graphical', 'graphical', False)]:
            record = producer['artifacts'][role]
            path = Path(record['path'])
            original = json.loads(path.read_text())
            path.write_text(json.dumps({**original, key: wrong}))
            record['sha256'] = sha(path)
            with self.subTest(role=role, key=key), self.assertRaises(ValueError):
                accept_reference(self.reference(producer, 'owner-closure'), self.report, [self.job], self.root)
            path.write_text(json.dumps(original))
            record['sha256'] = sha(path)
        producer['package_inputs'].pop('godot/project.godot')
        with self.assertRaisesRegex(ValueError, 'input closure'):
            accept_reference(self.reference(producer, 'owner-closure'), self.report, [self.job], self.root)

    def test_combo_evidence_requires_both_facings_actual_contacts_and_no_missing_routes(self):
        self.put('godot/fighting/data/roster.json', {'operators': [{'id': 'fixture', 'combos': [{'name': 'route'}]}]})
        job = {'artifact_checks': [{'kind': 'combos', 'path': 'combos.json'}]}
        rows = [{'operator': 'fixture', 'name': 'route', 'facing': f, 'passed': True, 'continuous': True,
                 'replay_equal': True, 'contacts': [{'damage': 1}]} for f in (1, -1)]
        self.put('combos.json', {'results': rows, 'failures': 0})
        self.assertEqual(len(validate_artifact_checks(job, self.root, self.root)), 2)
        self.put('combos.json', {'results': rows[:1], 'failures': 0})
        with self.assertRaisesRegex(ValueError, 'Every authored combo'):
            validate_artifact_checks(job, self.root, self.root)
        rows[1]['continuous'] = False
        self.put('combos.json', {'results': rows, 'failures': 0})
        with self.assertRaisesRegex(ValueError, 'contact/continuity'):
            validate_artifact_checks(job, self.root, self.root)

    def test_final_extension_keeps_base_critical_jobs_and_delegates_existing_plan(self):
        base = load_matrix()
        final = load_matrix(ROOT / 'port/finish/final_matrix.json')
        self.assertEqual(final['jobs'][:len(base['jobs'])], base['jobs'])
        jobs = {j['id']: j for j in final['jobs']}
        plan = json.loads((ROOT / 'port/fighting/acceptance/plan.json').read_text())
        for job in plan['jobs']:
            delegated = jobs['fighting-plan-' + job['id']]
            self.assertEqual(delegated['delegated_job'], job)
            if job.get('script'):
                self.assertIn('tools/fighting/acceptance/run.py', delegated['command'])
        self.assertEqual(jobs['final-windows-release-proof']['receipt_policy'], 'windows-release')
        self.assertEqual(jobs['fighting-native-audio-review']['cohort'], 'audio')
        self.assertEqual(jobs['production-robots-native']['cohort'], 'engine')
        self.assertTrue(jobs['production-robots-native']['receipt_only'])
        report = {'input_identity': self.identity, 'attempts': {}}
        summarize(report, final['jobs'])
        self.assertFalse(report['integration_ready'])
        self.assertFalse(report['release_ready'])
        rows = {r['id']: r for r in report['completion_ledger']}
        self.assertEqual(rows['production-robots-native']['execution_status'], 'unrun')
        self.assertEqual(rows['production-robots-native']['preparation'], 'blocked')
        self.assertIn('final-windows-release-proof', report['incomplete_critical'])

    def test_camera_result_requires_one_complete_passing_json_record(self):
        job = {'output_checks': [{'prefix': 'FIGHTING_CAMERA_GATE'}]}
        good = 'FIGHTING_CAMERA_GATE {"passed":true,"failures":[]}'
        validate_output_checks(job, good)
        for output in ('', 'FIGHTING_CAMERA_GATE', 'FIGHTING_CAMERA_GATE null', good + '\n' + good,
                       'FIGHTING_CAMERA_GATE {"passed":false,"failures":[]}',
                       'FIGHTING_CAMERA_GATE {"passed":true}',
                       'FIGHTING_CAMERA_GATE {"passed":true,"failures":["clipped"]}'):
            with self.subTest(output=output), self.assertRaises(ValueError):
                validate_output_checks(job, output)

    def test_map_journey_requires_all_modes_current_bytes_and_clean_native_peers(self):
        recipe = self.put('map.json', {'geometryHash': 'geometry-fixture'})
        art = self.root / 'map.glb'
        art.write_bytes(b'synthetic identity fixture')
        job = {'map_journeys': {'id': 'map', 'recipe': 'map.json', 'art': 'map.glb',
                               'modes': ['deathmatch', 'ctf']}}
        data = {'map_journeys': {m: {'stage': 'private-production', 'artifact': m}
                                for m in ('deathmatch', 'ctf')}}
        artifacts = {}
        for mode in ('deathmatch', 'ctf'):
            artifacts[mode] = self.put(mode + '.json', {'id': 'map', 'mode': mode,
                'recipeSha': sha(recipe), 'artSha': sha(art), 'geometryHash': 'geometry-fixture',
                'success': True, 'journeyPassed': True, 'processFailed': False, 'accepted': False,
                'teardown': {'success': True, 'processFailed': False, 'serverError': None,
                             'peers': [{'clean': True}, {'clean': True}]}})
        validate_map_journeys(data, job, artifacts, self.root)
        # Production acceptance is supplied by the exact-anchor owner envelope;
        # the private producer correctly never sets public acceptance itself.
        incomplete = copy.deepcopy(data)
        incomplete['map_journeys'].pop('ctf')
        with self.assertRaisesRegex(ValueError, 'Every accepted'):
            validate_map_journeys(incomplete, job, artifacts, self.root)
        outcome = json.loads(artifacts['ctf'].read_text())
        outcome['teardown']['peers'][1]['clean'] = False
        artifacts['ctf'].write_text(json.dumps(outcome))
        with self.assertRaisesRegex(ValueError, 'teardown incomplete'):
            validate_map_journeys(data, job, artifacts, self.root)
        art.write_bytes(b'changed actual export')
        with self.assertRaisesRegex(ValueError, 'identity differs'):
            validate_map_journeys(data, job, artifacts, self.root)

    def test_foundry_preserved_luminaire_does_not_require_all_selectors_dressed(self):
        job = {'artifact_checks': [{'kind': 'map-finish', 'path': 'foundry.json', 'map': 'gravemill-foundry'}]}
        data = {'map': 'gravemill-foundry', 'failures': [], 'owned_max': 1, 'frame_usec': [16000],
                'initial': {'status': 'ready', 'surfaces': 7, 'preserved': 1},
                'reloaded': {'status': 'ready', 'surfaces': 7, 'preserved': 1}}
        self.put('foundry.json', data)
        validate_artifact_checks(job, self.root, self.root)
        data['failures'] = ['preserved luminaire emission changed']
        self.put('foundry.json', data)
        with self.assertRaisesRegex(ValueError, 'lifecycle proof incomplete'):
            validate_artifact_checks(job, self.root, self.root)

    def test_registration_uses_strict_closure_and_never_postpromotion_private_host(self):
        jobs = {j['id']: j for j in load_matrix(ROOT / 'port/finish/final_matrix.json')['jobs']}
        for name in ('final-seven-unit-production-closure', 'final-fighter-resource-closure'):
            self.assertNotIn('--audit', jobs[name]['command'])
            self.assertEqual(jobs[name]['cohort'], 'source')
        self.assertEqual(len(jobs['final-seven-unit-production-closure']['units']), 7)
        self.assertIn('fighting-camera-native', jobs['fighting-four-stage-training-review']['after'])
        for job in jobs.values():
            self.assertNotIn('tools/asset-production/candidate-hosted.mjs', job.get('command', []))
        self.assertEqual(sum(len(j.get('map_journeys', {}).get('modes', [])) for j in jobs.values()), 13)

    def test_package_conversion_is_not_an_owner_execution_receipt(self):
        producer = self.owner()
        producer.update(accepted=False, status='ready', executed=False)
        with self.assertRaisesRegex(ValueError, 'not acceptance'):
            accept_reference(self.reference(producer, 'owner-closure'), self.report, [self.job], self.root)


if __name__ == '__main__':
    unittest.main()
