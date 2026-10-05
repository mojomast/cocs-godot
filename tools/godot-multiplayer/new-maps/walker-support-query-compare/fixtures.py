"""Deterministic in-memory LiveMeasurement used by the test suite.

Everything the driver would learn from the engine is decided here, from the
frozen AM operands, and nothing is imported, staged or launched. The fake
records its call order so the observation-ordering contract can be asserted from
the outside, and it can be told to misbehave in one specific way so the driver's
refusals are exercised rather than assumed.
"""
import copy
import math

from . import hook
from . import policy

#: Frozen AM profile parameters for the two authorized cases. Taken verbatim from
#: the reviewed AM receipt so the synthetic fixture cannot drift into a new shape.
PROFILES = {
    'reference-035-015-neg45': {
        'margin': 0.0199999995529652, 'bodyRid': 154618822659, 'targetRid': 146028888066,
        'shapeRadius': 0.349999994039536, 'rise': 0.15,
        'from': [0.212131947278976, 0.0166666638106108, -0.212131947278976],
        'raised': [0.212131947278976, 0.172130957245827, -0.212131947278976],
        'horizontalBudget': [-0.0707106813788414, 0.0, 0.0707106813788414],
        'expectedFinal': [0.141421258449554, 0.0877559557557106, -0.141421258449554],
        'upMotion': [0.0, 0.1554642934352165, 0.0],
        'landingY': 0.15000000715255737,
        'guardNormal': [0.422360450029373, 0.802012085914612, -0.422360450029373],
        'guardTravel': [0.00652162730693817, -0.00682989694178104, -0.00652182102203369],
        'guardDepth': 0.0197234023362398,
        'guardAngleDegrees': 36.67732574092844,
        'guardPassed': True,
        'guardReason': 'endpoint_and_pinned_clear_branch_and_live_support_agree',
        'frame': 176,
    },
    'failure-042-018-neg45': {
        'margin': 0.0199999995529652, 'bodyRid': 274877906947, 'targetRid': 266287972354,
        'shapeRadius': 0.419999986886978, 'rise': 0.18,
        'from': [0.282842636108398, 0.0166666638106108, -0.282842636108398],
        'raised': [0.282842636108398, 0.20213095843792, -0.282842636108398],
        'horizontalBudget': [-0.0707106813788414, 0.0, 0.0707106813788414],
        'expectedFinal': [0.212131947278976, 0.0544746965169907, -0.212131947278976],
        'upMotion': [0.0, 0.18546429343521652, 0.0],
        'landingY': 0.18000000715255737,
        'guardNormal': [0.521141886711121, 0.675886213779449, -0.521141886711121],
        'guardTravel': [0.00818042457103729, -0.00874407775700092, -0.00818061828613281],
        'guardDepth': 0.0172504857182503,
        'guardAngleDegrees': 47.476992341452714,
        'guardPassed': False,
        'guardReason': 'invalid_final_support_normal_or_velocity',
        'frame': 550,
    },
}
#: Yaw basis shared by both authorized cases (recorded AM yaw basis).
BASIS = [[math.cos(math.radians(-45.0)), 0.0, -math.sin(math.radians(-45.0))],
         [0.0, 1.0, 0.0],
         [math.sin(math.radians(-45.0)), 0.0, math.cos(math.radians(-45.0))]]
#: The only reason the unchanged guard reports on a passing transition.
GUARD_PASS_REASON = 'endpoint_and_pinned_clear_branch_and_live_support_agree'


def policy_ok_reason():
    return GUARD_PASS_REASON


class FakeLive:
    """A :class:`driver.LiveMeasurement` whose every answer is frozen in advance.

    ``misbehave`` selects exactly one deviation so the driver or the validator can
    be shown to refuse it. The default ``None`` behaves.
    """

    def __init__(self, case_id, *, first_transition=None, extra_transitions=(), misbehave=None):
        if case_id not in PROFILES:
            raise ValueError('no synthetic profile for ' + repr(case_id))
        self.case_id = case_id
        self.profile = copy.deepcopy(PROFILES[case_id])
        self.first_transition = self.profile['frame'] if first_transition is None else first_transition
        self.extra = list(extra_transitions)
        self.misbehave = misbehave
        self.calls = []
        self.moved = False
        self.candidate_calls = 0
        self._phase = 'pre_up'

    # -- LiveMeasurement protocol ----------------------------------------
    def first_eligible_transition(self):
        self.calls.append('first_eligible_transition')
        return self.first_transition

    def eligible_transitions(self):
        self.calls.append('eligible_transitions')
        return [self.first_transition] + self.extra

    def state(self):
        self.calls.append('state:' + self._phase)
        origin = list(self.profile['expectedFinal'] if self._phase == 'final'
                      else self.profile['from'])
        grounded = True
        return {'transform': {'origin': origin, 'basis': [list(row) for row in BASIS]},
                'velocity': [0.0, 0.0, 0.0] if not self.moved else [0.0, -8.859375, 0.0],
                'grounded': grounded, 'floorNormal': [0.0, 1.0, 0.0],
                'platformVelocity': [0.0, 0.0, 0.0], 'platformAngularVelocity': [0.0, 0.0, 0.0],
                'slideCount': 0, 'resetCount': 1}

    def live_plan(self):
        self.calls.append('live_plan')
        plan = {'accepted': True, 'reason': 'bounded_riser_and_flat_static_base_support',
                'from': {'origin': list(self.profile['from']), 'basis': [list(r) for r in BASIS]},
                'raised': {'origin': list(self.profile['raised']),
                           'basis': [list(r) for r in BASIS]},
                'horizontalBudget': list(self.profile['horizontalBudget']),
                'expectedFinal': list(self.profile['expectedFinal']),
                'upMotion': list(self.profile['upMotion']),
                'landingY': self.profile['landingY'],
                'supportRid': self.profile['targetRid'], 'supportShape': 0}
        if self.misbehave == 'unaccepted_plan':
            plan['accepted'] = False
        if self.misbehave == 'expected_final_moved':
            plan['expectedFinal'] = [plan['expectedFinal'][0] + 0.01, plan['expectedFinal'][1],
                                     plan['expectedFinal'][2]]
        return plan

    def test_motion(self, request):
        self.calls.append('test_motion:' + request['name'])
        return self._serialize(request)

    def candidate_response(self, plan):
        self.calls.append('candidate_response')
        if self.misbehave == 'second_candidate_response':
            # Fires only on a second call: the first call is the authorized one.
            if self.candidate_calls:
                raise AssertionError('the driver asked for a second candidate response')
        self.candidate_calls += 1
        self.moved = True
        self._phase = 'final'
        passed = self.profile['guardPassed']
        reason = self.profile['guardReason']
        fault = '' if passed else reason
        if self.misbehave == 'guard_flipped':
            passed = not passed
            reason = policy_ok_reason() if passed else 'endpoint_differs_from_proof'
            fault = '' if passed else reason
        actual = list(self.profile['expectedFinal'])
        guard_request = self._serialize(hook.request_from(
            hook.GUARD_NAME, {'origin': actual, 'basis': [list(r) for r in BASIS]},
            hook.frozen_operands({'margin': self.profile['margin']},
                                 body_rid=self.profile['bodyRid'])))
        return {'guard': {'passed': passed, 'reason': reason},
                'guardRequest': guard_request, 'actualFinal': actual,
                'candidateFault': fault, 'appliedUpCount': 1, 'parentResponseCount': 1}

    # -- internals -------------------------------------------------------
    def _serialize(self, request):
        """Answer a down32 request the way the frozen AM receipt answered it.

        The normal is the recorded guard normal at the actual final state and a
        flatter tread normal at the predicted endpoint before the UP step: this is
        the very difference the comparison exists to observe, expressed as a
        frozen synthetic answer and labelled as such.
        """
        profile = self.profile
        at_predicted = request['name'] == hook.PRE_UP_NAME
        if at_predicted:
            # A flat tread normal: a passing observation, and clearly distinct from
            # the recorded fresh guard normal below. This is the synthetic answer a
            # flat pre-UP rest sample would produce; it is not a predicted result.
            normal = [0.0, 1.0, 0.0]
        else:
            normal = list(profile['guardNormal'])
        point = [profile['expectedFinal'][0], profile['landingY'], profile['expectedFinal'][2]]
        result = {'name': request['name'],
                  'from': {'origin': list(request['from']['origin']),
                           'basis': [list(row) for row in request['from']['basis']]},
                  'motion': list(request['motion']), 'margin': request['margin'],
                  'maxCollisions': hook.MAX_CONTACTS, 'hit': True, 'validResult': True,
                  'recoveryAsCollision': True, 'collideSeparationRay': True,
                  'travel': list(profile['guardTravel']), 'remainder': [0.0, 0.0, 0.0],
                  'safeFraction': 1.0, 'unsafeFraction': 1.0,
                  'contacts': [{'colliderRid': profile['targetRid'], 'colliderShape': 0,
                                'localShape': 0, 'colliderId': profile['targetRid'],
                                'collider': '/root/Test/PositiveTread',
                                'point': point, 'normal': normal,
                                'depth': profile['guardDepth'],
                                'velocity': [0.0, 0.0, 0.0]}],
                  'bodyRid': request['bodyRid'], 'excludeBodies': [],
                  'excludeObjects': [], 'testOnly': True}
        if self.misbehave == 'operands_rewritten' and request['name'] == hook.DUPLICATE_NAME:
            result['motion'] = [0.0, -(request['margin'] + 0.001), 0.0]
        if self.misbehave == 'zero_motion_instead_of_duplicate':
            result['motion'] = [0.0, 0.0, 0.0]
        if self.misbehave == 'state_mutated_by_query':
            self.moved = True
        if self.misbehave == 'guard_support_motion_changed':
            result['motion'] = [0.0, -(request['margin'] + 0.002), 0.0]
        if self.misbehave == 'unqualified_contact':
            result['contacts'][0]['colliderRid'] = 999
        if self.misbehave == 'nonfinite_contact':
            result['contacts'][0]['point'][1] = float('nan')
        return result

    def orders(self):
        """The observation order as the driver actually drove it."""
        return [call for call in self.calls if call.startswith(('test_motion', 'candidate_response'))]


def params_for(case_id):
    profile = PROFILES[case_id]
    return {'margin': profile['margin'], 'bodyRid': profile['bodyRid']}


def lives(misbehave=None, **kwargs):
    return {case_id: FakeLive(case_id, misbehave=misbehave, **kwargs)
            for case_id in policy.CASES}
