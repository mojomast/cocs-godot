"""Observational hook: the exact down32 requests this package is allowed to make.

Pure request and record construction. The hook never moves a body, never selects
a normal (a normal it returns is an observation, not a selected normal), never
substitutes an acceptance and never retries. Two observations from the reviewed
design are deliberately absent: every exact-zero motion request is *omitted* from
the executable proposal, because ``godot_space_3d.cpp:698-699`` divides motion by
its length with no zero check, so exact-zero semantics are not established. Epsilon
motion is never substituted for an omitted observation.

Predetermination, stated precisely. Everything about the down32 request that can
be known before execution *is* frozen first: motion, margin, max contacts,
recovery-as-collision, separation-ray, body RID, exclusions and test-only. Those
constants are fixed in :func:`frozen_operands` before the UP step runs, and the
resulting tuple is written into the prepared source record before execution and
carried into the receipt. The one field that cannot be predetermined is the pose,
because "the actual final state" is by definition only known after the candidate
response returns; that pose is taken verbatim from the guard's own recorded
request and is never chosen.

That is what makes the duplicate a genuine duplicate rather than a re-tuned
request, and it is *checked* rather than asserted. The validator holds all three
executed requests -- the pre-UP one, the guard's own recorded one and the duplicate
-- against the single recorded frozen-operand tuple: all three must carry exactly it
on every constant in :data:`CONSTANTS`, and they are compared against each other as
well. See :func:`operands_unchanged` for that predicate and ``evidence.record`` for
the check itself, which also anchors the tuple to the SHA256-pinned AM guard request
so it cannot be re-tuned inside a receipt.

What the check does *not* claim: that the recorded tuple is the one the driver froze.
That is the prepared source record's job, and the receipt's ``sourceSha256`` is what
binds the two. What the validator can prove from a self-attested record alone is that
the three requests agree with each other and with one recorded operand set.
"""
import math

#: response_guard.gd:3 -- LIMIT. Kept separate from margin; never merged into one.
LIMIT = 0.0001
#: sweep_proposal.gd MAX_CONTACTS used by every reviewed support sweep.
MAX_CONTACTS = 32
#: Operand constants that must be identical across the frozen proposal, the
#: unchanged guard's own request, and the issued duplicate.
CONSTANTS = ('motion', 'margin', 'maxCollisions', 'recoveryAsCollision',
             'collideSeparationRay', 'bodyRid', 'excludeBodies', 'excludeObjects', 'testOnly')
#: How each frozen constant is pinned. The three groups together are exactly
#: ``CONSTANTS``, and each group has its own fail-closed rule; the split matters
#: because the three kinds of constant have genuinely different provenance.
#:
#: * :data:`DESIGN_FROZEN_CONSTANTS` -- fixed by reviewed source (the
#:   ``sweep_proposal.gd`` operand set, ``response_guard.gd`` LIMIT) and recorded
#:   in the SHA256-pinned AM guard request. Re-tuning one of these is not a fresh
#:   measurement of this case, it is a different case.
#: * :data:`DERIVED_FROZEN_CONSTANTS` -- computed from the frozen margin by
#:   :func:`down_motion`, so the right test is the derivation rather than equality
#:   with the engine's float32 round-trip of the same value.
#: * :data:`RUN_FROZEN_CONSTANTS` -- assigned by the engine for one run and frozen
#:   into the prepared record before execution. Provenance is the run itself, so
#:   these are pinned by being identical across the pre-UP request, the guard's
#:   own request and the duplicate, not by comparison with the AM value.
DESIGN_FROZEN_CONSTANTS = ('margin', 'maxCollisions', 'recoveryAsCollision',
                           'collideSeparationRay', 'excludeBodies', 'excludeObjects',
                           'testOnly')
DERIVED_FROZEN_CONSTANTS = ('motion',)
RUN_FROZEN_CONSTANTS = ('bodyRid',)

#: Tolerance for checking a *recorded* engine motion against the derivation.
#:
#: The reviewed guard computes ``-UP * (margin + LIMIT)`` in float32, so its
#: serialized motion is a float32 rounding of the double-precision derivation: the
#: pinned AM guard request records ``[0, -0.0200999993830919, 0]`` where
#: ``down_motion(0.0199999995529652)`` gives ``[0, -0.0200999995529652, 0]``, a gap
#: of 1.6987e-10. The recorded value is therefore not bit-identical to the
#: derivation and must not be required to be -- what has to hold is the identity
#: "this motion is the derived motion, to within the guard's own arithmetic", which
#: is why this tolerance is used for the recorded check and only there.
#:
#: 1e-9 is a thousand times a double epsilon (so ordinary float32 rounding of a
#: 20 mm vector passes) and a million times below any physical difference in this
#: contract (the guard's own numeric budget for these coordinates is 1e-6 m), so it
#: cannot absorb a re-tuned margin or motion.
DERIVED_MOTION_EPSILON = 1e-9
#: The subset a legacy log_sweep serialization actually carries.
GUARD_CONSTANTS = ('motion', 'margin', 'maxCollisions', 'recoveryAsCollision',
                   'collideSeparationRay', 'bodyRid', 'excludeBodies', 'excludeObjects')
#: Keys that only exist once the engine has answered.
RETURNED = ('hit', 'validResult', 'travel', 'remainder', 'safeFraction', 'unsafeFraction', 'contacts')

PRE_UP_NAME = 'pre-up-predicted-endpoint-support'
DUPLICATE_NAME = 'duplicate-actual-final-support'
GUARD_NAME = 'actual-final-support'

OMISSION_REASON = 'exact_zero_motion_semantics_undefined'
OMISSION_BASIS = ('godot_space_3d.cpp:698-699 forms motion/length with no zero check; '
                  'exact-zero semantics are not established for this build')
#: Tolerance for comparing a frozen operand against a returned serialization.
#: 1e-12 is six orders of magnitude below the 1um guard budget, so it cannot
#: absorb any physical difference; it only absorbs double round-tripping.
OPERAND_EPSILON = 1e-12

#: Ordered observation sites, following the reviewed design's numbering.
SITES = (
    (1, 'pre_up_predicted_endpoint', 'executed'),
    (2, 'pre_up_predicted_endpoint', 'omitted'),
    (3, 'guard_actual_final_state', 'executed'),
    (4, 'duplicate_actual_final_state', 'executed'),
    (5, 'post_guard_actual_final_state', 'omitted'),
)


class HookError(ValueError):
    """Any request this package is not allowed to build or record."""


class ExactZeroMotionOmitted(HookError):
    """An exact-zero motion request was requested; it is refused, not adjusted."""

    def __init__(self, site, ordinal=0):
        super().__init__('exact-zero motion omitted at ordinal %d (%s)' % (ordinal, site))
        self.site = site
        self.ordinal = ordinal


def num(value):
    return type(value) in (int, float) and math.isfinite(value)


def integer(value):
    return num(value) and value == int(value)


def vec(value, size=3):
    return isinstance(value, list) and len(value) == size and all(num(v) for v in value)


def near(a, b, epsilon=OPERAND_EPSILON):
    return num(a) and num(b) and abs(a - b) <= epsilon


def zero(value):
    """Componentwise zero, matching Godot's Vector3.is_zero_approx (CMP_EPSILON)."""
    return vec(value) and all(abs(x) < 0.00001 for x in value)


def exact_zero(value):
    """Exactly zero in every component -- no approximate slack at all.

    This is the predicate an omitted observation must satisfy. It is deliberately
    stricter than :func:`zero`, which reproduces Godot's own approximate test for
    *engine* values; here the distinction matters because an approximate test
    would let a small nonzero motion be filed as an exact-zero omission.
    """
    return vec(value) and all(x == 0 for x in value)


def length3(value):
    return math.sqrt(sum(x * x for x in value))


def distance(a, b):
    if not (vec(a) and vec(b) and len(a) == len(b)):
        return math.inf
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def transform(value):
    return (isinstance(value, dict) and set(value) == {'origin', 'basis'}
            and vec(value['origin'])
            and isinstance(value['basis'], list) and len(value['basis']) == 3
            and all(vec(row) for row in value['basis']))


def numeric_budget(points):
    """Port of response_guard.gd numeric_budget: eight float32 ULPs, or refusal.

    Returns -1.0 for a non-finite or unsupportable coordinate domain, exactly as
    the guard does. The cap is a domain refusal, never an endpoint allowance.
    """
    magnitude = 1.0
    for point in points:
        if not vec(point):
            return -1.0
        magnitude = max(magnitude, max(abs(x) for x in point))
    budget = 8.0 * 2.0 ** (math.floor(math.log(magnitude) / math.log(2.0)) - 23.0)
    return max(0.000001, budget) if budget <= LIMIT else -1.0


def down_motion(params):
    """The reviewed down32 motion: ``-UP * (safe_margin + LIMIT)``.

    A margin that is negative, or that would cancel LIMIT exactly, is refused
    before any arithmetic happens -- both would produce a zero-length or upward
    motion, which is precisely the undefined case this package refuses to issue.
    """
    margin = params.get('margin')
    if not num(margin):
        raise HookError('non-numeric safe margin')
    if margin + LIMIT <= 0:
        # Distinguish a margin that cancels LIMIT exactly (the undefined-zero case
        # this package exists to avoid issuing) from an outright invalid margin.
        if margin == -LIMIT:
            raise ExactZeroMotionOmitted('down_motion')
        raise HookError('negative safe margin')
    return [0.0, -(margin + LIMIT), 0.0]


def frozen_operands(params, *, body_rid, test_only=True):
    """Freeze the down32 operand constants. Called before anything is executed."""
    if not integer(body_rid) or body_rid <= 0:
        raise HookError('positive integer body RID required')
    motion = down_motion(params)
    if zero(motion) or length3(motion) == 0.0:
        raise ExactZeroMotionOmitted('frozen_operands')
    return {'motion': list(motion), 'margin': params['margin'], 'maxCollisions': MAX_CONTACTS,
            'recoveryAsCollision': True, 'collideSeparationRay': True, 'bodyRid': body_rid,
            'excludeBodies': [], 'excludeObjects': [], 'testOnly': bool(test_only)}


def design_frozen(tuple_or_none):
    """The design-frozen subset of a recorded frozen-operand tuple, or ``None``.

    ``None`` for anything that is not exactly a frozen-operand tuple, so callers
    fail closed rather than comparing against a partial mapping.
    """
    if not isinstance(tuple_or_none, dict) or set(tuple_or_none) != set(CONSTANTS):
        return None
    return {key: tuple_or_none[key] for key in DESIGN_FROZEN_CONSTANTS}


def operands_unchanged(frozen, *requests):
    """Fail closed: every request must carry exactly the frozen operand constants.

    This is the cross-observation proof the duplicate depends on, and it is checked
    two ways on purpose.

    * against the recorded frozen-operand tuple, on every constant in
      :data:`CONSTANTS` -- so a re-tuned margin, motion, body RID, flag or exclusion
      in *any one* of the pre-UP request, the guard's own recorded request or the
      duplicate is refused even if the other two were re-tuned with it;
    * against each other, pairwise -- so the three requests are proven equal to one
      another directly rather than only through the tuple. The two overlap by
      construction, and the pairwise half is kept anyway: it is the property the
      package actually relies on (the duplicate is a duplicate of the guard), and
      deriving it only from a tuple that is itself a recorded field would let a
      future change that loosens the tuple anchor remove the comparison silently.

    Differences are reported as ``request<i>:<key>`` for the tuple comparison and
    ``<i>~<j>:<key>`` for the pairwise one, so a refusal names which observation
    drifted, on which operand, and whether it disagreed with the frozen set or only
    with another observation.

    What this does *not* claim: that the tuple is the one the driver froze. That is
    the prepared source record's job, and the record is what the receipt's
    ``sourceSha256`` binds.
    """
    differences = []
    if not isinstance(frozen, dict) or set(frozen) != set(CONSTANTS):
        return False, ['frozen_operand_tuple']
    for index, request in enumerate(requests):
        equal, found = operand_equal(frozen, request, keys=CONSTANTS)
        differences.extend('request%d:%s' % (index, key) for key in found)
    for index, request in enumerate(requests):
        for other_index in range(index + 1, len(requests)):
            equal, found = operand_equal(request, requests[other_index], keys=CONSTANTS)
            differences.extend('%d~%d:%s' % (index, other_index, key) for key in found)
    return not differences, differences


def request_from(name, start, frozen):
    """Bind frozen operand constants to a pose. The pose is supplied, never chosen."""
    if not isinstance(name, str) or not name:
        raise HookError('observation name required')
    if not transform(start):
        raise HookError('hypothetical full transform required')
    if not isinstance(frozen, dict) or set(frozen) != set(CONSTANTS):
        raise HookError('exact frozen operand set required')
    return {'name': name,
            'from': {'origin': list(start['origin']), 'basis': [list(row) for row in start['basis']]},
            **{key: (list(frozen[key]) if isinstance(frozen[key], list) else frozen[key])
               for key in CONSTANTS}}


def request(name, start, params, *, body_rid, test_only=True):
    """Convenience wrapper: freeze and bind in one step."""
    return request_from(name, start, frozen_operands(params, body_rid=body_rid, test_only=test_only))


def omission(ordinal, site, *, reason=OMISSION_REASON, requested_motion=(0.0, 0.0, 0.0),
             substituted_motion=None):
    """Record an omitted observation.

    ``requested_motion`` must be exactly zero: an omission is a record of a
    request that was *not* made, so an epsilon stand-in cannot be recorded here
    and ``substituted_motion`` must stay ``None``. The only accepted ``reason``
    is the undefined-zero-semantics one; there is no free-text reason.
    """
    if type(ordinal) is not int or ordinal < 1:
        raise HookError('positive integer ordinal required')
    if not isinstance(site, str) or not site:
        raise HookError('site required')
    if reason != OMISSION_REASON:
        raise HookError('only the undefined-zero-semantics omission reason is recognized')
    if substituted_motion is not None:
        raise HookError('epsilon substitution refused: an omission carries no substituted motion')
    motion = list(requested_motion)
    if not vec(motion) or not exact_zero(motion):
        raise HookError('only exact-zero motion may be omitted; epsilon substitution refused')
    return {'ordinal': ordinal, 'site': site, 'requestedMotion': motion,
            'omitted': True, 'executed': False, 'substitutedMotion': None,
            'substitutionRefused': True, 'reason': reason, 'sourceBasis': OMISSION_BASIS,
            'qualification': ('Not a result. This observation was removed from the '
                              'executable proposal; it is not evidence of support '
                              'semantics and not a valid support certificate.')}


def frozen_tuple(value):
    """Fail-closed validation of a recorded frozen-operand tuple.

    Requires the exact :data:`CONSTANTS` key set and requires the values to be the
    ones :func:`frozen_operands` produces for those operands: a positive integer
    body RID, a margin that yields a nonzero motion, motion equal to the derived
    :func:`down_motion` value, the reviewed contact cap, the two true flags, empty
    exclusions and test-only. Nothing is repaired or defaulted; a malformed tuple
    raises :class:`HookError` rather than being filled in.

    The derived-motion check is exact equality on purpose. The frozen tuple is
    computed once in Python before execution and serialized; a float64 round-trip
    through JSON is exact, and the engine's own float32 round-trip is a different
    question answered by the recorded result, not by the frozen tuple.
    """
    if not isinstance(value, dict) or set(value) != set(CONSTANTS):
        raise HookError('exact frozen operand tuple required')
    if not integer(value['bodyRid']) or value['bodyRid'] <= 0:
        raise HookError('positive integer body RID required')
    if not num(value['margin']) or value['margin'] + LIMIT <= 0:
        raise HookError('frozen safe margin must yield a nonzero motion')
    if list(value['motion']) != down_motion({'margin': value['margin']}):
        raise HookError('frozen motion must be the derived down32 motion')
    if value['maxCollisions'] != MAX_CONTACTS:
        raise HookError('frozen max contacts must be the reviewed contact cap')
    for key in ('recoveryAsCollision', 'collideSeparationRay', 'testOnly'):
        if value[key] is not True:
            raise HookError('frozen ' + key + ' must be true')
    if value['excludeBodies'] != [] or value['excludeObjects'] != []:
        raise HookError('frozen exclusions must be empty')
    return {key: (list(value[key]) if isinstance(value[key], list) else value[key])
            for key in CONSTANTS}


def proposal(plan, params, *, body_rid):
    """The whole predetermined proposal, built before anything is executed.

    Returns the pre-UP request at the live plan's predicted endpoint, the frozen
    duplicate operand constants, and the two omitted exact-zero observations.
    Because the constants are frozen here, the duplicate issued after the guard
    cannot have been re-tuned after seeing the guard's answer.
    """
    if not isinstance(plan, dict):
        raise HookError('live plan required')
    for key in ('from', 'raised', 'horizontalBudget', 'expectedFinal'):
        if key not in plan:
            raise HookError('live plan is missing ' + key)
    for key in ('from', 'raised'):
        if not transform(plan[key]):
            raise HookError('live plan transform invalid: ' + key)
    if not vec(plan['horizontalBudget']):
        raise HookError('horizontal budget required')
    predicted = [a + b for a, b in zip(plan['raised']['origin'], plan['horizontalBudget'])]
    basis = plan['raised']['basis']
    frozen = frozen_operands(params, body_rid=body_rid)
    return {'predictedEndpoint': predicted,
            'frozenOperands': frozen,
            'preUpRequest': request_from(PRE_UP_NAME, {'origin': predicted, 'basis': basis}, frozen),
            'duplicateName': DUPLICATE_NAME,
            'omissions': [omission(2, 'pre_up_predicted_endpoint'),
                          omission(5, 'post_guard_actual_final_state')],
            'executableObservationCount': 2, 'omittedObservationCount': 2,
            'epsilonSubstitutionUsed': False, 'zeroMotionRequestsExecuted': 0,
            'qualification': ('Down32 operands only. A normal returned by either '
                              'observation is an observation, not a selected normal, '
                              'and never replaces the guard predicate.')}


def record(pre, post, raw, *, operands, issued_by, site, ordinal):
    """Serialize one executed observation against its body-state snapshots."""
    if issued_by not in ('bounded_observer', 'unchanged_response_guard'):
        raise HookError('unknown observation issuer')
    return {'ordinal': ordinal, 'site': site, 'issuedBy': issued_by,
            'request': dict(operands), 'result': dict(raw),
            'bodyStateBefore': pre, 'bodyStateAfter': post,
            'queryStateEqual': pre == post,
            'recordedBeforeUpStep': ordinal == 1,
            'issuedAfterUpStep': ordinal != 1,
            'qualification': ('Equal recorded body state does not prove caches, broadphase '
                              'or other hidden state were unaffected.')}


def operand_equal(expected, actual, *, keys=CONSTANTS, require_name=None):
    """Fail-closed operand comparison, numeric keys within OPERAND_EPSILON."""
    if not isinstance(expected, dict) or not isinstance(actual, dict):
        return False, ['not_a_mapping']
    differences = []
    if require_name is not None and actual.get('name') != require_name:
        differences.append('name')
    for key in keys:
        if key not in actual:
            differences.append('missing:' + key)
            continue
        want, got = expected[key], actual[key]
        if isinstance(want, bool) or isinstance(got, bool):
            if want is not got:
                differences.append(key)
        elif isinstance(want, (int, float)) and isinstance(got, (int, float)):
            if not near(want, got):
                differences.append(key)
        elif isinstance(want, list) and isinstance(got, list):
            if len(want) != len(got) or any(not near(a, b) for a, b in zip(want, got)):
                differences.append(key)
        elif want != got:
            differences.append(key)
    return not differences, differences


def guard_constants(recorded):
    """Extract the operand constants the unchanged guard's own request carries."""
    if not isinstance(recorded, dict) or recorded.get('name') != GUARD_NAME:
        raise HookError('expected the unchanged guard support request')
    return {key: recorded[key] for key in GUARD_CONSTANTS if key in recorded}


def valid_result(operands, result, *, target_rid, target_shape, local_shape=0,
                 plane_y=None, floor_angle=None, epsilon=None,
                 max_contacts=MAX_CONTACTS):
    """Finite-result and qualification checks for one returned observation.

    Mirrors the reviewed ``Evidence.support`` predicates minus the pass/fail
    decision: this is a measurement, so an unqualified contact is *reported*, not
    turned into a verdict about whether support exists.
    """
    problems = []
    if not isinstance(result, dict):
        return False, ['not_a_mapping']
    if not isinstance(operands, dict) or set(operands) != set(CONSTANTS):
        return False, ['operands']
    equal, differences = operand_equal(operands, result, keys=('maxCollisions', 'margin'))
    if not equal:
        problems.extend(differences)
    for key in ('recoveryAsCollision', 'collideSeparationRay'):
        if result.get(key) is not operands[key]:
            problems.append(key)
    if result.get('excludeBodies') != [] or result.get('excludeObjects') != []:
        problems.append('exclusions')
    if result.get('testOnly', True) is not True:
        problems.append('testOnly')
    for key in ('travel', 'remainder'):
        if not vec(result.get(key)):
            problems.append(key)
    safe, unsafe = result.get('safeFraction'), result.get('unsafeFraction')
    if not num(safe) or not num(unsafe) or not 0 <= safe <= unsafe <= 1:
        problems.append('fractions')
    contacts = result.get('contacts')
    if not isinstance(contacts, list) or len(contacts) == 0 or len(contacts) >= max_contacts:
        problems.append('contact_count')
        return not problems, problems
    for contact in contacts:
        if not isinstance(contact, dict):
            problems.append('contact_schema')
            break
        if not integer(contact.get('colliderRid')) or contact['colliderRid'] != target_rid:
            problems.append('collider_rid')
        if contact.get('colliderShape') != target_shape or contact.get('localShape') != local_shape:
            problems.append('support_shape')
        if not vec(contact.get('point')) or not vec(contact.get('normal')):
            problems.append('contact_geometry')
            break
        if abs(length3(contact['normal']) - 1.0) >= LIMIT:
            problems.append('normal_length')
        if not zero(contact.get('velocity')):
            problems.append('collider_velocity')
        if not num(contact.get('depth')) or contact['depth'] < 0:
            problems.append('contact_depth')
        if floor_angle is not None and contact['normal'][1] < math.cos(floor_angle):
            problems.append('normal_angle')
        if plane_y is not None and epsilon is not None and abs(contact['point'][1] - plane_y) > epsilon:
            problems.append('contact_plane')
    return not problems, problems
