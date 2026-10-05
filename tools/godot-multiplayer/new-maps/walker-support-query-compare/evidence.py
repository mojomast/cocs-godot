"""Fail-closed validation of a bounded support-query comparison receipt.

Every predicate here returns a boolean and swallows malformed input rather than
raising, so a validator call can never be turned into a pass by an exception. It
checks structure, ordering, counters and qualifications -- never physics. A
returned normal is not interpreted; the package records it and reports it.

Two things this validator deliberately does *not* do:

* it does not decide whether support exists, or whether an observed normal is
  acceptable -- that is the unchanged guard's job and it is preserved verbatim;
* it does not treat equal recorded body state around an observation as proof that
  caches or other hidden state were unaffected. Those fields must be present and
  explicitly false, and ``queryStateEqualityProvesCacheNeutrality`` is required
  to stay false in the receipt itself.
"""
import hashlib
import json
import math

from . import hook
from . import policy

MATCHED_OPERANDS = ('from', 'motion', 'margin', 'maxCollisions', 'recoveryAsCollision',
                    'collideSeparationRay', 'bodyRid', 'excludeBodies', 'excludeObjects')


def _num(value):
    return type(value) in (int, float) and math.isfinite(value)


def _bool(value):
    return type(value) is bool


def _observation(row, ordinal, site, issuer, *, require_from=None):
    """Structural validation of one observation.

    Note what is deliberately absent: the strict46 degree support predicate. This
    package measures the normal, it does not judge it. Applying the guard's own
    angle threshold here would make the validator reject the very failure AM
    recorded and this campaign exists to re-observe -- the recorded angle is
    checked for finiteness and consistency with the normal, and reported.
    """
    if not isinstance(row, dict) or set(row) != policy.OBSERVATION_KEYS:
        return False
    if row['ordinal'] != ordinal or row['site'] != site or row['issuedBy'] != issuer:
        return False
    if not isinstance(row['qualification'], str) or not row['qualification']:
        return False
    if row['recordedBeforeUpStep'] is not (ordinal == 1):
        return False
    if row['issuedAfterUpStep'] is not (ordinal != 1):
        return False
    if row['queryStateEqual'] is not True:
        return False
    request, result = row['request'], row['result']
    if not isinstance(request, dict) or not isinstance(result, dict):
        return False
    if not isinstance(request.get('name'), str) or request['name'] != result.get('name'):
        return False
    if not hook.transform(request.get('from')):
        return False
    if request.get('maxCollisions') != hook.MAX_CONTACTS:
        return False
    if request.get('recoveryAsCollision') is not True or request.get('collideSeparationRay') is not True:
        return False
    if request.get('excludeBodies') != [] or request.get('excludeObjects') != []:
        return False
    if request.get('testOnly', True) is not True:
        return False
    if not _num(request.get('margin')) or request['margin'] < 0:
        return False
    if not hook.vec(request.get('motion')) or hook.zero(request['motion']):
        return False
    if abs(request['motion'][1] - (-(request['margin'] + hook.LIMIT))) > hook.OPERAND_EPSILON:
        return False
    if not hook.integer(request.get('bodyRid')) or request['bodyRid'] <= 0:
        return False
    if not hook.integer(result.get('maxCollisions')) or result['maxCollisions'] != hook.MAX_CONTACTS:
        return False
    if result.get('recoveryAsCollision') is not True or result.get('collideSeparationRay') is not True:
        return False
    if result.get('excludeBodies') != [] or result.get('excludeObjects') != []:
        return False
    if result.get('testOnly', True) is not True:
        return False
    if result.get('hit') not in (True, False) or result.get('validResult') not in (True, False):
        return False
    if not _num(result.get('margin')) or abs(result['margin'] - request['margin']) > hook.OPERAND_EPSILON:
        return False
    equal, _ = hook.operand_equal(request, result, keys=MATCHED_OPERANDS)
    if not equal:
        return False
    if require_from is not None and \
            hook.distance(request['from']['origin'], require_from) != 0.0:
        return False
    for key in ('travel', 'remainder'):
        if not hook.vec(result.get(key)):
            return False
    safe, unsafe = result.get('safeFraction'), result.get('unsafeFraction')
    if not _num(safe) or not _num(unsafe) or not 0 <= safe <= unsafe <= 1:
        return False
    contacts = result.get('contacts')
    if not isinstance(contacts, list) or not contacts or len(contacts) >= hook.MAX_CONTACTS:
        return False
    for contact in contacts:
        if not isinstance(contact, dict):
            return False
        if not hook.integer(contact.get('colliderRid')) or contact['colliderRid'] <= 0:
            return False
        if contact.get('colliderShape') != 0 or contact.get('localShape') != 0:
            return False
        if not hook.vec(contact.get('point')) or not hook.vec(contact.get('normal')):
            return False
        if abs(hook.length3(contact['normal']) - 1.0) >= hook.LIMIT:
            return False
        if not hook.zero(contact.get('velocity')) or not _num(contact.get('depth')):
            return False
        if contact['depth'] < 0:
            return False
    return True


def _frozen_operands(row, historical, observations):
    """The cross-observation proof the duplicate's honesty rests on.

    Three independent checks, each of which must pass:

    1. the record carries exactly one well-formed frozen-operand tuple
       (:func:`hook.frozen_tuple`);
    2. that tuple is anchored: its design-frozen constants equal the SHA256-pinned AM
       guard's, and its body RID equals the RID in the record's own AM binding --
       so the tuple cannot be re-tuned inside the receipt;
    3. all three executed requests carry exactly that tuple, and agree with each other
       pairwise (:func:`hook.operands_unchanged`, which checks both, so the guarantee
       does not rest on the tuple anchor alone).

    Without (2) and (3) a receipt could re-tune any one of the six forged constants
    the independent review demonstrated -- or all of them at once, consistently -- and
    still validate, because each observation is otherwise self-consistent in
    isolation. Any mismatch fails closed.
    """
    if not isinstance(historical, dict):
        return False
    try:
        frozen = hook.frozen_tuple(row['frozenOperands'])
    except (hook.HookError, KeyError, TypeError):
        return False
    approved = historical.get('amFrozenOperands')
    if hook.design_frozen(approved) is None:
        return False
    equal, _ = hook.operand_equal(approved, frozen, keys=hook.DESIGN_FROZEN_CONSTANTS)
    if not equal:
        return False
    # The record's own history binding must carry the same AM tuple the validator
    # was handed, so a receipt cannot substitute one approved set for another.
    bound = row['history'].get('amFrozenOperands') if isinstance(row.get('history'), dict) else None
    if hook.design_frozen(bound) is None:
        return False
    equal, _ = hook.operand_equal(approved, bound, keys=hook.CONSTANTS)
    if not equal:
        return False
    # ``bodyRid`` is the body under test, not the support RID, so it is anchored by
    # the AM binding too rather than left free.
    if bound['bodyRid'] != frozen['bodyRid']:
        return False
    requests = tuple(observation['request'] for observation in observations)
    equal, _ = hook.operands_unchanged(frozen, *requests)
    return equal


def _omission(row, ordinal, site):
    if not isinstance(row, dict) or set(row) != policy.OMISSION_KEYS:
        return False
    if row['ordinal'] != ordinal or row['site'] != site:
        return False
    if row['omitted'] is not True or row['executed'] is not False:
        return False
    if row['substitutionRefused'] is not True or row['substitutedMotion'] is not None:
        return False
    if not hook.vec(row['requestedMotion']) or not hook.exact_zero(row['requestedMotion']):
        return False
    if row['reason'] != hook.OMISSION_REASON:
        return False
    return isinstance(row['sourceBasis'], str) and isinstance(row['qualification'], str)


def _plan(row):
    """Validate the recorded plan geometry.

    ``predictedEndpoint`` is the guard's own endpoint (``raised.origin +
    horizontalBudget``). ``apply_floor_snap``'s Y-only projection means its height
    legitimately differs from ``expectedFinal``, so only the horizontal agreement
    is required to hold within the guard's epsilon; the vertical offset is
    recorded explicitly instead of being demanded to zero.
    """
    plan = row.get('plan')
    if not isinstance(plan, dict) or set(plan) != policy.PLAN_KEYS:
        return False
    if not hook.transform(plan['from']) or not hook.transform(plan['raised']):
        return False
    for key in ('horizontalBudget', 'predictedEndpoint', 'expectedFinal', 'upMotion'):
        if not hook.vec(plan[key]):
            return False
    if not _num(plan['landingY']):
        return False
    if not hook.integer(plan['supportRid']) or plan['supportRid'] <= 0 or plan['supportShape'] != 0:
        return False
    if not _num(plan['epsilon']) or not 0 < plan['epsilon'] <= hook.LIMIT:
        return False
    if not isinstance(plan['predictedEndpointBasis'], str) or not plan['predictedEndpointBasis']:
        return False
    predicted = [a + b for a, b in zip(plan['raised']['origin'], plan['horizontalBudget'])]
    if hook.distance(predicted, plan['predictedEndpoint']) > plan['epsilon']:
        return False
    horizontal = math.hypot(plan['expectedFinal'][0] - plan['predictedEndpoint'][0],
                            plan['expectedFinal'][2] - plan['predictedEndpoint'][2])
    if horizontal != plan['horizontalAgreementError'] or horizontal > plan['epsilon']:
        return False
    if plan['verticalOffsetFromPredictedEndpoint'] != \
            plan['expectedFinal'][1] - plan['predictedEndpoint'][1]:
        return False
    if hook.distance(plan['from']['origin'], plan['expectedFinal']) <= plan['epsilon']:
        return False
    return hook.zero(plan['upMotion']) or plan['upMotion'][1] > 0


def record(row, case_id, spec, historical):
    """Validate one case record in full. Returns a boolean, never raises.

    ``historical`` is the frozen AM table for this case. It is consulted only to
    confirm that the recorded history *binding* is the right one and that the
    declared agreement flag is arithmetically consistent with the recorded guard;
    it is never used to overwrite or second-guess an observed outcome.
    """
    try:
        if not isinstance(row, dict) or set(row) != policy.RECORD_KEYS:
            return False
        if row['caseId'] != case_id or row['caseIndex'] != policy.CASES.index(case_id):
            return False
        if not policy.spec_equal(row['spec'], spec):
            return False
        if row['status'] != 'stopped_after_duplicate_observation':
            return False
        if row['usedFirstEligibleTransition'] is not True:
            return False
        # Nonnegative integer and nonzero: a transition index of zero would mean the
        # very first frame, which cannot be an *eligible* riser transition.
        if not hook.integer(row['firstEligibleTransition']) or row['firstEligibleTransition'] <= 0:
            return False
        if list(row['eventLog']) != list(policy.EVENT_LOG):
            return False
        if row['stoppedAfterDuplicateObservation'] is not True:
            return False
        if row['subsequentMovementPossible'] is not False:
            return False
        for key in ('candidateResponses', 'appliedUpCount', 'parentResponseCount'):
            if row[key] != policy.CANDIDATE_RESPONSE_BUDGET:
                return False
        for key in ('subsequentMovementResponses', 'retries', 'normalSelections',
                    'acceptanceSubstitutions'):
            if row[key] != 0:
                return False
        if not _plan(row):
            return False
        plan = row['plan']
        observations = row['observations']
        if not isinstance(observations, list) or len(observations) != policy.EXECUTED_OBSERVATIONS:
            return False
        if [o['ordinal'] if isinstance(o, dict) else None for o in observations] != [1, 3, 4]:
            return False
        if observations[0]['result'].get('name') != hook.PRE_UP_NAME:
            return False
        if not _observation(observations[0], 1, 'pre_up_predicted_endpoint', 'bounded_observer',
                            require_from=plan['predictedEndpoint']):
            return False
        if observations[1]['result'].get('name') != hook.GUARD_NAME:
            return False
        if observations[1]['request'] is not observations[1]['result']:
            return False
        if observations[1]['bodyStateBefore'] is not None or observations[1]['bodyStateAfter'] is not None:
            return False
        if not _observation(observations[1], 3, 'guard_actual_final_state',
                            'unchanged_response_guard'):
            return False
        # The guard asks at the *actual* final state, which is exactly what its own
        # endpoint check already proved equals expectedFinal within epsilon.
        if hook.distance(observations[1]['request']['from']['origin'],
                         plan['expectedFinal']) > plan['epsilon']:
            return False
        if observations[2]['result'].get('name') != hook.DUPLICATE_NAME:
            return False
        if not _observation(observations[2], 4, 'duplicate_actual_final_state',
                            'bounded_observer',
                            require_from=observations[1]['request']['from']['origin']):
            return False
        if not _frozen_operands(row, historical, observations):
            return False
        equality = row['queryStateEquality']
        if not isinstance(equality, list) or len(equality) != policy.EXECUTED_OBSERVATIONS:
            return False
        if [entry.get('site') for entry in equality] != ['pre_up_predicted_endpoint',
                                                         'guard_actual_final_state',
                                                         'duplicate_actual_final_state']:
            return False
        if any(entry.get('queryStateEqual') is not True for entry in equality):
            return False
        omissions = row['omissions']
        if not isinstance(omissions, list) or len(omissions) != policy.OMITTED_OBSERVATIONS:
            return False
        if not _omission(omissions[0], 2, 'pre_up_predicted_endpoint'):
            return False
        if not _omission(omissions[1], 5, 'post_guard_actual_final_state'):
            return False
        guard = row['guard']
        if not isinstance(guard, dict) or set(guard) != policy.GUARD_KEYS:
            return False
        if not _bool(guard['passed']) or not isinstance(guard['reason'], str):
            return False
        if not isinstance(guard['candidateFault'], str) or guard['preservedIntact'] is not True:
            return False
        if guard['candidateFault'] != ('' if guard['passed'] else guard['reason']):
            return False
        history_row = row['history']
        if not isinstance(history_row, dict):
            return False
        if not hook.integer(history_row.get('amCaseIndex')) or not hook.integer(history_row.get('amFrame')):
            return False
        if history_row['amCaseIndex'] != historical['amCaseIndex'] or \
                history_row['amFrame'] != historical['amFrame']:
            return False
        # The recorded AM binding must be exactly the approved table's entry, so a
        # receipt cannot swap one case's frozen operands in for another's.
        equal, _ = hook.operand_equal(historical['amFrozenOperands'],
                                      history_row.get('amFrozenOperands'), keys=hook.CONSTANTS)
        if not equal:
            return False
        if history_row['preUpPredictedEndpointRecordedInAM'] is not False:
            return False
        if history_row['historicalGuardReason'] != historical['guardReason']:
            return False
        agrees = history_row.get('agreesWithHistory')
        if not _bool(agrees):
            return False
        expected_agrees = (guard['reason'] == historical['guardReason']
                           and guard['passed'] == historical['guardPassed']
                           and guard['candidateFault'] == historical['candidateFaultExpected'])
        if agrees is not expected_agrees:
            return False
        unexpected = row['unexpectedOutcome']
        if agrees:
            if unexpected is not None:
                return False
        else:
            if not isinstance(unexpected, dict) or set(unexpected) != {'caseId', 'divergence'}:
                return False
            if unexpected['caseId'] != case_id:
                return False
            divergence = unexpected['divergence']
            if not isinstance(divergence, dict) or not divergence:
                return False
            if not set(divergence) <= {'field', 'historical', 'observed', 'reason'}:
                return False
        return True
    except (KeyError, TypeError, ValueError, IndexError, AttributeError, OverflowError,
            ArithmeticError):
        return False


def receipt(value, *, source_hash, grant_hash, engine_hash, historical):
    """Validate a whole comparison receipt against the frozen history.

    ``guardOutcomesAgreeWithHistory`` is allowed to be either True or False; what
    is required is that the flag is *true to what was recorded*. A receipt that
    reports a divergent guard and then claims agreement, or claims divergence
    silently, is rejected.
    """
    try:
        if not isinstance(value, dict) or set(value) != policy.RECEIPT_KEYS:
            return False
        if value['phase'] != policy.PHASE or value['mode'] != policy.MODE:
            return False
        if value['group'] != policy.GROUP or value['scope'] != policy.SCOPE:
            return False
        if (value['sourceSha256'], value['grantSha256'], value['engineSha256']) != \
                (source_hash, grant_hash, engine_hash):
            return False
        for key in ('positiveAdmission', 'nativeStepAdmission', 'productionPromotion'):
            if value[key] is not False:
                return False
        if value['failed'] is not False or value['contractHeld'] is not True:
            return False
        if not _bool(value['guardOutcomesAgreeWithHistory']):
            return False
        if value['candidateMapWalks'] != 0 or value['engineInvocations'] != 0:
            return False
        if value['authority'] != 'none-source-only':
            return False
        if value['caseCount'] != policy.CASE_COUNT:
            return False
        if value['executableObservationCount'] != policy.EXECUTED_OBSERVATIONS:
            return False
        if value['omittedObservationCount'] != policy.OMITTED_OBSERVATIONS:
            return False
        if value['candidateResponseBudget'] != policy.CANDIDATE_RESPONSE_BUDGET:
            return False
        if value['exactZeroMotionOmitted'] is not True:
            return False
        if value['zeroMotionRequestsExecuted'] != 0 or value['epsilonSubstitutionUsed'] is not False:
            return False
        for key in ('operationalNeutralityProven', 'hiddenStateUnaffectedProven',
                    'queryStateEqualityProvesCacheNeutrality', 'backendImplementationVerified',
                    'parentInternalCallsTraced'):
            if value[key] is not False:
                return False
        if value['physicalCallCounts'] is not None:
            return False
        frozen_table = value['frozenOperands']
        if not isinstance(frozen_table, dict) or set(frozen_table) != set(policy.CASES):
            return False
        for row in value['records'] if isinstance(value['records'], list) else []:
            case_id = row.get('caseId') if isinstance(row, dict) else None
            if case_id in frozen_table and \
                    not hook.operand_equal(frozen_table[case_id], row.get('frozenOperands'))[0]:
                return False
        readiness = value['nativeReadiness']
        if not isinstance(readiness, dict) or set(readiness) != {'ready', 'blockingReasons'}:
            return False
        if readiness['ready'] is not False:
            return False
        if readiness['blockingReasons'] != list(policy.NATIVE_READINESS_BLOCKERS):
            return False
        rows = value['records']
        if not isinstance(rows, list) or len(rows) != policy.CASE_COUNT:
            return False
        agrees = []
        for index, (case_id, spec) in enumerate(zip(policy.CASES, policy.canonical())):
            if not record(rows[index], case_id, spec, historical['cases'][case_id]):
                return False
            agrees.append(rows[index]['history']['agreesWithHistory'])
        if value['guardOutcomesAgreeWithHistory'] is not all(agrees):
            return False
        if value['unexpectedChangedOutcomes'] != [row['caseId'] for row, flag in zip(rows, agrees)
                                                 if not flag]:
            return False
        # The digest closes the gap the per-field predicates leave open: it binds
        # every recorded byte of both case records, including fields whose value is
        # legitimately free (an observed normal, for example).
        if value['recordsSha256'] != records_digest(rows):
            return False
        return True
    except (KeyError, TypeError, ValueError, IndexError, AttributeError, OverflowError,
            ArithmeticError):
        return False


def records_digest(records):
    """SHA256 over the canonical serialization of the two case records.

    Canonical means sorted keys, no insignificant whitespace and ``allow_nan``
    disabled, so the digest is a pure function of the recorded content: any edit
    to any field -- including one the structural predicates would not otherwise
    notice, such as a contact normal -- changes it.
    """
    try:
        return hashlib.sha256(
            json.dumps(records, sort_keys=True, separators=(',', ':'),
                       allow_nan=False).encode()).hexdigest()
    except (TypeError, ValueError):
        return None


def unexpected_summary(value):
    """Report, never repair: the case ids whose guard outcome diverged from history."""
    try:
        return [row['caseId'] for row in value['records']
                if not row['history']['agreesWithHistory']]
    except (KeyError, TypeError, AttributeError):
        return None
