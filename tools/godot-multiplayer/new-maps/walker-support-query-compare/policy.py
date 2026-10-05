"""Phase, case and grant allowlist. No native authority is created here.

Exactly two finite-motion cases are authorized and they are fixed here, in
canonical order. Everything that could widen the campaign -- the phase name, the
case list, the grant schema, the receipt schema -- is enumerated rather than
discovered, so a stage, driver or receipt cannot introduce a third case, a
second candidate response, a retry or a later movement.
"""
import math
import re

PHASE = 'support-query-compare-v1'
MODE = 'bounded-support-query'
GROUP = 'support-query-comparison'
SCOPE = 'support-query-observation'
#: Godot 4.5.2 identity of the AM build, pinned for binding only. This source
#: package contains no code path that executes, resolves or copies the binary.
ENGINE = '5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae'
ENGINE_MAJOR, ENGINE_MINOR, ENGINE_PATCH = 4, 5, 2

#: The two authorized cases. Order is canonical and part of every seal.
CASES = ('reference-035-015-neg45', 'failure-042-018-neg45')
CASE_COUNT = 2
#: One candidate response per case, and never a second one.
CANDIDATE_RESPONSE_BUDGET = 1
#: Executed observations per case: pre-UP, guard's own, duplicate.
EXECUTED_OBSERVATIONS = 3
#: Omitted exact-zero observations per case.
OMITTED_OBSERVATIONS = 2
#: Ordered event log a completed case must show.
EVENT_LOG = ('pre_up_observation', 'candidate_response', 'guard_observation',
             'duplicate_observation', 'stop')

GRANT_KEYS = {'phase', 'mode', 'allowedCases', 'grantId', 'authorized', 'expiresUnix',
              'sourceSha256', 'engineSha256'}
RECEIPT_KEYS = {'phase', 'mode', 'group', 'scope', 'sourceSha256', 'grantSha256', 'engineSha256',
                'failed', 'contractHeld', 'positiveAdmission', 'nativeStepAdmission',
                'productionPromotion', 'candidateMapWalks', 'authority', 'engineInvocations',
                'caseCount', 'executableObservationCount', 'omittedObservationCount',
                'candidateResponseBudget', 'exactZeroMotionOmitted', 'zeroMotionRequestsExecuted',
                'epsilonSubstitutionUsed', 'unexpectedChangedOutcomes',
                'guardOutcomesAgreeWithHistory', 'recordsSha256',
                'operationalNeutralityProven', 'hiddenStateUnaffectedProven',
                'queryStateEqualityProvesCacheNeutrality', 'backendImplementationVerified',
                'parentInternalCallsTraced', 'physicalCallCounts', 'nativeReadiness', 'records'}
RECORD_KEYS = {'caseIndex', 'caseId', 'spec', 'status', 'firstEligibleTransition',
               'usedFirstEligibleTransition', 'eventLog', 'plan', 'observations', 'omissions',
               'queryStateEquality', 'candidateResponses', 'appliedUpCount', 'parentResponseCount',
               'guard', 'history', 'unexpectedOutcome', 'subsequentMovementResponses', 'retries',
               'normalSelections', 'acceptanceSubstitutions', 'stoppedAfterDuplicateObservation',
               'subsequentMovementPossible'}
OBSERVATION_KEYS = {'ordinal', 'site', 'issuedBy', 'request', 'result', 'bodyStateBefore',
                    'bodyStateAfter', 'queryStateEqual', 'recordedBeforeUpStep',
                    'issuedAfterUpStep', 'qualification'}
OMISSION_KEYS = {'ordinal', 'site', 'requestedMotion', 'omitted', 'executed', 'substitutedMotion',
                 'substitutionRefused', 'reason', 'sourceBasis', 'qualification'}
PLAN_KEYS = {'from', 'raised', 'horizontalBudget', 'predictedEndpoint', 'expectedFinal',
             'upMotion', 'landingY', 'supportRid', 'supportShape', 'epsilon',
             'horizontalAgreementError', 'verticalOffsetFromPredictedEndpoint',
             'predictedEndpointBasis'}
GUARD_KEYS = {'passed', 'reason', 'candidateFault', 'preservedIntact'}

#: What still blocks a native run. Reported verbatim; never softened to "ready".
NATIVE_READINESS_BLOCKERS = (
    'no independent source review of this package',
    'no heavy grant exists for phase ' + PHASE,
    'no GDScript staging is implemented; the bounded driver and hook exist only as offline Python',
    'no engine-invocation path exists in this source package by design',
    'zero-motion support semantics remain undefined; those two observations stay omitted',
    'AM whole positive admission remains failed and .42/.18/+45 remains unrun',
)

#: Modules this package must never import: each one can start a process. Checked
#: against the parsed AST of every module in this package by the test suite, so
#: "no engine invocation" is a verified property rather than a promise.
FORBIDDEN_IMPORTS = ('subprocess', 'multiprocessing', 'shutil', 'pty', 'popen2', 'commands')
#: Attributes and names that must never be referenced: each one can execute code.
FORBIDDEN_REFERENCES = ('system', 'popen', 'execl', 'execle', 'execlp', 'execv', 'execve', 'spawn',
                        'fork', 'forkpty', 'run', 'call', 'check_call', 'check_output', 'Popen')


class PolicyError(ValueError):
    """Any request outside the fixed phase/case allowlist."""


def canonical():
    """The two fixed finite-motion cases, in canonical order.

    Shaped exactly like the reviewed AM positive specification so a case cannot be
    silently redefined: same radius/rise/yaw, same incline, start, goal and
    response cap. Only the two -45 degree cases are in scope.
    """
    specs = []
    for case_id, radius, rise, degrees in (('reference-035-015-neg45', .35, .15, -45.0),
                                          ('failure-042-018-neg45', .42, .18, -45.0)):
        specs.append({'caseId': case_id, 'id': str(radius) + ':' + str(degrees),
                      'radius': radius, 'rise': rise, 'yaw': math.radians(degrees),
                      'incline': 0.0, 'start': -1.0, 'goal': 1.0, 'maxResponses': 240})
    return specs


def case_ids():
    return tuple(spec['caseId'] for spec in canonical())


def spec_for(case_id):
    for spec in canonical():
        if spec['caseId'] == case_id:
            return spec
    raise PolicyError('case not authorized: ' + repr(case_id))


def spec_equal(a, b):
    if not isinstance(a, dict) or set(a) != set(b):
        return False
    for key, value in b.items():
        if isinstance(value, float):
            if type(a.get(key)) not in (int, float) or not math.isfinite(a[key]) or a[key] != value:
                return False
        elif a.get(key) != value:
            return False
    return True


def case_allowed(case_id):
    return case_id in CASES


def validate_case_set(case_ids_in):
    """The executed case set must be exactly the two authorized cases, in order."""
    if not isinstance(case_ids_in, (list, tuple)):
        raise PolicyError('case list required')
    if len(case_ids_in) != CASE_COUNT:
        raise PolicyError('exactly %d cases are authorized; got %d' % (CASE_COUNT, len(case_ids_in)))
    if tuple(case_ids_in) != CASES:
        raise PolicyError('canonical case set and order required')
    return list(case_ids_in)


def validate_grant(grant, *, case_ids_in, source_hash, engine_hash, now):
    """Fail-closed grant validation. Raises; never returns a partially valid grant."""
    if engine_hash != ENGINE:
        raise PolicyError('pinned engine identity required')
    if not isinstance(grant, dict) or set(grant) != GRANT_KEYS:
        raise PolicyError('exact grant schema required')
    if grant['phase'] != PHASE or grant['mode'] != MODE:
        raise PolicyError('synthetic phase and mode required')
    validate_case_set(grant['allowedCases'])
    if tuple(grant['allowedCases']) != CASES or list(case_ids_in) != list(CASES):
        raise PolicyError('grant and request must authorize the same two cases')
    if grant['authorized'] is not True:
        raise PolicyError('explicit authorization required')
    if not isinstance(grant['grantId'], str) or not grant['grantId']:
        raise PolicyError('grant identity required')
    expiry = grant['expiresUnix']
    if type(expiry) not in (int, float) or not math.isfinite(expiry) or expiry <= now:
        raise PolicyError('finite unexpired grant required')
    for actual, expected in ((grant['sourceSha256'], source_hash), (grant['engineSha256'], engine_hash)):
        if not isinstance(actual, str) or not re.fullmatch('[a-f0-9]{64}', actual) or actual != expected:
            raise PolicyError('hash binding required')
    return grant
