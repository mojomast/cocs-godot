"""Bounded two-case Walker support-query comparison -- offline source tests.

These tests exercise the ordering, omission, preservation, sealing and
fail-closed contracts of the source package. They are not native evidence: no
engine is started, no fixture is staged, and every "measurement" here is a
deterministic in-memory answer from :mod:`fixtures`.
"""
import copy
import hashlib
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


def run_campaign(misbehave=None, *, run_rid=None, **kwargs):
    """Run the two authorized cases and compose a receipt.

    ``misbehave`` may be one behaviour applied to both cases or a per-case
    mapping, which is what lets a test produce a campaign that diverges on one
    case and agrees on the other.

    ``run_rid`` is this run's own body RID -- one value for both cases, or a
    per-case mapping. The driver and the fake are always told the *same* value, which
    is what a genuine run does when the engine assigns a fresh RID: the number is new,
    all three requests inside the run carry it, and the AM anchor is untouched.
    """
    reference = historical()
    records = []
    for case_id in policy.CASES:
        behaviour = misbehave.get(case_id) if isinstance(misbehave, dict) else misbehave
        rid = run_rid.get(case_id) if isinstance(run_rid, dict) else run_rid
        bounded = driver.BoundedDriver(case_id,
                                       params=fixtures.params_for(case_id, body_rid=rid),
                                       historical=reference['cases'][case_id])
        records.append(bounded.run_case(
            fixtures.FakeLive(case_id, misbehave=behaviour, run_rid=rid, **kwargs)))
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


class FrozenOperandTests(unittest.TestCase):
    """The frozen down32 operand tuple is recorded, anchored and cross-checked.

    Condition C1 of the independent review: the claim that the validator proves the
    guard's request and the duplicate both carry the frozen constants unchanged was
    false, because ``evidence.record`` validated each observation in isolation and
    the receipt carried no frozen-operand tuple to compare against. These tests
    close that gap on both sides of it:

    * the six re-tunings the reviewer's forger demonstrated are reproduced here as
      negative cases and every one must be refused, with ``recordsSha256``
      **re-derived by the forger** so only a structural predicate can refuse. That is
      what separates a real cross-observation check from a digest-masked test.
    * the driver refuses a re-tuned guard request on the live side of the boundary,
      before any observation is recorded.

    Every forgery here is additionally *preconditioned* (see
    :meth:`per_observation_intact`): each observation is still internally consistent,
    so a refusal is attributable to the cross-observation layer under test rather than
    to the isolation predicates it was meant to make redundant. That precondition is
    the whole difference between a test that reaches the layer it names and one that
    stops one layer earlier.

    The four anchors are carried behaviourally rather than by source shape alone: the
    tests in this class load a copy of the validator with each anchor's *enforcement*
    removed and require the attributable forgery to be admitted, so neutering an
    anchor fails the suite instead of quietly doing nothing.
    """

    #: This run's own body RID per case: a value the engine would assign, deliberately
    #: different from the AM run's (154618822659 / 274877906947) for both cases.
    RUN_RIDS = {policy.CASES[0]: 777000333, policy.CASES[1]: 777000444}

    #: The validator's anchor sites, as exact source pairs. Each is required to occur
    #: exactly once (see :meth:`shadow_evidence`), so deleting an anchor fails these
    #: tests as loudly as neutering it does. The new half of each pair removes the
    #: *enforcement* while leaving the call, the operands and the docstring in place --
    #: the shape-preserving mutation, which a ``co_names`` assertion cannot see.
    ANCHORS = {
        'design_frozen': (
            "    equal, _ = hook.operand_equal(approved, frozen, keys=hook.DESIGN_FROZEN_CONSTANTS)\n"
            "    if not equal:\n        return False\n",
            "    equal, _ = hook.operand_equal(approved, frozen, keys=hook.DESIGN_FROZEN_CONSTANTS)\n"
            "    if not equal:\n        pass  # anchor neutered by the anchor-cargo test\n"),
        'record_binding': (
            "    equal, _ = hook.operand_equal(approved, bound, keys=hook.CONSTANTS)\n"
            "    if not equal:\n        return False\n",
            "    equal, _ = hook.operand_equal(approved, bound, keys=hook.CONSTANTS)\n"
            "    if not equal:\n        pass  # anchor neutered by the anchor-cargo test\n"),
        'run_frozen': (
            "    equal, _ = hook.run_frozen_unchanged(frozen, *requests)\n"
            "    if not equal:\n        return False\n",
            "    equal, _ = hook.run_frozen_unchanged(frozen, *requests)\n"
            "    if not equal:\n        pass  # anchor neutered by the anchor-cargo test\n"),
        'cross_observation': (
            "    equal, _ = hook.operands_unchanged(frozen, *requests)\n    return equal\n",
            "    equal, _ = hook.operands_unchanged(frozen, *requests)\n    return True\n"),
        # The well-formedness gate, inventoried for the same reason and measured as
        # redundant defence-in-depth: see
        # ``test_the_well_formedness_gate_is_redundant_but_still_present``.
        'well_formedness': (
            "    try:\n        frozen = hook.frozen_tuple(row['frozenOperands'])\n"
            "    except (hook.HookError, KeyError, TypeError):\n        return False\n",
            "    frozen = row['frozenOperands']\n"),
        'record_history_binding': (
            "        equal, _ = hook.operand_equal(historical['amFrozenOperands'],\n"
            "                                      history_row.get('amFrozenOperands'), keys=hook.CONSTANTS)\n"
            "        if not equal:\n            return False\n",
            "        equal, _ = hook.operand_equal(historical['amFrozenOperands'],\n"
            "                                      history_row.get('amFrozenOperands'), keys=hook.CONSTANTS)\n"
            "        if not equal:\n            pass  # anchor neutered by the anchor-cargo test\n"),
    }

    def shadow_evidence(self, anchors):
        """Load ``evidence`` from a copy of this package's own modules.

        ``anchors`` is a sequence of :data:`ANCHORS` keys, each of which has its
        *enforcement* removed in the copy -- the call, its operands and its docstring
        all stay, which is the shape-preserving neutering rather than a deletion. The
        copy carries the same ``hook`` and ``policy`` byte for byte, so a forgery
        admitted here can only have been admitted by the code that was removed.

        Three states are distinguished, and each fails differently, which is why a
        neutered anchor cannot pass by being unremarkable:

        * the enforcing form is present once -- it is replaced by the neutered form;
        * the neutered form is *already* present (the shipped source has been neutered
          in place) -- the copy is left as it is, so the behavioural assertion reports
          the failure rather than a text tripwire;
        * neither -- the anchor was deleted, moved or rewritten, and this fails with
          that as the message.

        Nothing is written outside a temporary directory, nothing is launched, and the
        copy is thrown away with it.
        """
        holder = tempfile.TemporaryDirectory(dir='/tmp/opencode',
                                            prefix='support-query-compare-anchor-')
        self.addCleanup(holder.cleanup)
        directory = Path(holder.name)
        for source in ('__init__.py', 'hook.py', 'policy.py', 'evidence.py'):
            (directory / source).write_bytes((HERE / source).read_bytes())
        text = (directory / 'evidence.py').read_text()
        for key in anchors:
            old, new = self.ANCHORS[key]
            if text.count(old) == 1:
                text = text.replace(old, new)
            else:
                self.assertEqual(text.count(new), 1,
                                 'anchor %r is neither enforced nor already neutered: '
                                 'it was deleted, moved or rewritten' % (key,))
        (directory / 'evidence.py').write_text(text)
        package = '_support_query_compare_anchor_' + \
            hashlib.sha256(str(directory).encode()).hexdigest()[:16]
        module_spec = importlib.util.spec_from_file_location(
            package, directory / '__init__.py', submodule_search_locations=[str(directory)])
        module = importlib.util.module_from_spec(module_spec)
        sys.modules[package] = module
        module_spec.loader.exec_module(module)
        return importlib.import_module(package + '.evidence')

    def admits(self, shadow, receipt):
        """Whether a (possibly mutated) copy of the validator admits this receipt."""
        return shadow.receipt(receipt, source_hash=SOURCE_HASH, grant_hash=GRANT_HASH,
                              engine_hash=policy.ENGINE, historical=historical())

    def forge(self, change, base=None):
        """Edit a receipt and re-derive its digest, as an attacker would.

        ``ReceiptValidatorTests.mutate`` leaves the digest stale, so a refusal it
        observes may be the digest rather than the predicate under test. Re-deriving
        it here is what forces the cross-observation predicates to act on their own.
        """
        receipt = copy.deepcopy(base if base is not None else run_campaign())
        change(receipt)
        # Re-derived by the attacker's own code, so the digest can never be what
        # refuses: only a structural predicate can.
        receipt['recordsSha256'] = evidence.records_digest(receipt['records'])
        return receipt

    def refuses(self, receipt):
        reference = historical()
        self.assertFalse(evidence.receipt(receipt, source_hash=SOURCE_HASH,
                                          grant_hash=GRANT_HASH, engine_hash=policy.ENGINE,
                                          historical=reference))

    def retune(self, request, **changes):
        """Re-tune a recorded request's operands, keeping motion and margin consistent.

        A self-consistent re-tune is the hard case: every per-observation predicate
        still passes, because ``motion[1] == -(margin + LIMIT)`` holds and the
        result still mirrors its own request. Only a cross-observation check
        against the frozen tuple can catch it.
        """
        if 'margin' in changes:
            request['margin'] = changes['margin']
            request['motion'] = [0.0, -(changes['margin'] + hook.LIMIT), 0.0]
        if 'motion' in changes:
            request['motion'] = changes['motion']
        if 'bodyRid' in changes:
            request['bodyRid'] = changes['bodyRid']

    def retune_observation(self, observation, **changes):
        """Re-tune one observation's operands *and its own result*.

        Observation 3 (the guard) has ``request is result``; observations 1 and 4 hold
        two distinct objects. Editing only the request leaves those two disagreeing
        with their own result, and they are then refused by the per-observation
        isolation predicate before the cross-observation layer is ever consulted -- so a
        test named after that layer would prove nothing about it while staying green.
        Mirroring the edit into the result is what makes the forgery the hard one: every
        observation is internally consistent, and only a cross-observation check can
        refuse it. ``per_observation_intact`` asserts that rather than assuming it.
        """
        self.retune(observation['request'], **changes)
        self.retune(observation['result'], **changes)

    def per_observation_intact(self, row):
        """True when every isolation predicate still passes for this case record.

        The precondition a cross-observation test owes its refusal: if an isolation
        predicate would refuse the forged record, the layer under test is never
        reached, and a test that reports a refusal is measuring the wrong predicate.
        """
        try:
            if not evidence._plan(row):
                return False
            hook.frozen_tuple(row['frozenOperands'])
            for observation in row['observations']:
                if not evidence._observation(observation, observation['ordinal'],
                                             observation['site'], observation['issuedBy']):
                    return False
        except (hook.HookError, KeyError, TypeError, IndexError):
            return False
        return True

    def forgery_reaching_only_the_design_frozen_anchor(self):
        """A consistent re-tune of every design-frozen operand in the first case.

        All three observations are re-tuned together *and each into its own result*,
        the recorded tuple follows, and the receipt's per-case table is updated to match
        the record. Every isolation predicate therefore still passes, and the three
        requests agree with the tuple and with each other, so the only thing left that
        can refuse this is the anchor on the SHA256-pinned AM guard request. Both
        preconditions are asserted here, not assumed.
        """
        def change(receipt):
            row = receipt['records'][0]
            for observation in row['observations']:
                self.retune_observation(observation, margin=0.0150)
            self.retune(row['frozenOperands'], margin=0.0150)
            receipt['frozenOperands'][row['caseId']] = copy.deepcopy(row['frozenOperands'])
        forged = self.forge(change)
        row = forged['records'][0]
        self.assertTrue(self.per_observation_intact(row))
        self.assertEqual(hook.operands_unchanged(
            row['frozenOperands'], *[o['request'] for o in row['observations']]), (True, []))
        self.assertFalse(hook.operand_equal(
            historical()['cases'][row['caseId']]['amFrozenOperands'], row['frozenOperands'],
            keys=hook.DESIGN_FROZEN_CONSTANTS)[0])
        return forged

    def forgery_reaching_only_the_binding_anchors(self):
        """A re-tune of the record's own AM binding, and of nothing else.

        The record claims a different approved tuple from the one the validator was
        handed, while the recorded tuple, all three requests and the receipt's per-case
        table stay exactly as the run left them. The design-frozen anchor still passes
        and the cross-observation layer still passes -- only the two binding anchors
        can refuse, which is asserted below.
        """
        def change(receipt):
            self.retune(receipt['records'][0]['history']['amFrozenOperands'], margin=0.0150)
        forged = self.forge(change)
        row = forged['records'][0]
        approved = historical()['cases'][row['caseId']]['amFrozenOperands']
        self.assertTrue(self.per_observation_intact(row))
        self.assertTrue(hook.operand_equal(approved, row['frozenOperands'],
                                           keys=hook.DESIGN_FROZEN_CONSTANTS)[0])
        self.assertEqual(hook.operands_unchanged(
            row['frozenOperands'], *[o['request'] for o in row['observations']]), (True, []))
        self.assertFalse(hook.operand_equal(approved, row['history']['amFrozenOperands'])[0])
        return forged

    def forgery_reaching_only_the_run_frozen_rule(self):
        """One observation's body RID disagreeing with the rest of this run's.

        Built from a run whose RID is not the AM run's, so the AM anchor cannot be what
        refuses it: only the run-frozen rule and the whole-tuple comparison can, and
        both are dropped in turn.
        """
        base = run_campaign(run_rid=self.RUN_RIDS)
        rid = self.RUN_RIDS[policy.CASES[0]]

        def change(receipt):
            duplicate = receipt['records'][0]['observations'][2]
            duplicate['request']['bodyRid'] = rid + 1
            duplicate['result']['bodyRid'] = rid + 1
        forged = self.forge(change, base=base)
        row = forged['records'][0]
        approved = historical()['cases'][row['caseId']]['amFrozenOperands']
        self.assertTrue(self.per_observation_intact(row))
        self.assertTrue(hook.operand_equal(approved, row['frozenOperands'],
                                           keys=hook.DESIGN_FROZEN_CONSTANTS)[0])
        self.assertEqual(row['frozenOperands']['bodyRid'], rid)
        self.assertEqual(hook.run_frozen_unchanged(
            row['frozenOperands'], *[o['request'] for o in row['observations']]),
            (False, ['request2:bodyRid', '0~2:bodyRid', '1~2:bodyRid']))
        return forged

    def test_the_unaltered_receipt_carries_one_frozen_tuple_shared_by_all_three_requests(self):
        receipt = run_campaign()
        reference = historical()
        self.assertEqual(set(receipt['frozenOperands']), set(policy.CASES))
        for row in receipt['records']:
            frozen = row['frozenOperands']
            # The tuple is well formed, complete and exactly the operand key set.
            self.assertEqual(set(frozen), set(hook.CONSTANTS))
            self.assertEqual(hook.frozen_tuple(frozen), frozen)
            # It is the AM guard's own recorded tuple, not a local retyping.
            approved = reference['cases'][row['caseId']]['amFrozenOperands']
            self.assertTrue(hook.operand_equal(approved, frozen)[0])
            self.assertEqual(row['history']['amFrozenOperands'], approved)
            self.assertEqual(receipt['frozenOperands'][row['caseId']], frozen)
            # All three executed requests carry exactly it, and are proven equal to
            # one another pairwise as well as through the tuple anchor.
            equal, differences = hook.operands_unchanged(
                frozen, *[o['request'] for o in row['observations']])
            self.assertTrue(equal, differences)
            # The recorded margin is the reviewed float32-sourced one, and motion
            # is its derivation rather than a re-derived or rounded value.
            self.assertEqual(frozen['margin'], 0.0199999995529652)
            self.assertEqual(frozen['motion'], [0.0, -0.0200999995529652, 0.0])
            self.assertEqual(frozen['maxCollisions'], 32)
            self.assertGreater(frozen['bodyRid'], 0)

    def test_the_reviewers_six_constant_retunings_are_all_refused(self):
        # Exactly the six forgeries the independent reviewer's model accepted, with
        # the digest re-derived each time. Five of the six are re-tuned into each
        # observation's own result as well, so they reach the cross-observation layer
        # instead of being refused one layer earlier by the isolation predicate. The
        # sixth -- a guard motion that disagrees with its own margin -- is *not*
        # self-consistent and cannot be made so: it is refused by the derivation
        # predicate, which is the stronger statement of the two.
        def guard_margin(receipt):
            self.retune_observation(receipt['records'][0]['observations'][1], margin=0.0150)
        self.refuses(self.forge(guard_margin))
        def guard_motion(receipt):
            self.retune(receipt['records'][0]['observations'][1]['request'],
                        motion=[0.0, -0.0400, 0.0])
        self.refuses(self.forge(guard_motion))
        def guard_rid(receipt):
            self.retune_observation(receipt['records'][0]['observations'][1], bodyRid=999000111)
        self.refuses(self.forge(guard_rid))
        def duplicate_margin(receipt):
            self.retune_observation(receipt['records'][0]['observations'][2], margin=0.0150)
        self.refuses(self.forge(duplicate_margin))
        def duplicate_rid(receipt):
            self.retune_observation(receipt['records'][0]['observations'][2], bodyRid=999000111)
        self.refuses(self.forge(duplicate_rid))
        def pre_up_rid(receipt):
            self.retune_observation(receipt['records'][0]['observations'][0], bodyRid=999000111)
        self.refuses(self.forge(pre_up_rid))
        # The five self-consistent re-tunings above are all internally intact, so each
        # of them really is refused by the cross-observation layer and not by an
        # isolation predicate it never reached.
        for change in (guard_margin, guard_rid, duplicate_margin, duplicate_rid, pre_up_rid):
            self.assertTrue(self.per_observation_intact(self.forge(change)['records'][0]))
        self.assertFalse(self.per_observation_intact(self.forge(guard_motion)['records'][0]))

    def test_retuning_all_three_requests_together_is_still_refused(self):
        # The stronger forgery: re-tune the pre-UP, guard and duplicate requests
        # *consistently*, so the three agree with each other and with each own
        # result. The recorded tuple is re-tuned to match, and the receipt's
        # per-case table is updated too. Only the SHA256-pinned AM anchor can catch
        # this, which is exactly why the tuple is anchored rather than merely
        # recorded.
        def consistent(receipt):
            row = receipt['records'][0]
            for observation in row['observations']:
                self.retune_observation(observation, margin=0.0150)
            self.retune(row['frozenOperands'], margin=0.0150)
            receipt['frozenOperands'][row['caseId']] = copy.deepcopy(row['frozenOperands'])
        receipt = self.forge(consistent)
        # Preconditioned, and it matters: each observation's edit is mirrored into its
        # own result, so the isolation predicates still pass and the cross-observation
        # layer is genuinely reached. Editing only the requests would leave observations
        # 1 and 4 disagreeing with their own results and this test would pass while
        # proving nothing about the anchor it names.
        row = receipt['records'][0]
        self.assertTrue(self.per_observation_intact(row))
        self.assertEqual(hook.operands_unchanged(
            row['frozenOperands'], *[o['request'] for o in row['observations']]), (True, []))
        self.refuses(receipt)
        # And even re-tuning the recorded AM binding cannot help: the validator is
        # handed the real one, and the receipt's copy must equal it.
        receipt = self.forge(consistent)
        self.retune(receipt['records'][0]['history']['amFrozenOperands'], margin=0.0150)
        receipt['recordsSha256'] = evidence.records_digest(receipt['records'])
        self.refuses(receipt)

    # -- the run-frozen body RID: this run's own value, never the AM run's --------

    def test_a_genuine_fresh_per_run_body_rid_is_accepted_by_driver_and_validator(self):
        # The AM run's body RID is a fact about the AM run. A RID is assigned by the
        # engine for one run, so the next real run will not reproduce it: the driver
        # deliberately does not compare it (``driver.run_case``), and the validator must
        # not either, or the first genuine run's receipt would be refused by a check the
        # driver already declined to make. Both RIDs here differ from the AM values, for
        # both cases.
        reference = historical()
        receipt = run_campaign(run_rid=self.RUN_RIDS)
        for row in receipt['records']:
            case_id = row['caseId']
            approved = reference['cases'][case_id]['amFrozenOperands']
            rid = self.RUN_RIDS[case_id]
            # The driver ran the case rather than refusing it, so the whole bounded
            # sequence happened with a body RID that is not the AM run's.
            self.assertEqual(row['status'], 'stopped_after_duplicate_observation')
            self.assertEqual(row['frozenOperands']['bodyRid'], rid)
            self.assertNotEqual(rid, approved['bodyRid'])
            # Every executed request in this run carries this run's RID, results
            # included: one value, used consistently, which is what a run is.
            for observation in row['observations']:
                self.assertEqual(observation['request']['bodyRid'], rid)
                self.assertEqual(observation['result']['bodyRid'], rid)
            self.assertEqual(hook.run_frozen_unchanged(
                row['frozenOperands'], *[o['request'] for o in row['observations']]), (True, []))
            # The AM binding still carries the AM run's own tuple, and the design-frozen
            # constants are still the pinned ones: the run's RID is not the anchor, and
            # the anchor is unchanged by it.
            self.assertEqual(row['history']['amFrozenOperands'], approved)
            self.assertEqual(row['history']['amFrozenOperands']['bodyRid'], approved['bodyRid'])
            self.assertTrue(hook.operand_equal(approved, row['frozenOperands'],
                                               keys=hook.DESIGN_FROZEN_CONSTANTS)[0])
        # ``run_campaign`` composes through ``campaign.assert_receipt``, so returning at
        # all *is* the whole-receipt acceptance: nothing above was taken on trust.
        self.assertEqual([row['caseId'] for row in receipt['records']], list(policy.CASES))

    def test_a_body_rid_that_disagrees_across_the_observations_is_refused(self):
        # Same run, two observations' RIDs edited. Each edit is mirrored into that
        # observation's own result, so the isolation predicates still pass and this is
        # refused by the run-frozen rule rather than by a schema check.
        base = run_campaign(run_rid=self.RUN_RIDS)
        rid = self.RUN_RIDS[policy.CASES[0]]

        def change(receipt):
            for index, drift in ((0, 7), (2, 11)):
                observation = receipt['records'][0]['observations'][index]
                observation['request']['bodyRid'] = rid + drift
                observation['result']['bodyRid'] = rid + drift
        receipt = self.forge(change, base=base)
        row = receipt['records'][0]
        self.assertTrue(self.per_observation_intact(row))
        self.refuses(receipt)
        # The recorded tuple and the untouched observation still agree; the two drifted
        # ones are named, against the tuple and pairwise. The AM anchor plays no part in
        # the refusal, because the design-frozen constants never moved.
        approved = historical()['cases'][row['caseId']]['amFrozenOperands']
        self.assertTrue(hook.operand_equal(approved, row['frozenOperands'],
                                           keys=hook.DESIGN_FROZEN_CONSTANTS)[0])
        equal, differences = hook.run_frozen_unchanged(
            row['frozenOperands'], *[o['request'] for o in row['observations']])
        self.assertFalse(equal)
        self.assertEqual(differences, ['request0:bodyRid', 'request2:bodyRid',
                                       '0~1:bodyRid', '0~2:bodyRid', '1~2:bodyRid'])
        # And the whole-tuple comparison names the same two, so either layer refuses.
        equal, differences = hook.operands_unchanged(
            row['frozenOperands'], *[o['request'] for o in row['observations']])
        self.assertFalse(equal)
        self.assertIn('request0:bodyRid', differences)
        self.assertIn('request2:bodyRid', differences)

    def test_a_recorded_body_rid_that_differs_from_the_runs_own_requests_is_refused(self):
        # The record's own binding of the run-frozen RID disagrees with the three
        # requests that run actually issued. The receipt's per-case table is updated to
        # match the record, so the table-vs-record comparison cannot be what refuses.
        base = run_campaign(run_rid=self.RUN_RIDS)
        rid = self.RUN_RIDS[policy.CASES[0]]

        def change(receipt):
            row = receipt['records'][0]
            row['frozenOperands']['bodyRid'] = rid + 1
            receipt['frozenOperands'][row['caseId']] = copy.deepcopy(row['frozenOperands'])
        receipt = self.forge(change, base=base)
        row = receipt['records'][0]
        self.assertTrue(self.per_observation_intact(row))
        self.refuses(receipt)
        approved = historical()['cases'][row['caseId']]['amFrozenOperands']
        # The design-frozen anchor and the AM binding are both untouched and still pass;
        # the only thing that moved is this run's own RID, and that is what is refused.
        self.assertTrue(hook.operand_equal(approved, row['frozenOperands'],
                                           keys=hook.DESIGN_FROZEN_CONSTANTS)[0])
        self.assertTrue(hook.operand_equal(approved, row['history']['amFrozenOperands'])[0])
        self.assertEqual(row['frozenOperands']['bodyRid'], rid + 1)
        for observation in row['observations']:
            self.assertEqual(observation['request']['bodyRid'], rid)
        # Each request is named as differing from the recorded binding, and the pairwise
        # half correctly stays silent: the three observations agree with *each other*,
        # which is the whole point of the forgery.
        self.assertEqual(hook.run_frozen_unchanged(
            row['frozenOperands'], *[o['request'] for o in row['observations']]),
            (False, ['request0:bodyRid', 'request1:bodyRid', 'request2:bodyRid']))

    def test_the_run_frozen_rule_is_empty_safe_and_reports_individually(self):
        # "All the requests agree" is not a statement about no requests, so the rule
        # refuses an empty observation set rather than passing vacuously -- and it
        # refuses a tuple that is not a frozen-operand tuple at all, like its
        # whole-tuple sibling.
        frozen = hook.frozen_operands({'margin': 0.02}, body_rid=777000333)
        self.assertEqual(hook.run_frozen_unchanged(frozen), (False, ['no_executed_request']))
        self.assertEqual(hook.run_frozen_unchanged(None, frozen), (False, ['frozen_operand_tuple']))
        self.assertEqual(hook.run_frozen_unchanged({}, frozen), (False, ['frozen_operand_tuple']))
        # Only the run-frozen keys are compared: a design-frozen drift is *not* this
        # rule's business, which is exactly why the design-frozen anchor exists.
        drifted = copy.deepcopy(frozen)
        self.retune(drifted, margin=0.03)
        self.assertEqual(hook.run_frozen_unchanged(frozen, drifted), (True, []))
        other = dict(frozen, bodyRid=777000444)
        self.assertEqual(hook.run_frozen_unchanged(frozen, frozen, other),
                         (False, ['request1:bodyRid', '0~1:bodyRid']))
        self.assertEqual(hook.run_frozen_unchanged(frozen, other, frozen),
                         (False, ['request0:bodyRid', '0~1:bodyRid']))
        # A malformed request is refused, and the key is named as missing rather than
        # silently defaulted.
        self.assertEqual(hook.run_frozen_unchanged(frozen, {'name': 'x'}),
                         (False, ['request0:missing:bodyRid']))

    # -- the four anchors, carried behaviourally ---------------------------------
    #
    # Deleting an anchor used to be caught only by a ``co_names`` introspection
    # assertion, and *neutering* it -- keeping the call, dropping ``if not equal:
    # return False`` -- was caught by nothing at all: the suite stayed green while a
    # consistent re-tune of every design-frozen operand was admitted. Each test below
    # therefore loads a copy of the validator with one anchor's enforcement removed and
    # requires the forgery that anchor is responsible for to be admitted by the copy.
    # Neuter any anchor and the matching test fails; delete it and the uniqueness
    # assertion inside ``shadow_evidence`` fails.

    def test_every_anchor_site_exists_exactly_once_in_the_validator(self):
        # The inventory these tests draw on, checked in the shipped source. If an anchor
        # is deleted, moved, duplicated or rewritten, this fails here rather than leaving
        # the anchor tests below unable to find their site.
        source = (HERE / 'evidence.py').read_text()
        for key, (old, _) in sorted(self.ANCHORS.items()):
            with self.subTest(anchor=key):
                self.assertEqual(source.count(old), 1)
        self.assertEqual(len(self.ANCHORS), 6)

    def test_the_well_formedness_gate_is_redundant_but_still_present(self):
        # Measured, not assumed: every malformed tuple the gate rejects is also rejected
        # by one of the four anchors, so removing the gate admits no forgery of its own.
        # That makes it redundant defence-in-depth -- the same category as the review's
        # two recorded survivors -- and it is kept anyway, because it is the layer that
        # refuses for the *right stated reason* ("the recorded tuple is not well
        # formed") instead of letting an anchor report a confusing key difference.
        malformed = {
            'maxCollisions': 16, 'testOnly': False, 'excludeBodies': [1],
            'bodyRid': 0, 'bodyRidFloat': 1.5, 'extra': 1,
            'motion': [0.0, -0.0400, 0.0],
        }
        for key, value in malformed.items():
            field = 'bodyRid' if key.startswith('bodyRid') else key

            def change(receipt, field=field, value=value):
                tuple_ = receipt['records'][0]['frozenOperands']
                tuple_[field] = value
                receipt['frozenOperands'][receipt['records'][0]['caseId']] = \
                    copy.deepcopy(tuple_)
            forged = self.forge(change)
            with self.subTest(field=field):
                # The shipped gate refuses it, naming the malformation...
                with self.assertRaises(hook.HookError):
                    hook.frozen_tuple(forged['records'][0]['frozenOperands'])
                self.refuses(forged)
                # ... and so does the validator with the gate removed, which is what
                # makes this layer redundant rather than load-bearing.
                self.assertFalse(self.admits(self.shadow_evidence(['well_formedness']), forged))
        # A tuple that is not a mapping at all is the one shape only the gate's
        # exception path refuses.
        for value in ({}, None, 'frozen', []):
            with self.subTest(value=type(value).__name__):
                forged = self.forge(
                    lambda r, v=value: r['records'][0].__setitem__('frozenOperands', v))
                with self.assertRaises(hook.HookError):
                    hook.frozen_tuple(value)
                self.refuses(forged)
                self.assertFalse(self.admits(self.shadow_evidence(['well_formedness']), forged))

    def test_the_design_frozen_anchor_alone_refuses_a_consistent_retune(self):
        # The design-frozen anchor is the only thing that can refuse this forgery: the
        # per-observation predicates pass (asserted in the forgery's own construction),
        # the run-frozen rule passes, and the three requests agree with the re-tuned
        # tuple and with each other. So the shipped validator refusing it proves the
        # anchor fired, and the neutered copy admitting it proves the test is not
        # passing on some other predicate's account.
        forged = self.forgery_reaching_only_the_design_frozen_anchor()
        self.refuses(forged)
        neutered = self.shadow_evidence(['design_frozen'])
        self.assertTrue(self.admits(neutered, forged),
                        'the design-frozen anchor is not load-bearing: a consistent '
                        're-tune of every design-frozen operand was admitted with it '
                        'neutered, so the refusal above came from something else')

    def test_the_record_binding_anchors_are_jointly_necessary(self):
        # Two anchors make the same comparison at two layers: the record's own AM binding
        # must be the tuple the validator was handed (:func:`evidence._frozen_operands`)
        # and must be the approved table entry for this case (:func:`evidence.record`).
        # Neither can be dropped on its own -- each is caught by the other, which is the
        # redundancy the review measured -- but with both gone the forgery is admitted,
        # so neither is redundant in the pair.
        forged = self.forgery_reaching_only_the_binding_anchors()
        self.refuses(forged)
        for alone in ('record_binding', 'record_history_binding'):
            with self.subTest(anchor=alone):
                self.assertFalse(self.admits(self.shadow_evidence([alone]), forged),
                                 'this anchor was reported as load-bearing on its own, '
                                 'but its sibling refused the forgery without it')
        self.assertTrue(
            self.admits(self.shadow_evidence(['record_binding', 'record_history_binding']),
                        forged),
            'both record-binding anchors are dead weight: a re-tuned AM binding was '
            'admitted with both removed')

    def test_the_run_frozen_anchor_is_jointly_necessary_with_the_whole_tuple_comparison(self):
        # The run-frozen rule and the whole-tuple comparison are both about agreement
        # across the three requests, and they overlap by construction: a RID that
        # differs from the recorded tuple is also a RID that differs from the frozen
        # tuple. So neither refusal can be attributed to one of them from the outside;
        # what can be established is that dropping both admits the forgery, and that
        # dropping one alone does not.
        forged = self.forgery_reaching_only_the_run_frozen_rule()
        self.refuses(forged)
        for alone in ('run_frozen', 'cross_observation'):
            with self.subTest(anchor=alone):
                self.assertFalse(self.admits(self.shadow_evidence([alone]), forged),
                                 'this anchor was reported as load-bearing on its own, '
                                 'but its sibling refused the forgery without it')
        self.assertTrue(
            self.admits(self.shadow_evidence(['run_frozen', 'cross_observation']), forged),
            'the run-frozen rule and the whole-tuple comparison are jointly dead: a body '
            'RID that disagreed across the observations was admitted with both removed')
        # The same pairing, from the other end: the design-frozen anchor alone is what
        # refuses a *consistent* re-tune, so it cannot be the cross-observation layer
        # quietly carrying that forgery.
        consistent = self.forgery_reaching_only_the_design_frozen_anchor()
        self.assertFalse(self.admits(self.shadow_evidence(['cross_observation']), consistent))
        self.assertTrue(self.admits(self.shadow_evidence(['design_frozen']), consistent))

    def test_other_frozen_constants_are_covered_too_not_just_margin_and_rid(self):
        for change, expected in ((lambda r: r['records'][0]['observations'][1]['request']
                                  .__setitem__('maxCollisions', 16), 'maxCollisions'),
                                 (lambda r: r['records'][0]['observations'][1]['request']
                                  .__setitem__('recoveryAsCollision', False),
                                  'recoveryAsCollision'),
                                 (lambda r: r['records'][0]['observations'][1]['request']
                                  .__setitem__('collideSeparationRay', False),
                                  'collideSeparationRay'),
                                 (lambda r: r['records'][0]['observations'][1]['request']
                                  .__setitem__('excludeBodies', [1]), 'excludeBodies'),
                                 (lambda r: r['records'][0]['observations'][1]['request']
                                  .__setitem__('testOnly', False), 'testOnly')):
            self.refuses(self.forge(change))
            # The named constant is what the check reports, so the refusal is the
            # cross-observation predicate and not an incidental schema failure.
            row = self.forge(change)['records'][0]
            frozen = row['frozenOperands']
            differences = hook.operands_unchanged(
                frozen, *[o['request'] for o in row['observations']])[1]
            self.assertTrue(any(expected in entry for entry in differences), differences)

    def test_a_re_tuned_or_malformed_frozen_tuple_is_refused(self):
        for change in (lambda r: r['records'][0].__setitem__('frozenOperands', {}),
                       lambda r: r['records'][0]['frozenOperands'].__setitem__('bodyRid', -1),
                       lambda r: r['records'][0]['frozenOperands'].__setitem__('bodyRid', 1.5),
                       lambda r: r['records'][0]['frozenOperands'].__setitem__('margin', -0.02),
                       lambda r: r['records'][0]['frozenOperands'].__setitem__(
                           'motion', [0.0, -0.0400, 0.0]),
                       lambda r: r['records'][0]['frozenOperands'].pop('bodyRid'),
                       lambda r: r['records'][0]['frozenOperands'].__setitem__(
                           'maxCollisions', 16),
                       lambda r: r['records'][0]['frozenOperands'].__setitem__(
                           'excludeObjects', [3])):
            self.refuses(self.forge(change))
        # Dropping the receipt-level table, or making it disagree with a record, is
        # refused as well: the table is carried, never independently invented.
        self.refuses(self.forge(lambda r: r.__setitem__('frozenOperands', {})))
        self.refuses(self.forge(lambda r: r.__setitem__(
            'frozenOperands', {case: dict(row['frozenOperands'], bodyRid=999000111)
                               for case, row in zip(policy.CASES, r['records'])})))
        self.refuses(self.forge(lambda r: r.pop('frozenOperands')))
        self.refuses(self.forge(lambda r: r.__setitem__('frozenOperands', [])))
        self.refuses(self.forge(lambda r: r['records'][0].pop('frozenOperands')))
        self.refuses(self.forge(lambda r: r['records'][0].pop('history')
                                ['amFrozenOperands']))

    def test_a_case_cannot_borrow_the_other_cases_frozen_operands(self):
        receipt = self.forge(lambda r: r['records'][0].__setitem__(
            'frozenOperands', copy.deepcopy(r['records'][1]['frozenOperands'])))
        self.refuses(receipt)
        # Swapping the whole history entry, AM frame and all, is still refused.
        receipt = self.forge(lambda r: r['records'][0].__setitem__(
            'history', copy.deepcopy(r['records'][1]['history'])))
        receipt['recordsSha256'] = evidence.records_digest(receipt['records'])
        self.refuses(receipt)

    def test_the_driver_refuses_a_re_tuned_guard_request_on_the_live_side(self):
        # The same six-class forgery, but delivered by the engine instead of forged
        # into the receipt afterwards. The driver must refuse it before the duplicate
        # is ever issued, so no record exists that the validator would ever accept.
        reference = historical()
        case_id = policy.CASES[1]
        for behaviour in ('guard_request_margin_retuned', 'guard_request_body_rid_retuned'):
            live = fixtures.FakeLive(case_id, misbehave=behaviour)
            with self.assertRaises(driver.BoundedContractError):
                driver.BoundedDriver(case_id, params=params(case_id),
                                     historical=reference['cases'][case_id]).run_case(live)
            # The re-tune is caught on the guard's own request, before the duplicate
            # is issued, so no record exists that the validator could ever accept.
            self.assertEqual(live.orders(), ['test_motion:' + hook.PRE_UP_NAME,
                                             'candidate_response'])
            self.assertEqual(live.candidate_calls, 1)

    def test_the_driver_refuses_a_live_plan_whose_frozen_operands_were_re_tuned(self):
        # The same anchor on the driver side: a margin that is not the recorded one
        # is a different case, not a fresh measurement of this one, and is refused
        # before anything executes.
        reference = historical()
        case_id = policy.CASES[0]
        approved_rid = reference['cases'][case_id]['amFrozenOperands']['bodyRid']
        # A re-tuned margin or motion is caught against the recorded AM tuple before
        # anything executes at all -- not one observation is issued.
        for retuned in ({'margin': 0.015, 'bodyRid': approved_rid},
                        {'margin': 0.02, 'bodyRid': approved_rid},
                        {'margin': 0.015, 'bodyRid': 999000111}):
            live = fixtures.FakeLive(case_id)
            with self.assertRaises(driver.BoundedContractError):
                driver.BoundedDriver(case_id, params=dict(retuned),
                                     historical=reference['cases'][case_id]).run_case(live)
            self.assertEqual(live.orders(), [])
        # ``bodyRid`` is deliberately not design-frozen (it is assigned per run), so
        # a re-tuned RID is caught by the guard-request comparison instead -- still
        # before the duplicate is issued, and still leaving no record behind.
        live = fixtures.FakeLive(case_id)
        with self.assertRaises(driver.BoundedContractError):
            driver.BoundedDriver(case_id, params={'margin': 0.0199999995529652,
                                                  'bodyRid': 999000111},
                                 historical=reference['cases'][case_id]).run_case(live)
        self.assertEqual(live.orders(), ['test_motion:' + hook.PRE_UP_NAME,
                                         'candidate_response'])

    def test_the_frozen_tuple_is_recorded_in_the_prepared_source_record(self):
        # The tuple has to exist before execution too, not only in the receipt: the
        # prepared record is what a future native staging would bind its driver to.
        contract = prepare.contract('support-query-compare-review-only')
        table = contract['proposal']['frozenOperandsByCase']
        self.assertEqual(set(table), set(policy.CASES))
        reference = historical()
        for case_id, operands in table.items():
            self.assertEqual(operands, reference['cases'][case_id]['amFrozenOperands'])
            self.assertEqual(set(operands), set(hook.CONSTANTS))
        # The shape placeholder still records the operand *set*, and the real
        # per-case RIDs are no longer a placeholder of 1.
        self.assertEqual(contract['proposal']['frozenConstants']['bodyRid'], 1)
        self.assertNotEqual(table[policy.CASES[0]]['bodyRid'], 1)
        self.assertNotEqual(table[policy.CASES[1]]['bodyRid'], 1)
        self.assertEqual(table[policy.CASES[0]]['bodyRid'], 154618822659)
        self.assertEqual(table[policy.CASES[1]]['bodyRid'], 274877906947)

    def test_the_predicates_are_reported_individually_and_never_repair(self):
        frozen = hook.frozen_operands({'margin': 0.02}, body_rid=7)
        good = hook.request_from('n', {'origin': [0.0, 0.0, 0.0],
                                       'basis': [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0],
                                                 [0.0, 0.0, 1.0]]}, frozen)
        frozen_0 = hook.frozen_operands({'margin': 0.02}, body_rid=7)
        self.assertEqual(hook.operands_unchanged(frozen_0, good), (True, []))
        self.assertEqual(hook.operands_unchanged(frozen_0, good, good, good), (True, []))
        # A malformed tuple is refused, never defaulted or repaired.
        for bad in ({}, dict(frozen, bodyRid=0), dict(frozen, bodyRid=1.5),
                    dict(frozen, margin=-0.02), dict(frozen, motion=[0.0, -0.04, 0.0]),
                    dict(frozen, maxCollisions=16), dict(frozen, testOnly=False),
                    dict(frozen, excludeBodies=[1]), None, 'frozen'):
            with self.assertRaises(hook.HookError):
                hook.frozen_tuple(bad)
        with self.assertRaises(hook.HookError):
            hook.frozen_tuple(dict(frozen, extra=1))
        # A non-mapping frozen tuple is refused by the comparison too.
        self.assertEqual(hook.operands_unchanged(None, good)[0], False)
        self.assertEqual(hook.operands_unchanged(None, good)[1], ['frozen_operand_tuple'])
        self.assertEqual(hook.operands_unchanged({}, good)[0], False)
        # Differences name the request index and the key.
        other = hook.request_from('n', {'origin': [0.0, 0.0, 0.0],
                                        'basis': [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0],
                                                  [0.0, 0.0, 1.0]]},
                                  hook.frozen_operands({'margin': 0.03}, body_rid=9))
        equal, differences = hook.operands_unchanged(frozen, good, other)
        self.assertFalse(equal)
        self.assertIn('request1:motion', differences)
        self.assertIn('request1:margin', differences)
        self.assertIn('request1:bodyRid', differences)
        # The pairwise half reports the disagreement as well, so a refusal names both
        # "differs from the frozen set" and "differs from another observation".
        equal, differences = hook.operands_unchanged(frozen, good, other)
        self.assertFalse(equal)
        self.assertIn('0~1:motion', differences)
        self.assertIn('0~1:margin', differences)
        self.assertIn('0~1:bodyRid', differences)
        # The pairwise half is redundant with the tuple half by construction (two
        # requests that both equal the tuple necessarily equal each other). It is
        # kept as defense in depth, so the redundancy is asserted rather than left
        # implicit: if a future change ever makes the tuple comparison weaker, this
        # test fails instead of the guarantee quietly narrowing.
        for triple in ((good, good, good), (good, good), (good,)):
            with_tuple, with_differences = hook.operands_unchanged(frozen_0, *triple)
            self.assertEqual(with_tuple, True, with_differences)
            self.assertEqual(with_differences, [])
        # Every pairwise disagreement is accompanied by a tuple disagreement and
        # vice versa, for any single-key drift: that is the redundancy, measured.
        for field, value in (('margin', 0.03), ('bodyRid', 9), ('maxCollisions', 16),
                             ('recoveryAsCollision', False), ('testOnly', False)):
            drifted = copy.deepcopy(good)
            if field == 'margin':
                self.retune(drifted, margin=value)
            else:
                drifted[field] = value
            equal, differences = hook.operands_unchanged(frozen, drifted, copy.deepcopy(drifted))
            self.assertFalse(equal)
            self.assertIn('request0:' + field if field != 'margin' else 'request0:margin',
                          differences)
            # Two requests that agree with each other but not with the tuple: the
            # tuple half fires, the pairwise half correctly does not. That is the
            # asymmetry the tuple anchor exists to cover.
            equal, differences = hook.operands_unchanged(frozen, drifted, drifted)
            self.assertFalse(equal)
            self.assertTrue(any(e.startswith('request') for e in differences))
            self.assertFalse(any(e.startswith('0~1:') for e in differences), differences)

    def test_the_operand_groups_partition_the_constants_and_say_what_they_pin(self):
        # How each constant is pinned is documented, exhaustive and non-overlapping,
        # so a future constant cannot be silently left unpinned.
        self.assertEqual(set(hook.DESIGN_FROZEN_CONSTANTS)
                         | set(hook.DERIVED_FROZEN_CONSTANTS)
                         | set(hook.RUN_FROZEN_CONSTANTS), set(hook.CONSTANTS))
        self.assertEqual(len(set(hook.DESIGN_FROZEN_CONSTANTS)
                             | set(hook.DERIVED_FROZEN_CONSTANTS)
                             | set(hook.RUN_FROZEN_CONSTANTS)), len(hook.CONSTANTS))
        self.assertEqual(hook.DERIVED_FROZEN_CONSTANTS, ('motion',))
        self.assertEqual(hook.RUN_FROZEN_CONSTANTS, ('bodyRid',))
        self.assertIn('bodyRid', hook.RUN_FROZEN_CONSTANTS)
        self.assertNotIn('bodyRid', hook.DESIGN_FROZEN_CONSTANTS)
        self.assertNotIn('motion', hook.DESIGN_FROZEN_CONSTANTS)
        # ``bodyRid`` is deliberately *not* design-frozen: a RID is assigned by the
        # engine for one run, so it is anchored by being identical across the three
        # requests rather than by comparison with the AM value.
        self.assertIs(hook.design_frozen(
            {'bodyRid': 1, 'margin': 0.02, 'maxCollisions': 32, 'recoveryAsCollision': True,
             'collideSeparationRay': True, 'excludeBodies': [], 'excludeObjects': [],
             'testOnly': True, 'motion': [0.0, -0.0201, 0.0]})['margin'], 0.02)
        self.assertIsNone(hook.design_frozen({'bodyRid': 1}))
        self.assertIsNone(hook.design_frozen(None))

    def test_the_recorded_am_motion_is_the_derivation_not_a_rounding(self):
        # The AM export serializes the motion the guard computed in float32, which is
        # a rounding of ``-UP * (margin + LIMIT)`` rather than the double-precision
        # derivation. The anchor therefore derives motion from the recorded margin and
        # checks the recorded motion against it, so the anchor is exact.
        export = history.load_export(prepare.ROOT)
        for application in export['applications']:
            if math.degrees(application['spec']['yaw']) > 0:
                continue
            raw = application['queries'][-1]['rawRequestResponse']
            derived = hook.down_motion({'margin': raw['margin']})
            self.assertNotEqual(list(raw['motion']), derived)
            self.assertLess(abs(raw['motion'][1] - derived[1]), hook.DERIVED_MOTION_EPSILON)
            self.assertGreater(abs(raw['motion'][1] - derived[1]), hook.OPERAND_EPSILON)
        # And the derived tolerance is far below the guard's own numeric budget, so
        # it cannot absorb a re-tuned motion.
        self.assertLess(hook.DERIVED_MOTION_EPSILON, hook.LIMIT)
        self.assertGreater(hook.DERIVED_MOTION_EPSILON, hook.OPERAND_EPSILON)


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
        # The claim that the validator proves the three requests carry the frozen
        # constants unchanged is true only because these calls exist. This is a *shape*
        # assertion, so it catches a refactor that drops a call outright; it cannot
        # catch a call whose verdict is ignored, which is why
        # ``FrozenOperandTests`` also loads a copy of the validator with each anchor's
        # enforcement removed and requires the forgery it is responsible for to be
        # admitted. Both are needed: deletion and neutering are different failures.
        # ``co_names`` records ``hook`` and each attribute separately, so these are
        # the calls the cross-observation proof is made of.
        calls = evidence._frozen_operands.__code__.co_names
        self.assertIn('hook', calls)
        for required in ('frozen_tuple', 'operands_unchanged', 'operand_equal',
                         'run_frozen_unchanged', 'DESIGN_FROZEN_CONSTANTS'):
            self.assertIn(required, calls)
        self.assertIn('carry exactly the whole tuple', evidence._frozen_operands.__doc__)
        # Each group of constants is pinned by its own rule, and the prose says so in
        # all three places the rule is written down -- the module that defines the
        # groups, the validator that enforces them and the validator's non-claims. A
        # run's body RID must not be described as anchored to the AM run anywhere.
        self.assertIn('and *never* by comparison with the AM run\'s value', hook.__doc__)
        self.assertIn('deliberately *not* compared with the AM run\'s RID',
                      evidence._frozen_operands.__doc__)
        self.assertIn('not required to be the AM run\'s body RID', evidence.__doc__)

    def test_the_native_readiness_blockers_are_pinned_verbatim(self):
        # Pinned as six literals, not compared against policy.NATIVE_READINESS_BLOCKERS
        # itself: comparing a value against itself moves both sides together, so
        # blanking or softening an entry would otherwise fail nothing. A reviewer
        # discharging a blocker must edit this list in the same commit as the policy,
        # which is what makes the edit visible.
        self.assertEqual(list(policy.NATIVE_READINESS_BLOCKERS), [
            'no independent source review of this package',
            'no heavy grant exists for phase support-query-compare-v1',
            'no GDScript staging is implemented; the bounded driver and hook exist only '
            'as offline Python',
            'no engine-invocation path exists in this source package by design',
            'zero-motion support semantics remain undefined; those two observations stay '
            'omitted',
            'AM whole positive admission remains failed and .42/.18/+45 remains unrun',
        ])
        self.assertEqual(len(policy.NATIVE_READINESS_BLOCKERS), 6)
        # Every entry must be a non-empty string, and no entry may be softened to a
        # vacuous one ("ready", "n/a", "" or a bare ".").
        for entry in policy.NATIVE_READINESS_BLOCKERS:
            self.assertIsInstance(entry, str)
            self.assertGreaterEqual(len(entry), 20)
            self.assertNotIn(entry.strip().lower(), ('', 'n/a', 'na', 'none', 'ready', '.'))
            self.assertTrue(entry.startswith('no ') or entry.startswith('zero-motion')
                            or entry.startswith('AM '), entry)
        # The receipt carries the same six, and the validator requires them exactly.
        receipt = run_campaign()
        self.assertIs(receipt['nativeReadiness']['ready'], False)
        self.assertEqual(receipt['nativeReadiness']['blockingReasons'],
                         list(policy.NATIVE_READINESS_BLOCKERS))
        self.assertEqual(len(receipt['nativeReadiness']['blockingReasons']), 6)

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
        # The frozen guard module is a pinned source reference, so this cross-package
        # dependency cannot drift silently: verify_references fails first.
        name = 'tools/godot-multiplayer/new-maps/walker-calibrated-admission/evidence.py'
        self.assertIn(name, prepare.REFERENCES)
        self.assertEqual(seals.sha(ROOT / name), prepare.REFERENCES[name])
        original = importlib.util.spec_from_file_location(
            '_support_query_compare_frozen_evidence', ROOT / name)
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
