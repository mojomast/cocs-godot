"""Receipt composition. Pure assembly from two bounded case records.

This module writes nothing and launches nothing. It exists so the producer and
the validator cannot disagree by accident: a receipt is exactly the two case
records the driver produced, plus the fixed qualification fields and the hash
bindings. Any divergence from the frozen history is carried into
``unexpectedChangedOutcomes`` rather than removed.
"""
from . import evidence
from . import policy


class CompositionError(ValueError):
    """The two case records cannot be composed into a receipt."""


def compose(records, *, source_hash, grant_hash, engine_hash, historical=None):
    """Assemble the receipt for a completed two-case campaign."""
    if not isinstance(records, list) or len(records) != policy.CASE_COUNT:
        raise CompositionError('exactly two case records are required')
    unexpected = evidence.unexpected_summary({'records': records})
    if unexpected is None:
        raise CompositionError('case records are malformed')
    agrees = not unexpected
    digest = evidence.records_digest(records)
    if digest is None:
        raise CompositionError('case records are not canonically serializable')
    return {
        'phase': policy.PHASE,
        'mode': policy.MODE,
        'group': policy.GROUP,
        'scope': policy.SCOPE,
        'sourceSha256': source_hash,
        'grantSha256': grant_hash,
        'engineSha256': engine_hash,
        'failed': False,
        'contractHeld': True,
        'positiveAdmission': False,
        'nativeStepAdmission': False,
        'productionPromotion': False,
        'candidateMapWalks': 0,
        'authority': 'none-source-only',
        'engineInvocations': 0,
        'caseCount': policy.CASE_COUNT,
        'executableObservationCount': policy.EXECUTED_OBSERVATIONS,
        'omittedObservationCount': policy.OMITTED_OBSERVATIONS,
        'candidateResponseBudget': policy.CANDIDATE_RESPONSE_BUDGET,
        'exactZeroMotionOmitted': True,
        'zeroMotionRequestsExecuted': 0,
        'epsilonSubstitutionUsed': False,
        'unexpectedChangedOutcomes': unexpected,
        'guardOutcomesAgreeWithHistory': agrees,
        'recordsSha256': digest,
        'operationalNeutralityProven': False,
        'hiddenStateUnaffectedProven': False,
        'queryStateEqualityProvesCacheNeutrality': False,
        'backendImplementationVerified': False,
        'parentInternalCallsTraced': False,
        'physicalCallCounts': None,
        'nativeReadiness': {'ready': False,
                            'blockingReasons': list(policy.NATIVE_READINESS_BLOCKERS)},
        'records': records,
    }


def assert_receipt(receipt, *, source_hash, grant_hash, engine_hash, historical):
    """Compose, then refuse to return a receipt the validator rejects.

    The receipt records every field, but the driver does not know which fields
    the validator reads, so a disagreement would otherwise surface only as a
    puzzling test failure. Naming the failing case makes the next debugging step
    obvious without weakening the check.
    """
    if evidence.receipt(receipt, source_hash=source_hash, grant_hash=grant_hash,
                        engine_hash=engine_hash, historical=historical):
        return receipt
    for index, (case_id, spec) in enumerate(zip(policy.CASES, policy.canonical())):
        if not evidence.record(receipt['records'][index], case_id, spec,
                               historical['cases'][case_id]):
            raise CompositionError('case record failed validation: ' + case_id)
    raise CompositionError('composed receipt failed whole-receipt validation')
