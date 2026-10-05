"""Bounded two-case Walker support-query comparison -- offline source tests.

These tests exercise the ordering, omission, preservation, sealing and
fail-closed contracts of the source package. They are not native evidence: no
engine is started, no fixture is staged, and every "measurement" here is a
deterministic in-memory answer from :mod:`fixtures`.
"""
import copy
import importlib.util
import inspect
import json
import math
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('_support_query_compare_test_loader', HERE / 'cli.py')
loader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(loader)

seals = loader.module('seals')
policy = loader.module('policy')
invocation = loader.module('invocation')
hook = loader.module('hook')
history = loader.module('history')
driver = loader.module('driver')
evidence = loader.module('evidence')
campaign = loader.module('campaign')
prepare = loader.module('prepare')
supervisor = loader.module('supervisor')
fixtures = loader.module('fixtures')

ROOT = prepare.ROOT
SOURCE_HASH = 'a' * 64
GRANT_HASH = 'b' * 64


def historical():
    return history.reference(policy.case_ids(), policy.canonical(), root=ROOT)


def params(case_id):
    return fixtures.params_for(case_id)


def run_campaign(misbehave=None, **kwargs):
    """Run the two authorized cases and compose a receipt.

    ``misbehave`` may be one behaviour applied to both cases or a per-case
    mapping, which is what lets a test produce a campaign that diverges on one
    case and agrees on the other.
    """
    reference = historical()
    records = []
    for case_id in policy.CASES:
        behaviour = misbehave.get(case_id) if isinstance(misbehave, dict) else misbehave
        bounded = driver.BoundedDriver(case_id, params=params(case_id),
                                      historical=reference['cases'][case_id])
        records.append(bounded.run_case(fixtures.FakeLive(case_id, misbehave=behaviour, **kwargs)))
    return campaign.assert_receipt(
        campaign.compose(records, source_hash=SOURCE_HASH, grant_hash=GRANT_HASH,
                         engine_hash=policy.ENGINE, historical=reference),
        source_hash=SOURCE_HASH, grant_hash=GRANT_HASH, engine_hash=policy.ENGINE,
        historical=reference)


class CaseSetTests(unittest.TestCase):
    """Exactly two cases, fixed values, no third case reachable."""

    def test_case_set_is_exactly_the_two_authorized_finite_motion_cases(self):
        self.assertEqual(policy.CASE_COUNT, 2)
        self.assertEqual(policy.case_ids(), ('reference-035-015-neg45', 'failure-042-018-neg45'))
        seen = [(s['radius'], s['rise'], round(math.degrees(s['yaw']))) for s in policy.canonical()]
        self.assertEqual(seen, [(.35, .15, -45), (.42, .18, -45)])
        for spec_row in policy.canonical():
            self.assertEqual(spec_row['incline'], 0.0)
            self.assertEqual(spec_row['start'], -1.0)
            self.assertEqual(spec_row['goal'], 1.0)
            self.assertEqual(spec_row['maxResponses'], 240)

    def test_phase_allowlist_rejects_a_third_case_and_reordering(self):
        self.assertEqual(policy.validate_case_set(list(policy.CASES)), list(policy.CASES))
        for bad in ([*policy.CASES, 'extra-060-020-neg45'],
                    list(policy.CASES)[::-1],
                    [policy.CASES[0]],
                    ['extra', *policy.CASES]):
            with self.assertRaises(policy.PolicyError):
                policy.validate_case_set(bad)
        with self.assertRaises(policy.PolicyError):
            driver.BoundedDriver('extra-060-020-neg45', params={'margin': .02, 'bodyRid': 1},
                                 historical={'caseId': 'extra-060-020-neg45'})

    def test_campaign_runner_refuses_extra_missing_or_reordered_lives(self):
        good = fixtures.lives()
        for bad in ({**good, 'extra': None},
                    {policy.CASES[0]: good[policy.CASES[0]]},
                    {policy.CASES[1]: good[policy.CASES[1]], policy.CASES[0]: good[policy.CASES[0]]}):
            with self.assertRaises(policy.PolicyError):
                driver.run(bad, params=params(policy.CASES[0]), historical=historical())

    def test_no_020_fallback_and_no_inclined_case_exists(self):
        self.assertFalse(any(s['radius'] == .60 for s in policy.canonical()))
        self.assertFalse(any(s['incline'] != 0.0 for s in policy.canonical()))
        self.assertFalse(any(math.degrees(s['yaw']) > 0 for s in policy.canonical()))


class ZeroMotionOmissionTests(unittest.TestCase):
    """Exact-zero requests are omitted, never epsilon-substituted."""

    def test_two_exact_zero_observations_are_omitted_from_the_executable_proposal(self):
        receipt = run_campaign()
        for row in receipt['records']:
            self.assertEqual(len(row['omissions']), 2)
            self.assertEqual([o['ordinal'] for o in row['omissions']], [2, 5])
            for omission in row['omissions']:
                self.assertIs(omission['omitted'], True)
                self.assertIs(omission['executed'], False)
                self.assertIsNone(omission['substitutedMotion'])
                self.assertIs(omission['substitutionRefused'], True)
                self.assertEqual(omission['requestedMotion'], [0.0, 0.0, 0.0])
                self.assertEqual(omission['reason'], hook.OMISSION_REASON)
        self.assertEqual(receipt['zeroMotionRequestsExecuted'], 0)
        self.assertIs(receipt['epsilonSubstitutionUsed'], False)
        self.assertEqual(receipt['omittedObservationCount'], 2)

    def test_no_executed_observation_carries_zero_or_epsilon_motion(self):
        receipt = run_campaign()
        for row in receipt['records']:
            for observation in row['observations']:
                motion = observation['request']['motion']
                self.assertNotEqual(motion, [0.0, 0.0, 0.0])
                self.assertGreater(abs(motion[1]), hook.LIMIT)
                self.assertFalse(hook.zero(motion))
                self.assertAlmostEqual(motion[1], -(observation['request']['margin'] + hook.LIMIT),
                                       delta=hook.OPERAND_EPSILON)

    def test_omission_records_are_not_observations(self):
        receipt = run_campaign()
        for row in receipt['records']:
            ordinals = [o['ordinal'] for o in row['observations']]
            self.assertEqual(ordinals, [1, 3, 4])
            self.assertNotIn(2, ordinals)
            self.assertNotIn(5, ordinals)

    def test_hook_refuses_exact_zero_and_refuses_epsilon_pretending_to_be_zero(self):
        self.assertEqual(hook.down_motion({'margin': 0.02}), [0.0, -0.0201, 0.0])
        # An omission record must describe an *exactly* zero request; an epsilon
        # stand-in cannot be filed as one, and no substituted motion is accepted.
        for epsilon_motion in ([0.0, -1e-9, 0.0], [0.0, -0.0001, 0.0], [0.0, -1e-15, 0.0]):
            with self.assertRaises(hook.HookError):
                hook.omission(2, 'pre_up_predicted_endpoint', requested_motion=epsilon_motion)
        with self.assertRaises(hook.HookError):
            hook.omission(2, 'pre_up_predicted_endpoint', substituted_motion=[0.0, -1e-9, 0.0])
        with self.assertRaises(hook.HookError):
            hook.omission(2, 'pre_up_predicted_endpoint', reason='observed_no_hit')
        # A margin that cancels LIMIT exactly would yield an exact-zero motion.
        with self.assertRaises(hook.ExactZeroMotionOmitted):
            hook.down_motion({'margin': -hook.LIMIT})
        with self.assertRaises(hook.HookError):
            hook.down_motion({'margin': -0.02})

    def test_a_zero_motion_duplicate_is_refused_by_the_driver(self):
        reference = historical()
        bounded = driver.BoundedDriver(policy.CASES[1], params=params(policy.CASES[1]),
                                      historical=reference['cases'][policy.CASES[1]])
        with self.assertRaises(driver.BoundedContractError):
            bounded.run_case(fixtures.FakeLive(policy.CASES[1], misbehave='zero_motion_instead_of_duplicate'))


class ObservationOrderingTests(unittest.TestCase):
    """Pre-UP predicted-endpoint, one candidate+guard, post-hoc duplicate, stop."""

    def test_event_order_is_exactly_the_five_authorized_events(self):
        receipt = run_campaign()
        for row in receipt['records']:
            self.assertEqual(row['eventLog'], list(policy.EVENT_LOG))
            self.assertEqual(row['eventLog'],
                             ['pre_up_observation', 'candidate_response', 'guard_observation',
                              'duplicate_observation', 'stop'])
            self.assertEqual(row['status'], 'stopped_after_duplicate_observation')

    def test_pre_up_request_is_asked_at_the_predicted_endpoint_before_the_up_step(self):
        receipt = run_campaign()
        for row in receipt['records']:
            first = row['observations'][0]
            self.assertEqual(first['ordinal'], 1)
            self.assertEqual(first['site'], 'pre_up_predicted_endpoint')
            self.assertIs(first['issuedBy'], 'bounded_observer')
            self.assertIs(first['recordedBeforeUpStep'], True)
            self.assertIs(first['issuedAfterUpStep'], False)
            self.assertEqual(first['request']['from']['origin'], row['plan']['predictedEndpoint'])
            self.assertEqual(row['plan']['predictedEndpoint'],
                             [a + b for a, b in zip(row['plan']['raised']['origin'],
                                                    row['plan']['horizontalBudget'])])
            self.assertEqual(row['history']['preUpPredictedEndpointRecordedInAM'], False)
            # The guard's endpoint height legitimately differs from expectedFinal
            # because apply_floor_snap projects Y only; that offset is recorded.
            self.assertLessEqual(row['plan']['horizontalAgreementError'], row['plan']['epsilon'])
            self.assertAlmostEqual(
                row['plan']['verticalOffsetFromPredictedEndpoint'],
                row['plan']['expectedFinal'][1] - row['plan']['predictedEndpoint'][1], places=12)
            self.assertIn('raised.origin', row['plan']['predictedEndpointBasis'])

    def test_duplicate_is_posthoc_at_the_actual_final_state(self):
        receipt = run_campaign()
        for row in receipt['records']:
            guard_observation, duplicate = row['observations'][1], row['observations'][2]
            self.assertEqual(guard_observation['ordinal'], 3)
            self.assertEqual(duplicate['ordinal'], 4)
            self.assertEqual(duplicate['site'], 'duplicate_actual_final_state')
            self.assertIs(duplicate['recordedBeforeUpStep'], False)
            self.assertIs(duplicate['issuedAfterUpStep'], True)
            self.assertEqual(duplicate['request']['from']['origin'],
                             guard_observation['request']['from']['origin'])
            self.assertNotEqual(duplicate['request']['from']['origin'],
                                row['observations'][0]['request']['from']['origin'])

    def test_live_call_order_places_the_observation_before_the_candidate_response(self):
        reference = historical()
        case_id = policy.CASES[1]
        live = fixtures.FakeLive(case_id)
        bounded = driver.BoundedDriver(case_id, params=params(case_id),
                                      historical=reference['cases'][case_id])
        bounded.run_case(live)
        self.assertEqual(live.orders(), ['test_motion:' + hook.PRE_UP_NAME, 'candidate_response',
                                         'test_motion:' + hook.DUPLICATE_NAME])
        self.assertEqual(live.candidate_calls, 1)

    def test_guard_observation_is_the_guard_own_recorded_request_not_a_reissue(self):
        receipt = run_campaign()
        for row in receipt['records']:
            guard_observation = row['observations'][1]
            self.assertEqual(guard_observation['issuedBy'], 'unchanged_response_guard')
            self.assertEqual(guard_observation['request']['name'], hook.GUARD_NAME)
            self.assertIs(guard_observation['request'], guard_observation['result'])
            self.assertIsNone(guard_observation['bodyStateBefore'])
            self.assertIn("recorded verbatim", guard_observation['qualification'])
            self.assertIn('not reissued here', guard_observation['qualification'])
            self.assertIn('does not prove caches', guard_observation['qualification'])

    def test_only_the_first_eligible_transition_is_authorized(self):
        reference = historical()
        case_id = policy.CASES[0]
        bounded = driver.BoundedDriver(case_id, params=params(case_id),
                                      historical=reference['cases'][case_id])
        live = fixtures.FakeLive(case_id, extra_transitions=(200, 400))
        with self.assertRaises(driver.BoundedContractError):
            bounded.run_case(live, transition_index=200)
        self.assertEqual(live.candidate_calls, 0)

    def test_unaccepted_live_plan_is_refused_before_any_observation(self):
        reference = historical()
        case_id = policy.CASES[0]
        bounded = driver.BoundedDriver(case_id, params=params(case_id),
                                      historical=reference['cases'][case_id])
        live = fixtures.FakeLive(case_id, misbehave='unaccepted_plan')
        with self.assertRaises(driver.BoundedContractError):
            bounded.run_case(live)
        self.assertEqual(live.orders(), [])

    def test_engine_changing_frozen_operands_is_refused(self):
        reference = historical()
        case_id = policy.CASES[1]
        bounded = driver.BoundedDriver(case_id, params=params(case_id),
                                      historical=reference['cases'][case_id])
        with self.assertRaises(driver.BoundedContractError):
            bounded.run_case(fixtures.FakeLive(case_id, misbehave='operands_rewritten'))
        with self.assertRaises(driver.BoundedContractError):
            driver.BoundedDriver(case_id, params=params(case_id),
                                 historical=reference['cases'][case_id]).run_case(
                fixtures.FakeLive(case_id, misbehave='guard_support_motion_changed'))

    def test_observation_that_mutates_recorded_state_is_refused(self):
        reference = historical()
        case_id = policy.CASES[1]
        with self.assertRaises(driver.BoundedContractError):
            driver.BoundedDriver(case_id, params=params(case_id),
                                 historical=reference['cases'][case_id]).run_case(
                fixtures.FakeLive(case_id, misbehave='state_mutated_by_query'))


class GuardPreservationTests(unittest.TestCase):
    """The guard's result and fault stay intact; history is reported, not enforced."""

    def test_guard_result_and_fault_are_preserved_for_both_cases(self):
        receipt = run_campaign()
        by_case = {row['caseId']: row for row in receipt['records']}
        reference = by_case['reference-035-015-neg45']
        self.assertIs(reference['guard']['passed'], True)
        self.assertEqual(reference['guard']['reason'],
                         'endpoint_and_pinned_clear_branch_and_live_support_agree')
        self.assertEqual(reference['guard']['candidateFault'], '')
        self.assertIs(reference['guard']['preservedIntact'], True)
        self.assertEqual(reference['appliedUpCount'], 1)
        self.assertEqual(reference['parentResponseCount'], 1)
        failure = by_case['failure-042-018-neg45']
        self.assertIs(failure['guard']['passed'], False)
        self.assertEqual(failure['guard']['reason'], 'invalid_final_support_normal_or_velocity')
        self.assertEqual(failure['guard']['candidateFault'], 'invalid_final_support_normal_or_velocity')

    def test_guard_result_is_not_relabelled_to_history_when_it_changes(self):
        receipt = run_campaign(misbehave='guard_flipped')
        flipped = {row['caseId']: row for row in receipt['records']}['reference-035-015-neg45']
        self.assertIs(flipped['guard']['passed'], False)
        self.assertEqual(flipped['guard']['reason'], 'endpoint_differs_from_proof')
        self.assertEqual(flipped['guard']['candidateFault'], 'endpoint_differs_from_proof')
        self.assertIs(flipped['history']['agreesWithHistory'], False)
        self.assertEqual(flipped['history']['historicalGuardReason'],
                         'endpoint_and_pinned_clear_branch_and_live_support_agree')
        self.assertIsNotNone(flipped['unexpectedOutcome'])
        self.assertIn(flipped['unexpectedOutcome']['divergence']['field'], ('passed', 'reason'))
        self.assertEqual(receipt['unexpectedChangedOutcomes'],
                         [row['caseId'] for row in receipt['records']
                          if not row['history']['agreesWithHistory']])
        self.assertIs(receipt['guardOutcomesAgreeWithHistory'], False)
        self.assertEqual(evidence.unexpected_summary(receipt), receipt['unexpectedChangedOutcomes'])

    def test_one_divergent_case_does_not_relabel_the_other(self):
        receipt = run_campaign(misbehave={'reference-035-015-neg45': 'guard_flipped'})
        rows = {row['caseId']: row for row in receipt['records']}
        self.assertIs(rows['reference-035-015-neg45']['history']['agreesWithHistory'], False)
        self.assertIs(rows['failure-042-018-neg45']['history']['agreesWithHistory'], True)
        self.assertIsNone(rows['failure-042-018-neg45']['unexpectedOutcome'])
        self.assertEqual(receipt['unexpectedChangedOutcomes'], ['reference-035-015-neg45'])
        self.assertIs(receipt['guardOutcomesAgreeWithHistory'], False)
        reference = historical()
        self.assertTrue(evidence.receipt(receipt, source_hash=SOURCE_HASH, grant_hash=GRANT_HASH,
                                         engine_hash=policy.ENGINE, historical=reference))

    def test_history_is_reported_never_forced_and_the_receipt_still_validates(self):
        receipt = run_campaign(misbehave='guard_flipped')
        reference = historical()
        self.assertTrue(evidence.receipt(receipt, source_hash=SOURCE_HASH, grant_hash=GRANT_HASH,
                                         engine_hash=policy.ENGINE, historical=reference))
        # The historical facts stay readable next to the divergence.
        for row in receipt['records']:
            self.assertIsNotNone(row['history']['historicalGuardReason'])
            self.assertEqual(row['history']['amFrame'],
                             reference['cases'][row['caseId']]['amFrame'])

    def test_history_records_the_frozen_AM_facts_and_still_shows_the_gap(self):
        reference = historical()
        self.assertEqual(reference['amWholePositiveFailed'], True)
        self.assertEqual(reference['amWholePositiveOutcome'], 'candidate_or_reset_fault')
        self.assertEqual(reference['amVerifiedLiftsForFailureCase'], 0)
        self.assertEqual(reference['unrunPositiveCase'], '.42/.18/+45')
        self.assertEqual(reference['amNativeSha256'],
                         '779b00c88f53d6b4fcb9b171844769ffc2133e2d11c0bf3300419861b3a81a57')
        table = reference['cases']
        self.assertEqual(table['reference-035-015-neg45']['amFrame'], 176)
        self.assertEqual(table['failure-042-018-neg45']['amFrame'], 550)
        angles = {'reference-035-015-neg45': 36.67732574092844,
                  'failure-042-018-neg45': 47.476992341452714}
        for case_id, expected in table.items():
            self.assertIs(expected['preUpPredictedEndpointRecorded'], False)
            self.assertIs(expected['guardPassed'], case_id == 'reference-035-015-neg45')
            self.assertAlmostEqual(expected['freshGuardNormalAngleDegrees'], angles[case_id],
                                   places=9)


class NoFurtherMovementTests(unittest.TestCase):
    """One candidate response, then stop. No retry, no second step, no rerun."""

    def test_exactly_one_candidate_response_and_no_further_movement(self):
        receipt = run_campaign()
        for row in receipt['records']:
            self.assertEqual(row['candidateResponses'], 1)
            self.assertEqual(row['appliedUpCount'], 1)
            self.assertEqual(row['parentResponseCount'], 1)
            for key in ('subsequentMovementResponses', 'retries', 'normalSelections',
                        'acceptanceSubstitutions'):
                self.assertEqual(row[key], 0)
            self.assertIs(row['stoppedAfterDuplicateObservation'], True)
            self.assertIs(row['subsequentMovementPossible'], False)

    def test_driver_is_terminal_after_stop(self):
        reference = historical()
        case_id = policy.CASES[0]
        bounded = driver.BoundedDriver(case_id, params=params(case_id),
                                      historical=reference['cases'][case_id])
        live = fixtures.FakeLive(case_id)
        bounded.run_case(live)
        self.assertTrue(bounded.stopped)
        self.assertEqual(bounded.phase, 'stopped')
        with self.assertRaises(driver.Stopped):
            bounded.state()
        with self.assertRaises(driver.BoundedContractError):
            bounded.run_case(fixtures.FakeLive(case_id))
        self.assertEqual(fixtures.FakeLive(case_id).candidate_calls, 0)

    def test_second_candidate_response_is_unreachable(self):
        reference = historical()
        case_id = policy.CASES[0]
        bounded = driver.BoundedDriver(case_id, params=params(case_id),
                                      historical=reference['cases'][case_id])
        live = fixtures.FakeLive(case_id, misbehave='second_candidate_response')
        bounded.run_case(live)
        self.assertEqual(live.candidate_calls, 1)

    def test_a_second_lift_or_parent_call_is_refused(self):
        reference = historical()
        case_id = policy.CASES[1]
        live = fixtures.FakeLive(case_id)
        original = live.candidate_response
        bounded = driver.BoundedDriver(case_id, params=params(case_id),
                                      historical=reference['cases'][case_id])
        bounded.run_case(live)
        for mutation in ({'appliedUpCount': 2}, {'parentResponseCount': 2},
                         {'parentResponseCount': 0}):
            def mutate(plan, mutation=mutation):
                response = original(plan)
                response.update(mutation)
                return response
            live.candidate_response = mutate
            with self.assertRaises(driver.BoundedContractError):
                driver.BoundedDriver(case_id, params=params(case_id),
                                     historical=reference['cases'][case_id]).run_case(live)
            live.candidate_response = original


class SealTests(unittest.TestCase):
    """Write-once records and seals; tampering and reruns are refused."""

    def with_record(self, function):
        holder = tempfile.TemporaryDirectory(dir='/tmp/opencode', prefix='support-query-compare-')
        self.addCleanup(holder.cleanup)
        parent = Path(holder.name) / 'runs'
        parent.mkdir()
        return function(prepare.build('support-query-compare-review-only', parent))

    def test_record_builds_and_validates_with_a_seal_manifest(self):
        def check(dest):
            record = prepare.validate_record(dest)
            self.assertEqual(record['allowedCases'], list(policy.CASES))
            self.assertEqual(record['caseCount'], 2)
            self.assertEqual(record['candidateResponseBudget'], 1)
            self.assertIsNone(record['grant'])
            self.assertIs(record['autoStart'], False)
            self.assertIs(record['queued'], False)
            self.assertEqual(record['engineInvocations'], 0)
            self.assertEqual(record['proposal']['epsilonSubstitutionUsed'], False)
            self.assertEqual(record['proposal']['limit'], hook.LIMIT)
            self.assertEqual(record['proposal']['maxCollisions'], 32)
            self.assertEqual([o['ordinal'] for o in record['proposal']['observationSites']], [1, 2, 3, 4, 5])
            self.assertEqual([o['disposition'] for o in record['proposal']['observationSites']],
                             ['executed', 'omitted', 'executed', 'executed', 'omitted'])
            manifest = seals.load(dest / prepare.MANIFEST_NAME)
            self.assertEqual(manifest['sealsVerified'], 1)
            self.assertTrue(seals.UTC.fullmatch(manifest['utc']))
        self.with_record(check)

    def test_rerun_cannot_overwrite_an_existing_record_or_its_refusal(self):
        holder = tempfile.TemporaryDirectory(dir='/tmp/opencode', prefix='support-query-compare-')
        self.addCleanup(holder.cleanup)
        parent = Path(holder.name) / 'runs'
        parent.mkdir()
        dest = prepare.build('support-query-compare-review-only', parent)
        with self.assertRaises(FileExistsError):
            prepare.build('support-query-compare-review-only', parent)
        self.assertEqual(prepare.validate_record(dest)['attempt'], dest.name)
        first = supervisor.refuse(dest, checks=supervisor.preflight(dest))
        self.assertEqual(seals.sha(first), seals.sha(first))
        with self.assertRaises(FileExistsError):
            supervisor.refuse(dest, checks=supervisor.preflight(dest))
        # A refusal is expected inside a record, so the record still validates.
        self.assertEqual(prepare.validate_record(dest)['engineInvocations'], 0)
        self.assertEqual(len(list(dest.iterdir())), 3)

    def test_tampered_record_fails_its_seal_and_its_contract(self):
        def check(dest):
            record_path = dest / prepare.RECORD_NAME
            record = seals.load(record_path)
            record['caseCount'] = 3
            record_path.write_text(json.dumps(record, indent=2) + '\n')
            with self.assertRaises(ValueError):
                seals.verify_seals(dest, seals.load(dest / prepare.MANIFEST_NAME)['seals'])
            with self.assertRaises(prepare.PrepareError):
                prepare.validate_record(dest)
        self.with_record(check)

    def test_tampered_guard_outcome_fails_seal_and_contract(self):
        def check(dest):
            path = dest / prepare.RECORD_NAME
            record = seals.load(path)
            record['history']['cases']['failure-042-018-neg45']['guardReason'] = 'endpoint_differs_from_proof'
            path.write_text(json.dumps(record, indent=2) + '\n')
            with self.assertRaises(prepare.PrepareError):
                prepare.validate_record(dest)
        self.with_record(check)

    def test_extra_file_or_symlink_inside_a_record_is_refused(self):
        def check(dest):
            (dest / 'leftover.json').write_text('{}\n')
            with self.assertRaises(prepare.PrepareError):
                prepare.validate_record(dest)
            (dest / 'leftover.json').unlink()
            (dest / 'link.json').symlink_to(dest / prepare.RECORD_NAME)
            with self.assertRaises(prepare.PrepareError):
                prepare.validate_record(dest)
        self.with_record(check)

    def test_seal_verification_rejects_every_field_tampering(self):
        def check(dest):
            sealed = seals.load(dest / prepare.MANIFEST_NAME)['seals']
            # ``role`` is metadata, not an integrity field: changing it is detected
            # only when the manifest as a whole is compared, so it is exercised
            # separately below. Every integrity field must reject a mutation.
            for mutation in ({'sha256': 'f' * 64}, {'bytes': sealed[0]['bytes'] + 1},
                             {'path': 'other.json'}, {'sha256': sealed[0]['sha256'].upper()},
                             {'path': '../escape.json'}, {'sha256': 'not-hex'}):
                bad = copy.deepcopy(sealed)
                bad[0].update(mutation)
                with self.assertRaises(ValueError):
                    seals.verify_seals(dest, bad)
            for bad in ([], copy.deepcopy(sealed) * 2, [{'path': 'source-record.json'}]):
                with self.assertRaises(ValueError):
                    seals.verify_seals(dest, bad)
            self.assertEqual(seals.verify_seals(dest, sealed), {'sealsVerified': 1,
                                                                'sealedBytes': sealed[0]['bytes']})
        self.with_record(check)

    def test_manifest_role_drift_is_caught_by_validate_record(self):
        def check(dest):
            path = dest / prepare.MANIFEST_NAME
            manifest = seals.load(path)
            manifest['seals'][0]['role'] = 'substituted'
            path.write_text(json.dumps(manifest, indent=2) + '\n')
            with self.assertRaises(prepare.PrepareError):
                prepare.validate_record(dest)
        self.with_record(check)

    def test_record_refuses_to_be_staged_into_the_godot_project_tree(self):
        with self.assertRaises(prepare.PrepareError):
            prepare.build('support-query-compare-review-only', ROOT / 'godot' / 'tests')
        with self.assertRaises(prepare.PrepareError):
            prepare.validate_record(ROOT / 'godot' / 'tests' / 'support-query-compare-review-only')

    def test_attempt_namespace_is_canonical_and_bounded(self):
        for bad in ('Support-Query-Compare', 'support-query-compare', 'a' * 200,
                    'support-query-compare-../escape', ''):
            with self.assertRaises(prepare.PrepareError):
                prepare.namespace(bad)

    def test_write_once_refuses_an_existing_path_and_load_refuses_bad_json(self):
        with tempfile.TemporaryDirectory(dir='/tmp/opencode', prefix='support-query-compare-') as d:
            path = Path(d) / 'record.json'
            seals.write_once(path, {'a': 1})
            with self.assertRaises(FileExistsError):
                seals.write_once(path, {'a': 2})
            duplicate = Path(d) / 'duplicate.json'
            duplicate.write_text('{"a":1,"a":2}')
            with self.assertRaises(ValueError):
                seals.load(duplicate)
            (Path(d) / 'nan.json').write_text('{"a":NaN}')
            with self.assertRaises(ValueError):
                seals.load(Path(d) / 'nan.json')


class SupervisorTests(unittest.TestCase):
    """Preflight runs in full, then the supervisor refuses. Nothing is launched."""

    def with_record(self):
        holder = tempfile.TemporaryDirectory(dir='/tmp/opencode', prefix='support-query-compare-')
        self.addCleanup(holder.cleanup)
        parent = Path(holder.name) / 'runs'
        parent.mkdir()
        return prepare.build('support-query-compare-review-only', parent)

    def test_preflight_verifies_record_seals_references_and_history(self):
        dest = self.with_record()
        checks = supervisor.preflight(dest)
        self.assertTrue(checks['recordContractMatches'])
        self.assertEqual(checks['allowedCases'], list(policy.CASES))
        self.assertEqual(checks['caseCount'], 2)
        self.assertEqual(checks['candidateResponseBudget'], 1)
        self.assertEqual(checks['amHistoryVerified'], 2)
        self.assertIs(checks['amWholePositiveStillFailed'], True)
        self.assertGreaterEqual(checks['frozenReferencesVerified'], 6)
        self.assertIs(checks['grantPresent'], False)
        self.assertIs(checks['grantValidated'], False)
        self.assertIs(checks['engineResolved'], False)

    def test_supervisor_refuses_and_records_why(self):
        dest = self.with_record()
        checks = supervisor.preflight(dest)
        refusal = seals.load(supervisor.refuse(dest, checks=checks))
        self.assertIs(refusal['refused'], True)
        self.assertEqual(refusal['engineInvocations'], 0)
        self.assertIs(refusal['engineResolutionAttempted'], False)
        self.assertIs(refusal['nativeArgvStaged'], False)
        self.assertEqual(refusal['nativeLaunchPaths'], 0)
        self.assertIs(refusal['nativeReadiness']['ready'], False)
        self.assertEqual(refusal['blockingReasons'], list(policy.NATIVE_READINESS_BLOCKERS))
        self.assertIs(refusal['positiveAdmission'], False)
        self.assertIs(refusal['nativeStepAdmission'], False)
        self.assertIs(refusal['productionPromotion'], False)
        self.assertIs(refusal['amWholePositiveFailed'], True)
        self.assertEqual(refusal['unrunPositiveCase'], '.42/.18/+45')
        self.assertEqual(refusal['candidateMapJourneysUnrun'], 60)
        self.assertEqual(refusal['staticVesperFailuresUnresolved'], 184)
        self.assertIs(refusal['productionAccountingOpen'], True)
        self.assertIs(refusal['plannedArgvIsADescriptionNotACommand'], True)

    def test_second_refusal_is_refused_so_evidence_cannot_be_replaced(self):
        dest = self.with_record()
        first = supervisor.refuse(dest, checks=supervisor.preflight(dest))
        original = seals.sha(first)
        with self.assertRaises(FileExistsError):
            supervisor.refuse(dest, checks=supervisor.preflight(dest))
        self.assertEqual(seals.sha(first), original)

    def test_no_module_in_this_package_can_execute_another_program(self):
        report = invocation.audit(HERE)
        self.assertEqual(report['engineInvocationPaths'], 0)
        self.assertGreaterEqual(report['modulesAudited'], 12)
        self.assertIn('subprocess', report['forbiddenImports'])
        for name in sorted(p.name for p in HERE.glob('*.py')):
            self.assertEqual(invocation.findings(HERE / name), [], name)

    def test_the_invocation_audit_would_catch_a_real_engine_path(self):
        for snippet in ('import subprocess\nsubprocess.run(["godot"])\n',
                        'import subprocess\nsubprocess.Popen(argv)\n',
                        'from subprocess import Popen\nPopen(argv)\n',
                        'from subprocess import run\nrun(argv)\n',
                        'import os\nos.system("godot --headless")\n',
                        'import os\nos.popen("godot --headless")\n',
                        'import os\nos.execv(binary, argv)\n',
                        'import os\nos.spawnv(1, b, a)\n',
                        'import os\nos.fork()\n',
                        'import shutil\nshutil.which("godot")\n',
                        'import multiprocessing\nmultiprocessing.Process()\n',
                        'from os import system\nsystem("godot")\n',
                        'import subprocess\nsubprocess.run(argv, shell=True)\n'):
            with tempfile.TemporaryDirectory(dir='/tmp/opencode') as d:
                path = Path(d) / 'engine_path.py'
                path.write_text(snippet)
                self.assertTrue(invocation.findings(path), snippet.splitlines()[0])
        self.assertEqual(invocation.findings(HERE / 'policy.py'), [])

    def test_the_invocation_audit_ignores_prose_that_merely_mentions_spawning(self):
        with tempfile.TemporaryDirectory(dir='/tmp/opencode') as d:
            path = Path(d) / 'prose.py'
            path.write_text('"""Never invokes subprocess or os.system; that is the point."""\n'
                            'TEXT = "Popen"\n'
                            'def run():\n'
                            '    """A local helper named run is not a launch."""\n'
                            '    return TEXT\n')
            self.assertEqual(invocation.findings(path), [])

    def test_supervisor_launch_constants_are_zero(self):
        self.assertEqual(supervisor.NATIVE_LAUNCH_PATHS, 0)
        self.assertIs(supervisor.NATIVE_ARGV_STAGED, False)

    def test_planned_argv_is_only_constructible_for_the_two_authorized_cases(self):
        argv = supervisor.planned_argv(grant_id='MOTH-BLENDER-20261005-AN',
                                       grant_sha256='c' * 64,
                                       dependencies_sha256='d' * 64,
                                       case_id=policy.CASES[0])
        self.assertIn('--grant-id=MOTH-BLENDER-20261005-AN', argv)
        self.assertIn('--grant-sha256=' + 'c' * 64, argv)
        self.assertIn('--case=' + policy.CASES[0], argv)
        # The engine and fixture slots stay literal: no binary is resolved and no
        # fixture is staged by this package.
        self.assertEqual(argv[0], '{engine}')
        self.assertIn('{fixture}', argv)
        for case_id in policy.CASES:
            self.assertIn('--case=' + case_id,
                          supervisor.planned_argv(grant_id='g', grant_sha256='c' * 64,
                                                  dependencies_sha256='d' * 64,
                                                  case_id=case_id))
        with self.assertRaises(supervisor.SupervisorRefusal):
            supervisor.planned_argv(grant_id='x', grant_sha256='y', dependencies_sha256='z',
                                    case_id='extra-060-020-neg45')
        for bad in ({'grant_id': ''}, {'grant_id': 'a{b}'}, {'grant_sha256': '{case}'},
                    {'dependencies_sha256': '<unknown>'}):
            arguments = {'grant_id': 'g', 'grant_sha256': 'c' * 64,
                         'dependencies_sha256': 'd' * 64, 'case_id': policy.CASES[0]}
            arguments.update(bad)
            with self.assertRaises(supervisor.SupervisorRefusal):
                supervisor.planned_argv(**arguments)

    def test_preflight_refuses_a_missing_or_tampered_record(self):
        holder = tempfile.TemporaryDirectory(dir='/tmp/opencode', prefix='support-query-compare-')
        self.addCleanup(holder.cleanup)
        with self.assertRaises(Exception):
            supervisor.preflight(Path(holder.name) / 'absent')
        dest = self.with_record()
        (dest / prepare.RECORD_NAME).unlink()
        with self.assertRaises(Exception):
            supervisor.preflight(dest)

    def test_grant_validation_is_fail_closed_and_bound_to_the_two_cases(self):
        grant = {'phase': policy.PHASE, 'mode': policy.MODE, 'allowedCases': list(policy.CASES),
                 'grantId': 'MOTH-BLENDER-20261005-AN', 'authorized': True, 'expiresUnix': 200.0,
                 'sourceSha256': SOURCE_HASH, 'engineSha256': policy.ENGINE}
        policy.validate_grant(grant, case_ids_in=list(policy.CASES), source_hash=SOURCE_HASH,
                              engine_hash=policy.ENGINE, now=100.0)
        for key, value in [('phase', 'support-query-compare-v2'),
                           ('mode', 'bounded-support-query-v2'),
                           ('allowedCases', list(policy.CASES)[::-1]),
                           ('allowedCases', [*policy.CASES, 'extra-060-020-neg45']),
                           ('allowedCases', [policy.CASES[0]]),
                           ('authorized', False), ('expiresUnix', 100.0),
                           ('expiresUnix', True), ('expiresUnix', float('inf')),
                           ('sourceSha256', 'e' * 64), ('engineSha256', 'f' * 64),
                           ('grantId', ''), ('extra', 1)]:
            with self.assertRaises(policy.PolicyError):
                policy.validate_grant(dict(grant, **{key: value}), case_ids_in=list(policy.CASES),
                                      source_hash=SOURCE_HASH, engine_hash=policy.ENGINE, now=100.0)
        with self.assertRaises(policy.PolicyError):
            policy.validate_grant(grant, case_ids_in=list(policy.CASES), source_hash=SOURCE_HASH,
                                  engine_hash='f' * 64, now=100.0)


class ReceiptValidatorTests(unittest.TestCase):
    """The validator rejects tampering, reordering and unexpected outcomes."""

    def mutate(self, change):
        receipt = copy.deepcopy(run_campaign())
        change(receipt)
        reference = historical()
        self.assertFalse(evidence.receipt(receipt, source_hash=SOURCE_HASH, grant_hash=GRANT_HASH,
                                          engine_hash=policy.ENGINE, historical=reference))
        return receipt

    def test_the_unaltered_receipt_validates(self):
        receipt = run_campaign()
        reference = historical()
        self.assertTrue(evidence.receipt(receipt, source_hash=SOURCE_HASH, grant_hash=GRANT_HASH,
                                         engine_hash=policy.ENGINE, historical=reference))

    def test_a_third_record_is_refused(self):
        def change(receipt):
            receipt['records'].append(copy.deepcopy(receipt['records'][1]))
            receipt['records'][2]['caseIndex'] = 2
        self.mutate(change)
        self.mutate(lambda receipt: receipt.__setitem__('caseCount', 3))
        self.mutate(lambda receipt: receipt['records'].pop())

    def test_reordered_observations_are_refused(self):
        def change(receipt):
            row = receipt['records'][0]
            row['observations'][0], row['observations'][2] = row['observations'][2], row['observations'][0]
        self.mutate(change)
        self.mutate(lambda receipt: receipt['records'][0].__setitem__('eventLog', [
            'candidate_response', 'pre_up_observation', 'guard_observation',
            'duplicate_observation', 'stop']))
        self.mutate(lambda receipt: receipt['records'][0].__setitem__('eventLog', [
            'pre_up_observation', 'guard_observation', 'candidate_response',
            'duplicate_observation', 'stop']))

    def test_a_pre_up_observation_relabelled_as_posthoc_is_refused(self):
        self.mutate(lambda receipt: receipt['records'][0]['observations'][0].__setitem__(
            'recordedBeforeUpStep', False))
        self.mutate(lambda receipt: receipt['records'][0]['observations'][2].__setitem__(
            'recordedBeforeUpStep', True))
        self.mutate(lambda receipt: receipt['records'][0]['observations'][1].__setitem__(
            'recordedBeforeUpStep', True))

    def test_a_duplicate_asked_at_another_pose_is_refused(self):
        def change(receipt):
            request = receipt['records'][0]['observations'][2]['request']
            request['from']['origin'][1] += 0.001
            receipt['records'][0]['observations'][2]['result'] = copy.deepcopy(request)
        self.mutate(change)
        def change_origin(receipt):
            request = receipt['records'][0]['observations'][2]['request']
            request['from']['origin'] = list(receipt['records'][0]['plan']['predictedEndpoint'])
            receipt['records'][0]['observations'][2]['result'] = copy.deepcopy(request)
        self.mutate(change_origin)

    def test_a_records_digest_binds_every_recorded_byte(self):
        receipt = run_campaign()
        self.assertEqual(receipt['recordsSha256'], evidence.records_digest(receipt['records']))
        self.assertEqual(len(receipt['recordsSha256']), 64)
        self.assertEqual(receipt['recordsSha256'], run_campaign()['recordsSha256'])
        self.assertIsNone(evidence.records_digest([{'x': float('nan')}]))

    def test_tampered_contacts_and_predicates_are_refused(self):
        # A recorded normal is free evidence, so the digest is what catches an edit
        # to it; the structural predicates catch the operand and predicate edits.
        self.mutate(lambda receipt: receipt['records'][1]['observations'][2]['result']
                    ['contacts'][0].__setitem__('normal', [0.0, 1.0, 0.0]))
        def velocity(receipt):
            receipt['records'][1]['observations'][1]['result']['contacts'][0]['velocity'] = [0.0, 1.0, 0.0]
        self.mutate(velocity)
        def nonfinite(receipt):
            receipt['records'][1]['observations'][0]['result']['contacts'][0]['depth'] = float('nan')
        self.mutate(nonfinite)
        def saturated(receipt):
            receipt['records'][1]['observations'][0]['result']['contacts'] = [{}] * 32
        self.mutate(saturated)
        def fractions(receipt):
            receipt['records'][1]['observations'][0]['result']['safeFraction'] = 0.9
            receipt['records'][1]['observations'][0]['result']['unsafeFraction'] = 0.5
        self.mutate(fractions)
        def motion(receipt):
            receipt['records'][1]['observations'][0]['request']['motion'] = [0.0, -0.05, 0.0]
            receipt['records'][1]['observations'][0]['result']['motion'] = [0.0, -0.05, 0.0]
        self.mutate(motion)
        def flags(receipt):
            receipt['records'][1]['observations'][0]['result']['recoveryAsCollision'] = False
        self.mutate(flags)
        def exclusions(receipt):
            receipt['records'][1]['observations'][0]['result']['excludeBodies'] = [1]
        self.mutate(exclusions)

    def test_removed_or_edited_omissions_are_refused(self):
        self.mutate(lambda receipt: receipt['records'][0]['omissions'].pop())
        def substitute(receipt):
            receipt['records'][0]['omissions'][0]['substitutedMotion'] = [0.0, -1e-9, 0.0]
        self.mutate(substitute)
        def executed(receipt):
            receipt['records'][0]['omissions'][0]['executed'] = True
        self.mutate(executed)
        def reason(receipt):
            receipt['records'][0]['omissions'][1]['reason'] = 'unmeasured'
        self.mutate(reason)
        self.mutate(lambda receipt: receipt.__setitem__('zeroMotionRequestsExecuted', 1))
        self.mutate(lambda receipt: receipt.__setitem__('epsilonSubstitutionUsed', True))

    def test_extra_candidate_response_or_movement_is_refused(self):
        self.mutate(lambda receipt: receipt['records'][0].__setitem__('candidateResponses', 2))
        self.mutate(lambda receipt: receipt['records'][0].__setitem__('appliedUpCount', 2))
        self.mutate(lambda receipt: receipt['records'][0].__setitem__('parentResponseCount', 0))
        self.mutate(lambda receipt: receipt['records'][0].__setitem__('retries', 1))
        self.mutate(lambda receipt: receipt['records'][0].__setitem__('subsequentMovementResponses', 1))
        self.mutate(lambda receipt: receipt['records'][0].__setitem__('normalSelections', 1))
        self.mutate(lambda receipt: receipt['records'][0].__setitem__('acceptanceSubstitutions', 1))
        self.mutate(lambda receipt: receipt['records'][0].__setitem__('subsequentMovementPossible', True))
        self.mutate(lambda receipt: receipt['records'][0].__setitem__(
            'stoppedAfterDuplicateObservation', False))

    def test_guard_field_tampering_is_refused(self):
        def fault(receipt):
            receipt['records'][1]['guard']['candidateFault'] = ''
        self.mutate(fault)
        def reason(receipt):
            receipt['records'][1]['guard']['reason'] = 'actual_contact_off_landing_plane'
        self.mutate(reason)
        def intact(receipt):
            receipt['records'][1]['guard']['preservedIntact'] = False
        self.mutate(intact)
        def passed(receipt):
            receipt['records'][1]['guard']['passed'] = True
        self.mutate(passed)

    def test_an_unreported_divergence_is_refused(self):
        def flip(receipt):
            receipt['records'][1]['guard']['passed'] = True
            receipt['records'][1]['guard']['reason'] = 'endpoint_differs_from_proof'
            receipt['records'][1]['guard']['candidateFault'] = 'endpoint_differs_from_proof'
            receipt['records'][1]['history']['agreesWithHistory'] = True
        self.mutate(flip)
        def hidden(receipt):
            receipt['records'][1]['history']['agreesWithHistory'] = False
        self.mutate(hidden)
        def summary(receipt):
            receipt['unexpectedChangedOutcomes'] = ['reference-035-015-neg45']
        self.mutate(summary)
        def agrees_flag(receipt):
            receipt['guardOutcomesAgreeWithHistory'] = False
        self.mutate(agrees_flag)

    def test_overclaiming_fields_are_refused(self):
        for key in ('operationalNeutralityProven', 'hiddenStateUnaffectedProven',
                    'queryStateEqualityProvesCacheNeutrality', 'backendImplementationVerified',
                    'parentInternalCallsTraced', 'positiveAdmission', 'nativeStepAdmission',
                    'productionPromotion'):
            self.mutate(lambda receipt, key=key: receipt.__setitem__(key, True))
        # ``exactZeroMotionOmitted`` is required to be present-and-True; flipping it
        # breaks the schema, so the schema check is what rejects the mutation.
        receipt = copy.deepcopy(run_campaign())
        receipt['exactZeroMotionOmitted'] = False
        self.assertFalse(evidence.receipt(receipt, source_hash=SOURCE_HASH, grant_hash=GRANT_HASH,
                                          engine_hash=policy.ENGINE, historical=historical()))
        self.mutate(lambda receipt: receipt.__setitem__('physicalCallCounts', 1234))
        self.mutate(lambda receipt: receipt.__setitem__('candidateMapWalks', 1))
        self.mutate(lambda receipt: receipt.__setitem__('engineInvocations', 1))
        self.mutate(lambda receipt: receipt.__setitem__('authority', 'granted'))
        self.mutate(lambda receipt: receipt.__setitem__('failed', True))
        self.mutate(lambda receipt: receipt.__setitem__('contractHeld', False))
        self.mutate(lambda receipt: receipt['nativeReadiness'].__setitem__('ready', True))
        self.mutate(lambda receipt: receipt['nativeReadiness'].__setitem__('blockingReasons', []))

    def test_hash_and_schema_binding_is_refused(self):
        for key, value in [('sourceSha256', 'c' * 64), ('grantSha256', 'c' * 64),
                           ('engineSha256', 'c' * 64), ('phase', 'support-query-compare-v2'),
                           ('mode', 'other'), ('group', 'other'), ('scope', 'other'),
                           ('caseCount', 4), ('executableObservationCount', 4),
                           ('omittedObservationCount', 0), ('candidateResponseBudget', 2)]:
            self.mutate(lambda receipt, key=key, value=value: receipt.__setitem__(key, value))
        self.mutate(lambda receipt: receipt.pop('records'))
        self.mutate(lambda receipt: receipt.__setitem__('extraField', 1))

    def test_a_malformed_value_never_raises(self):
        reference = historical()
        for bad in (None, 0, 'x', [], {}, {'records': []}, float('nan'),
                    run_campaign() | {'records': [None, None]}):
            self.assertFalse(evidence.receipt(bad, source_hash=SOURCE_HASH, grant_hash=GRANT_HASH,
                                              engine_hash=policy.ENGINE,
                                              historical=reference))
        self.assertIsNone(evidence.unexpected_summary(None))

    def test_specification_tampering_is_refused(self):
        def rise(receipt):
            receipt['records'][0]['spec']['rise'] = 0.20
        self.mutate(rise)
        def radius(receipt):
            receipt['records'][1]['spec']['radius'] = 0.35
        self.mutate(radius)
        def yaw(receipt):
            receipt['records'][0]['spec']['yaw'] = math.radians(45.0)
        self.mutate(yaw)
        def case(receipt):
            receipt['records'][0]['caseId'] = 'extra-060-020-neg45'
        self.mutate(case)
        def index(receipt):
            receipt['records'][1]['caseIndex'] = 0
        self.mutate(index)
        def first_transition(receipt):
            receipt['records'][0]['firstEligibleTransition'] = 400
        self.mutate(first_transition)
        def not_first(receipt):
            receipt['records'][0]['usedFirstEligibleTransition'] = False
        self.mutate(not_first)
        def history_case(receipt):
            receipt['records'][0]['history']['amCaseIndex'] = 9
        self.mutate(history_case)
        def history_gap(receipt):
            receipt['records'][0]['history']['preUpPredictedEndpointRecordedInAM'] = True
        self.mutate(history_gap)

    def test_a_nonfinite_plan_coordinate_is_refused(self):
        def nan(receipt):
            receipt['records'][0]['plan']['expectedFinal'][1] = float('nan')
        self.mutate(nan)
        def huge(receipt):
            receipt['records'][0]['plan']['epsilon'] = 1e-3
        self.mutate(huge)
        def misaligned(receipt):
            receipt['records'][0]['plan']['predictedEndpoint'][0] += 0.01
        self.mutate(misaligned)
        def hidden_horizontal(receipt):
            receipt['records'][0]['plan']['horizontalAgreementError'] = 0.0
        self.mutate(hidden_horizontal)
        def hidden_vertical(receipt):
            receipt['records'][0]['plan']['verticalOffsetFromPredictedEndpoint'] = 0.0
        self.mutate(hidden_vertical)
        def dropped_basis(receipt):
            receipt['records'][0]['plan']['predictedEndpointBasis'] = ''
        self.mutate(dropped_basis)

    def test_a_query_state_equality_claim_that_is_false_is_refused(self):
        self.mutate(lambda receipt: receipt['records'][0]['queryStateEquality'][0].__setitem__(
            'queryStateEqual', False))
        self.mutate(lambda receipt: receipt['records'][0]['observations'][0].__setitem__(
            'queryStateEqual', False))
        self.mutate(lambda receipt: receipt['records'][0]['queryStateEquality'].pop())
        self.mutate(lambda receipt: receipt['records'][0]['queryStateEquality'].__setitem__(
            0, {'site': 'duplicate_actual_final_state', 'queryStateEqual': True}))

    def test_a_reissued_guard_request_is_refused(self):
        def reissue(receipt):
            guard = receipt['records'][0]['observations'][1]
            guard['request'] = copy.deepcopy(receipt['records'][0]['observations'][2]['request'])
            guard['result'] = guard['request']
        self.mutate(reissue)
        def name(receipt):
            receipt['records'][0]['observations'][1]['request']['name'] = hook.DUPLICATE_NAME
            receipt['records'][0]['observations'][1]['result']['name'] = hook.DUPLICATE_NAME
        self.mutate(name)
        def identity(receipt):
            receipt['records'][0]['observations'][1]['request'] = copy.deepcopy(
                receipt['records'][0]['observations'][1]['request'])
            receipt['records'][0]['observations'][1]['result'] = copy.deepcopy(
                receipt['records'][0]['observations'][1]['result'])
        self.mutate(identity)


class QualificationTests(unittest.TestCase):
    """Overclaim guards: the package must not assert what it cannot show."""

    def test_the_receipt_disclaims_neutrality_and_hidden_state(self):
        receipt = run_campaign()
        self.assertIs(receipt['operationalNeutralityProven'], False)
        self.assertIs(receipt['hiddenStateUnaffectedProven'], False)
        self.assertIs(receipt['queryStateEqualityProvesCacheNeutrality'], False)
        self.assertIs(receipt['backendImplementationVerified'], False)
        self.assertIs(receipt['parentInternalCallsTraced'], False)
        self.assertIsNone(receipt['physicalCallCounts'])
        self.assertIs(receipt['positiveAdmission'], False)
        self.assertIs(receipt['nativeStepAdmission'], False)
        self.assertIs(receipt['productionPromotion'], False)
        self.assertEqual(receipt['candidateMapWalks'], 0)
        self.assertEqual(receipt['engineInvocations'], 0)
        self.assertIs(receipt['nativeReadiness']['ready'], False)
        self.assertEqual(receipt['nativeReadiness']['blockingReasons'],
                         list(policy.NATIVE_READINESS_BLOCKERS))

    def test_every_observation_carries_the_non_proof_qualification(self):
        receipt = run_campaign()
        for row in receipt['records']:
            for observation in row['observations']:
                self.assertIn('does not prove caches', observation['qualification'])
            for omission in row['omissions']:
                self.assertIn('Not a result', omission['qualification'])

    def test_no_source_in_this_package_claims_a_verdict_or_neutrality(self):
        # The non-claims must be stated in prose wherever a normal is handled, so
        # the qualification cannot be lost by refactoring one module.
        self.assertIn('never selects\na normal', hook.__doc__)
        self.assertIn('not a selected normal', hook.proposal(
            {'from': {'origin': [0.0, 0.0, 0.0], 'basis': [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]},
             'raised': {'origin': [0.0, 0.1, 0.0], 'basis': [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]},
             'horizontalBudget': [0.0, 0.0, 0.1], 'expectedFinal': [0.0, 0.1, 0.1]},
            {'margin': 0.02}, body_rid=1)['qualification'])
        self.assertIn('does not decide whether support exists', evidence.__doc__)
        self.assertIn('recorded verbatim and preserved as primary', driver.__doc__)
        self.assertIn('carried into', campaign.__doc__)
        # The validator must not apply the guard's own angle predicate, or it would
        # reject the very failure this campaign exists to re-observe.
        self.assertNotIn('floor_angle', inspect.signature(evidence.record).parameters)
        self.assertNotIn('floor_angle', inspect.signature(evidence.receipt).parameters)
        self.assertIn('does not judge it', evidence._observation.__doc__)

    def test_history_is_declared_read_only_and_not_a_substitute(self):
        reference = historical()
        self.assertIn('may legitimately disagree', reference['qualification'])
        for case_id, entry in reference['cases'].items():
            self.assertIn('may legitimately disagree', entry['qualification'])
            self.assertEqual(entry['caseId'], case_id)
            self.assertIn('read-only', entry['qualification'])
        # The comparison is on the guard decision, not on the observed normal:
        # a differing normal is the finding, not a contract violation.
        self.assertIn('not a comparison of\nobserved normals', history.agree.__doc__)

    def test_numeric_budget_matches_the_frozen_guard(self):
        original = importlib.util.spec_from_file_location(
            '_support_query_compare_frozen_evidence',
            HERE.parent / 'walker-calibrated-admission' / 'evidence.py')
        frozen = importlib.util.module_from_spec(original)
        original.loader.exec_module(frozen)
        for points in ([[0.212131947278976, 0.0166666638106108, -0.212131947278976]],
                       [[1.0, 1.0, 1.0]], [[0.0, 0.0, 0.0]],
                       [[1e6, 1e6, 1e6]], [[float('nan'), 0.0, 0.0]]):
            self.assertEqual(hook.numeric_budget(points), frozen.budget(points), points)
        self.assertEqual(hook.numeric_budget([[1e6, 1e6, 1e6]]), -1.0)
        self.assertEqual(hook.numeric_budget([['a', 0.0, 0.0]]), -1.0)

    def test_guard_operand_constants_are_the_reviewed_down32_set(self):
        frozen = hook.frozen_operands({'margin': 0.0199999995529652}, body_rid=274877906947)
        self.assertEqual(frozen['motion'], [0.0, -0.0200999995529652, 0.0])
        self.assertEqual(frozen['margin'], 0.0199999995529652)
        self.assertEqual(frozen['maxCollisions'], 32)
        self.assertIs(frozen['recoveryAsCollision'], True)
        self.assertIs(frozen['collideSeparationRay'], True)
        self.assertEqual(frozen['excludeBodies'], [])
        self.assertEqual(frozen['excludeObjects'], [])
        self.assertIs(frozen['testOnly'], True)
        self.assertEqual(set(frozen), set(hook.CONSTANTS))
        recorded = dict(frozen, name=hook.GUARD_NAME)
        equal, differences = hook.operand_equal(frozen, recorded, keys=hook.GUARD_CONSTANTS)
        self.assertTrue(equal, differences)
        # A legacy log_sweep serialization omits testOnly; that is still test-only.
        legacy = {k: v for k, v in recorded.items() if k != 'testOnly'}
        equal, differences = hook.operand_equal(frozen, legacy, keys=hook.GUARD_CONSTANTS)
        self.assertTrue(equal, differences)

    def test_valid_result_reports_unqualified_contacts_without_a_verdict(self):
        frozen = hook.frozen_operands({'margin': 0.02}, body_rid=1)
        raw = {'name': hook.PRE_UP_NAME, 'margin': 0.02, 'maxCollisions': 32, 'hit': True,
               'validResult': True, 'recoveryAsCollision': True, 'collideSeparationRay': True,
               'travel': [0, 0, 0], 'remainder': [0, -0.02, 0], 'safeFraction': 1.0,
               'unsafeFraction': 1.0, 'excludeBodies': [], 'excludeObjects': [],
               'testOnly': True,
               'contacts': [{'colliderRid': 7, 'colliderShape': 0, 'localShape': 0,
                             'point': [0.0, 0.18, 0.0], 'normal': [0.0, 1.0, 0.0],
                             'velocity': [0.0, 0.0, 0.0], 'depth': 0.02}]}
        ok, problems = hook.valid_result(raw and frozen, raw, target_rid=7, target_shape=0)
        self.assertTrue(ok, problems)
        # The recorded AM .35/-45 fresh guard normal: 36.677 degrees, inside 46.
        steep = copy.deepcopy(raw)
        steep['contacts'][0]['normal'] = [0.422360450029373, 0.802012085914612, -0.422360450029373]
        ok, problems = hook.valid_result(frozen, steep, target_rid=7, target_shape=0,
                                         floor_angle=math.radians(46.0))
        self.assertTrue(ok, problems)
        # The recorded AM .42/-45 fresh guard normal: 47.477 degrees, beyond 46.
        steeper = copy.deepcopy(raw)
        steeper['contacts'][0]['normal'] = [0.521141886711121, 0.675886213779449, -0.521141886711121]
        ok, problems = hook.valid_result(frozen, steeper, target_rid=7, target_shape=0,
                                         floor_angle=math.radians(46.0))
        self.assertFalse(ok)
        self.assertIn('normal_angle', problems)
        for mutation, expected in (({'colliderRid': 9}, 'collider_rid'),
                                   ({'colliderShape': 1}, 'support_shape'),
                                   ({'localShape': 1}, 'support_shape'),
                                   ({'velocity': [0.0, 1.0, 0.0]}, 'collider_velocity'),
                                   ({'depth': -1.0}, 'contact_depth')):
            wrong = copy.deepcopy(raw)
            wrong['contacts'][0].update(mutation)
            ok, problems = hook.valid_result(frozen, wrong, target_rid=7, target_shape=0)
            self.assertFalse(ok, mutation)
            self.assertIn(expected, problems)
        saturated = copy.deepcopy(raw)
        saturated['contacts'] = [saturated['contacts'][0]] * 32
        ok, problems = hook.valid_result(frozen, saturated, target_rid=7, target_shape=0)
        self.assertFalse(ok)
        self.assertIn('contact_count', problems)
        empty = copy.deepcopy(raw)
        empty['contacts'] = []
        ok, problems = hook.valid_result(frozen, empty, target_rid=7, target_shape=0)
        self.assertFalse(ok)
        self.assertIn('contact_count', problems)


class BoundaryTests(unittest.TestCase):
    """AM stays failed, .42/+45 unrun, 60 journeys and 184 static failures untouched."""

    def test_am_still_failed_and_the_unrun_case_is_absent_from_the_case_set(self):
        self.assertEqual(policy.case_ids(), ('reference-035-015-neg45', 'failure-042-018-neg45'))
        self.assertNotIn('.42/.18/+45', [spec_row['id'] for spec_row in policy.canonical()])
        reference = historical()
        self.assertIs(reference['amWholePositiveFailed'], True)
        self.assertEqual(reference['amVerifiedLiftsForFailureCase'], 0)

    def test_no_production_or_admission_promotion_is_expressible(self):
        receipt = run_campaign()
        for key in ('positiveAdmission', 'nativeStepAdmission', 'productionPromotion'):
            self.assertIs(receipt[key], False)
        self.assertEqual(receipt['candidateMapWalks'], 0)
        self.assertEqual(receipt['authority'], 'none-source-only')

    def test_the_package_never_touches_the_frozen_am_or_diagnosis_artifacts(self):
        frozen = (history.DIAGNOSIS_EXPORT, history.DIAGNOSIS_SOURCE_RECEIPT)
        before = {name: seals.sha(ROOT / name) for name in frozen}
        holder = tempfile.TemporaryDirectory(dir='/tmp/opencode', prefix='support-query-compare-')
        self.addCleanup(holder.cleanup)
        parent = Path(holder.name) / 'runs'
        parent.mkdir()
        run_campaign()
        supervisor.refuse(prepare.build('support-query-compare-review-only', parent),
                          checks=supervisor.preflight(
                              prepare.build('support-query-compare-review-only',
                                            Path(holder.name) / 'runs2')))
        after = {name: seals.sha(ROOT / name) for name in frozen}
        self.assertEqual(before, after)

    def test_frozen_references_are_verified_and_drift_is_fatal(self):
        verified = prepare.verify_references(ROOT)
        self.assertEqual(verified['godot/tests/walker_step_up/response_guard.gd'],
                         'ff242f1c352755e3655666440731115911b59dc431f0ec7c37807e8c8ec281b0')
        self.assertIn(prepare.DESIGN_REVIEW, verified)
        self.assertEqual(len(verified), len(prepare.REFERENCES) + 1)
        with self.assertRaises(prepare.PrepareError):
            prepare.verify_references(HERE)

    def test_module_names_are_not_shadowed(self):
        before = {name: sys.modules.get(name) for name in ('policy', 'prepare', 'supervisor', 'evidence')}
        loader.module('driver')
        self.assertEqual(before, {name: sys.modules.get(name) for name in before})
        self.assertTrue(policy.__name__.startswith('_support_query_compare_'))

    def test_deterministic_output_across_repeated_runs(self):
        self.assertEqual(json.dumps(run_campaign(), sort_keys=True),
                         json.dumps(run_campaign(), sort_keys=True))
        self.assertEqual(json.dumps(prepare.contract('support-query-compare-review-only'), sort_keys=True),
                         json.dumps(prepare.contract('support-query-compare-review-only'), sort_keys=True))


if __name__ == '__main__':
    unittest.main()
