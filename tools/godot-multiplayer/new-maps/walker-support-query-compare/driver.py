"""Bounded driver: one first-eligible transition, three observations, then STOP.

This is the offline Python model of the driver the approved design calls for. It
is a state machine, not a harness: it takes no clock, no random source and no
network, and it never touches an engine. Every physics-dependent action is
delegated to a :class:`LiveMeasurement` supplied by the caller, so the ordering
contract can be exercised deterministically without a native run.

The enforced order is exactly:

1. ``pre_up_observation``    -- down32 at the live plan's predicted endpoint,
   before the UP step;
2. ``candidate_response``    -- ONE unchanged candidate response and guard;
3. ``guard_observation``     -- the guard's own actual-final-state down32,
   recorded verbatim and preserved as primary;
4. ``duplicate_observation`` -- the predetermined duplicate down32 at the same
   actual final state;
5. ``stop``                  -- terminal. No further movement, no retry.

There is no normal selection, no acceptance substitution, and no path that can run
a third case, a second candidate response, a later eligible transition, or any
movement after the stop.
"""
import math

from . import history
from . import hook
from . import policy


class BoundedContractError(ValueError):
    """The bounded contract was violated. Always raised, never logged and moved on."""


class Stopped(BoundedContractError):
    """Raised on any attempt to act after the terminal stop."""


#: Observable phases, in order. ``run_case`` may only move forward through these.
PHASES = ('planned', 'pre_up_observed', 'candidate_responded', 'guard_observed',
          'duplicate_observed', 'stopped')


class LiveMeasurement:
    """What a future native driver must expose. Nothing else is consulted.

    The point of this class is that the ordering contract lives entirely on this
    side of the boundary. Every method is a place where engine behaviour would
    later enter, and every one of them is called at most once per case except
    ``state`` and ``test_motion``.
    """

    def first_eligible_transition(self):
        """Index of the *first* eligible transition for this case."""
        raise NotImplementedError

    def eligible_transitions(self):
        """Every eligible transition index, so a later one can be refused."""
        raise NotImplementedError

    def state(self):
        """Observe.state equivalent: transform, velocity, grounded, floor normal."""
        raise NotImplementedError

    def live_plan(self):
        """The live plan at the transition, with raised/horizontalBudget/expectedFinal."""
        raise NotImplementedError

    def test_motion(self, request):
        """Execute one predetermined read-only down32 request and serialize it."""
        raise NotImplementedError

    def candidate_response(self, plan):
        """Execute the unchanged candidate response and guard exactly once.

        Must return the guard's own recorded support request unmodified together
        with its result, fault and counters. The driver refuses to fabricate,
        repair or reinterpret any part of it.
        """
        raise NotImplementedError


def _require(condition, message):
    if not condition:
        raise BoundedContractError(message)


class BoundedDriver:
    """Runs one case under the fixed observation contract, then stops."""

    def __init__(self, case_id, *, params, historical):
        if not policy.case_allowed(case_id):
            # Refused as an out-of-scope case, so the refusal reads as the phase
            # allowlist rather than as some other contract detail.
            raise policy.PolicyError('case not authorized: ' + repr(case_id))
        if not isinstance(params, dict) or 'margin' not in params or 'bodyRid' not in params:
            raise BoundedContractError('live profile parameters required')
        if not isinstance(historical, dict) or historical.get('caseId') != case_id:
            raise BoundedContractError('historical record must bind this case')
        self.case_id = case_id
        self.spec = policy.spec_for(case_id)
        self.params = dict(params)
        self.historical = historical
        self.phase = 'planned'
        self.events = []
        self.observations = []
        self.query_state = []
        self.frozen = None
        self.counters = {'candidateResponses': 0, 'appliedUpCount': 0,
                         'parentResponseCount': 0, 'subsequentMovementResponses': 0,
                         'retries': 0, 'normalSelections': 0, 'acceptanceSubstitutions': 0}

    # -- introspection ---------------------------------------------------
    @property
    def stopped(self):
        return self.phase == 'stopped'

    def state(self):
        """Refuse any further body interaction once the driver has stopped."""
        if self.stopped:
            raise Stopped('body interaction after stop is not permitted')
        return None

    def _advance(self, phase):
        index = PHASES.index(self.phase)
        if PHASES.index(phase) != index + 1:
            raise BoundedContractError('illegal phase move %s -> %s' % (self.phase, phase))
        self.phase = phase

    # -- the bounded sequence -------------------------------------------
    def run_case(self, live, transition_index=None):
        """Execute the one authorized sequence for this case and return its record."""
        if self.phase != 'planned':
            raise BoundedContractError('case already started: ' + self.phase)
        first = live.first_eligible_transition()
        eligible = list(live.eligible_transitions())
        _require(eligible and eligible[0] == first,
                 'the first eligible transition must be the minimum eligible index')
        if transition_index is None:
            transition_index = first
        _require(hook.integer(transition_index) and transition_index >= 0,
                 'transition index must be a nonnegative integer')
        _require(transition_index == first,
                 'only the first eligible transition is authorized; got %r' % (transition_index,))

        plan = live.live_plan()
        _require(isinstance(plan, dict) and plan.get('accepted') is True,
                 'the live plan must be an accepted original proposal')
        for key in ('from', 'raised', 'horizontalBudget', 'expectedFinal', 'upMotion',
                    'landingY', 'supportRid', 'supportShape'):
            _require(key in plan, 'live plan is missing ' + key)
        # response_guard.gd:29 defines the endpoint as raised.origin+horizontal and
        # then compares only its UP-projected remainder against the actual final
        # position, because apply_floor_snap's Y-only projection changes the height
        # without changing the proved horizontal vector. The pre-UP observation is
        # therefore asked at that same endpoint, and the height disagreement is
        # recorded rather than demanded away.
        predicted_origin = [a + b for a, b in zip(plan['raised']['origin'], plan['horizontalBudget'])]
        epsilon = hook.numeric_budget([plan['from']['origin'], plan['raised']['origin'],
                                       predicted_origin, plan['expectedFinal'],
                                       live.state()['transform']['origin']])
        _require(epsilon > 0, 'unsupported numeric domain for the bounded observation')
        self.params['epsilon'] = epsilon

        # The proposal -- including the omitted zero-motion observations and the
        # frozen duplicate constants -- is built here, before any execution.
        predetermined = hook.proposal(plan, self.params, body_rid=self.params['bodyRid'])
        self.frozen = predetermined['frozenOperands']
        # The AM guard's own recorded operands are the anchor for the frozen tuple.
        # Checking here, before anything executes, means a re-tuned profile is
        # refused rather than measured against a history it no longer matches.
        # ``bodyRid`` is deliberately absent from ``compared``: it is run-frozen
        # rather than design-frozen, so it is not required to equal the AM run's RID.
        # It is required to be a positive integer (checked below) and, on the
        # validator's side, to agree with itself across this run's three requests
        # (``hook.run_frozen_unchanged``) -- which is the same rule, not a looser one.
        frozen_from_history = self.historical.get('amFrozenOperands')
        if not isinstance(frozen_from_history, dict):
            raise BoundedContractError('historical record must bind the AM frozen operands')
        compared = hook.DESIGN_FROZEN_CONSTANTS + hook.DERIVED_FROZEN_CONSTANTS
        equal, differences = hook.operand_equal(frozen_from_history, self.frozen, keys=compared)
        if not equal:
            raise BoundedContractError('the live plan\'s frozen down32 operands differ from '
                                        'the recorded AM operands at: ' + ','.join(differences))
        _require(hook.integer(self.frozen['bodyRid']) and self.frozen['bodyRid'] > 0,
                 'the frozen body RID must be a positive integer')
        horizontal_error = math.hypot(
            plan['expectedFinal'][0] - predetermined['predictedEndpoint'][0],
            plan['expectedFinal'][2] - predetermined['predictedEndpoint'][2])
        _require(horizontal_error <= epsilon,
                 'the predicted endpoint disagrees horizontally with the live expected endpoint')
        vertical_offset = plan['expectedFinal'][1] - predetermined['predictedEndpoint'][1]

        pre_state = live.state()
        _require(hook.distance(pre_state['transform']['origin'], plan['from']['origin']) <= epsilon,
                 'the body is not at the plan origin before the UP step')
        _require(pre_state['grounded'] is True, 'the body must be grounded at the transition')

        # 1. down32 at the predicted endpoint, BEFORE the UP step.
        pre_up = self._observe(live, predetermined['preUpRequest'], ordinal=1,
                               site='pre_up_predicted_endpoint', issued_by='bounded_observer')
        _require(pre_up['queryStateEqual'] is True,
                 'the pre-UP observation changed recorded body state')
        _require(pre_up['request']['from']['origin'] == predetermined['predictedEndpoint'],
                 'the pre-UP observation must be asked at the predicted endpoint')
        self._advance('pre_up_observed')
        self.events.append('pre_up_observation')

        # 2. exactly one unchanged candidate response and guard.
        response = live.candidate_response(plan)
        self.counters['candidateResponses'] += 1
        _require(self.counters['candidateResponses'] == policy.CANDIDATE_RESPONSE_BUDGET,
                 'exactly one candidate response is authorized')
        guard, guard_observation = self._consume_candidate_response(response, epsilon)
        self._advance('candidate_responded')
        self.events.append('candidate_response')

        # 3. the guard's own actual-final-state down32, recorded verbatim.
        self.observations.append(guard_observation)
        self.query_state.append({'site': 'guard_actual_final_state', 'queryStateEqual': True,
                                 'source': 'unchanged response guard'})
        self._advance('guard_observed')
        self.events.append('guard_observation')

        # 4. the predetermined duplicate down32 at the same actual final state.
        actual_final = guard_observation['request']['from']
        duplicate_request = hook.request_from(predetermined['duplicateName'],
                                              actual_final, self.frozen)
        duplicate = self._observe(live, duplicate_request, ordinal=4,
                                  site='duplicate_actual_final_state',
                                  issued_by='bounded_observer')
        _require(duplicate['queryStateEqual'] is True,
                 'the duplicate observation changed recorded body state')
        _require(hook.distance(duplicate['request']['from']['origin'], actual_final['origin']) == 0.0,
                 'the duplicate must be asked at the same actual final state as the guard')
        self._advance('duplicate_observed')
        self.events.append('duplicate_observation')

        # 5. terminal stop.
        self._advance('stopped')
        self.events.append('stop')
        return self._record(plan, predetermined, guard, transition_index, epsilon,
                            horizontal_error, vertical_offset)

    # -- internals -------------------------------------------------------
    def _observe(self, live, operands, *, ordinal, site, issued_by):
        pre = live.state()
        raw = live.test_motion(operands)
        post = live.state()
        _require(isinstance(raw, dict) and 'name' in raw, 'serialized observation required')
        equal, differences = hook.operand_equal(operands, raw)
        _require(equal, 'the engine changed frozen operands: ' + ','.join(differences))
        observed = hook.record(pre, post, raw, operands=operands, issued_by=issued_by,
                               site=site, ordinal=ordinal)
        if issued_by == 'bounded_observer':
            self.observations.append(observed)
            self.query_state.append({'site': site, 'queryStateEqual': observed['queryStateEqual'],
                                     'source': 'bounded observer'})
        return observed

    def _consume_candidate_response(self, response, epsilon):
        """Preserve the guard's result, fault and request exactly as returned."""
        _require(isinstance(response, dict), 'candidate response record required')
        for key in ('guard', 'guardRequest', 'actualFinal', 'candidateFault',
                    'appliedUpCount', 'parentResponseCount'):
            _require(key in response, 'candidate response is missing ' + key)
        guard = response['guard']
        _require(isinstance(guard, dict) and type(guard.get('passed')) is bool
                 and isinstance(guard.get('reason'), str), 'guard result required')
        guard_request = response['guardRequest']
        _require(isinstance(guard_request, dict) and guard_request.get('name') == hook.GUARD_NAME,
                 'the unchanged guard support request is required and is primary')
        _require(guard_request.get('testOnly', True) is True,
                 'the guard support request must remain test-only')
        equal, differences = hook.operand_equal(self.frozen, guard_request,
                                                keys=hook.GUARD_CONSTANTS)
        _require(equal, 'the unchanged guard request differs from the frozen down32 constants: '
                        + ','.join(differences))
        _require(hook.transform(guard_request['from']), 'the guard request needs a full transform')
        actual = response['actualFinal']
        _require(hook.vec(actual), 'actual final position required')
        _require(hook.distance(actual, guard_request['from']['origin']) <= epsilon,
                 'the guard request must originate at the actual final state')
        _require(response['appliedUpCount'] == policy.CANDIDATE_RESPONSE_BUDGET,
                 'exactly one UP may be applied')
        _require(response['parentResponseCount'] == 1, 'exactly one parent response may occur')
        fault = response['candidateFault']
        _require(isinstance(fault, str), 'candidate fault must be a string')
        _require(fault == ('' if guard['passed'] else guard['reason']),
                 'the candidate fault must stay exactly as the guard reported it')
        self.counters['appliedUpCount'] += 1
        self.counters['parentResponseCount'] += 1
        observation = {'ordinal': 3, 'site': 'guard_actual_final_state',
                       'issuedBy': 'unchanged_response_guard',
                       'request': guard_request, 'result': guard_request,
                       'bodyStateBefore': None, 'bodyStateAfter': None,
                       'queryStateEqual': True, 'recordedBeforeUpStep': False,
                       'issuedAfterUpStep': True,
                       'qualification': "The guard's own request, recorded verbatim and "
                                        'preserved as primary; not reissued here. Equal '
                                        'recorded body state does not prove caches, broadphase '
                                        'or other hidden state were unaffected.'}
        preserved = {'passed': guard['passed'], 'reason': guard['reason'],
                     'candidateFault': fault, 'preservedIntact': True}
        return preserved, observation

    def _record(self, plan, predetermined, guard, transition_index, epsilon,
                horizontal_error, vertical_offset):
        agrees, divergence = history.agree(self.case_id, self.historical, guard)
        return {
            'caseIndex': policy.CASES.index(self.case_id),
            'caseId': self.case_id,
            'spec': dict(self.spec),
            'status': 'stopped_after_duplicate_observation',
            'firstEligibleTransition': transition_index,
            'usedFirstEligibleTransition': True,
            'eventLog': list(self.events),
            'plan': {
                'from': plan['from'], 'raised': plan['raised'],
                'horizontalBudget': plan['horizontalBudget'],
                'predictedEndpoint': predetermined['predictedEndpoint'],
                'expectedFinal': plan['expectedFinal'], 'upMotion': plan['upMotion'],
                'landingY': plan['landingY'], 'supportRid': plan['supportRid'],
                'supportShape': plan['supportShape'], 'epsilon': epsilon,
                'horizontalAgreementError': horizontal_error,
                'verticalOffsetFromPredictedEndpoint': vertical_offset,
                'predictedEndpointBasis': ('response_guard.gd:29 endpoint = raised.origin + '
                                           'horizontalBudget; only the UP-projected remainder '
                                           'is compared against the actual final position'),
            },
            'observations': list(self.observations),
            'frozenOperands': dict(self.frozen),
            'omissions': list(predetermined['omissions']),
            'queryStateEquality': list(self.query_state),
            'guard': guard,
            'history': {'amCaseIndex': self.historical['amCaseIndex'],
                        'amFrame': self.historical['amFrame'],
                        'amFrozenOperands': dict(self.historical['amFrozenOperands']),
                        'agreesWithHistory': agrees,
                        'historicalGuardReason': self.historical['guardReason'],
                        'historicalFreshGuardNormalAngleDegrees':
                            self.historical['freshGuardNormalAngleDegrees'],
                        'preUpPredictedEndpointRecordedInAM': False},
            'unexpectedOutcome': None if agrees else {'caseId': self.case_id, 'divergence': divergence},
            'stoppedAfterDuplicateObservation': True,
            'subsequentMovementPossible': False,
            **self.counters,
        }


def run(lives, *, params, historical):
    """Run exactly the two authorized cases, in canonical order, and stop.

    ``lives`` must be a mapping with exactly the two authorized case ids, keyed in
    canonical order. Any extra, missing or reordered case raises before a single
    body is touched.
    """
    policy.validate_case_set(list(lives))
    records = []
    for case_id in policy.CASES:
        driver = BoundedDriver(case_id, params=params, historical=historical['cases'][case_id])
        records.append(driver.run_case(lives[case_id]))
    if len(records) != policy.CASE_COUNT:
        raise BoundedContractError('the campaign must contain exactly two case records')
    return records


__all__ = ['BoundedDriver', 'BoundedContractError', 'LiveMeasurement', 'PHASES', 'Stopped', 'run']
