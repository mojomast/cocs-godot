"""Frozen AM historical reference for the two authorized comparison cases.

Read-only and derived, never retyped. The reference is extracted from the
approved support-normal diagnosis export, so a change to that artifact is a pin
failure rather than a silent re-baseline. Nothing here is a prediction, a
fixture value or a substitute: a fresh measurement may disagree with these
numbers, and the disagreement is what the comparison exists to report.
"""
import math
from pathlib import Path

from . import seals

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]

#: Reviewed derived export of the AM failure operands (support-normal diagnosis).
DIAGNOSIS_EXPORT = 'tools/godot-multiplayer/new-maps/walker-support-normal-diagnosis/comparison.json'
DIAGNOSIS_EXPORT_SHA256 = 'b2a40dd21ee67d484a678be91e90824758c5a94fad601011cf757c62bfcd6392'
DIAGNOSIS_EXPORT_BYTES = 93728
#: Identity of the approved diagnosis delivery this package builds on.
DIAGNOSIS_SOURCE_RECEIPT = 'tools/godot-multiplayer/new-maps/walker-support-normal-diagnosis/source-receipt.json'
DIAGNOSIS_SOURCE_RECEIPT_SHA256 = '25382b4dd0d51b1e671a97a1478bb8bee5daaf0fff305ea024016d2c94082c40'
#: The frozen AM native receipt the export was derived from.
AM_NATIVE_SHA256 = '779b00c88f53d6b4fcb9b171844769ffc2133e2d11c0bf3300419861b3a81a57'


class HistoryError(ValueError):
    """Raised when the frozen history cannot be reproduced exactly."""


def _spec_key(spec):
    return (round(float(spec['radius']), 6), round(float(spec['rise']), 6),
            round(math.degrees(float(spec['yaw'])), 6))


def load_export(root=ROOT):
    """Verify the diagnosis export identity, then return the parsed table."""
    path = seals.relative(root, DIAGNOSIS_EXPORT)
    if seals.sha(path) != DIAGNOSIS_EXPORT_SHA256 or path.stat().st_size != DIAGNOSIS_EXPORT_BYTES:
        raise HistoryError('approved diagnosis export drift')
    receipt = seals.relative(root, DIAGNOSIS_SOURCE_RECEIPT)
    if seals.sha(receipt) != DIAGNOSIS_SOURCE_RECEIPT_SHA256:
        raise HistoryError('approved diagnosis source receipt drift')
    export = seals.load(path)
    if export.get('nativeSha256') != AM_NATIVE_SHA256:
        raise HistoryError('diagnosis export no longer binds the AM native receipt')
    if export.get('backendImplementationVerified') is not False or export.get('physicalCallCounts') is not None:
        raise HistoryError('diagnosis qualification fields changed')
    return export


def reference(case_ids, specs, *, root=ROOT):
    """Historical record per authorized case, keyed by case id.

    ``case_ids`` and ``specs`` are the canonical pair from :mod:`policy`, so the
    history cannot be bound to a case this package is not allowed to run.
    """
    export = load_export(root)
    applications = export['applications']
    table = {}
    for case_id, spec in zip(case_ids, specs):
        key = _spec_key(spec)
        matches = [a for a in applications if _spec_key(a['spec']) == key]
        if len(matches) != 1:
            raise HistoryError('expected exactly one AM application for ' + case_id)
        application = matches[0]
        guard = application['queries'][-1]
        if guard['label'] != 'fresh-guard-down32':
            raise HistoryError('fresh guard operand missing for ' + case_id)
        raw = guard['rawRequestResponse']
        normal = guard['contactAnalysis'][0]['normalAnalysis']
        if application.get('preflightAtPredictedEndpointRecorded') is not False:
            raise HistoryError('pre-UP predicted-endpoint observation already recorded for ' + case_id)
        table[case_id] = {
            'caseId': case_id,
            'amCaseIndex': application['caseIndex'],
            'amFrame': application['frame'],
            'guardPassed': application['guardPassed'],
            'guardReason': application['guardReason'],
            'candidateFaultExpected': '' if application['guardPassed'] else application['guardReason'],
            'freshGuardSupportName': raw['name'],
            'freshGuardMotion': list(raw['motion']),
            'freshGuardMargin': raw['margin'],
            'freshGuardMaxCollisions': raw['maxCollisions'],
            'freshGuardRecoveryAsCollision': raw['recoveryAsCollision'],
            'freshGuardCollideSeparationRay': raw['collideSeparationRay'],
            'freshGuardNormalAngleDegrees': normal['rawDotAngleDegrees'],
            'endpointError': application['endpointError'],
            'epsilon': application['epsilon'],
            'preUpPredictedEndpointRecorded': False,
            'qualification': ('Historical AM operands, read-only. A fresh measurement may '
                              'legitimately disagree; divergence is reported, never forced '
                              'onto these values.'),
        }
    return {
        'cases': table,
        'amNativeSha256': AM_NATIVE_SHA256,
        'amWholePositiveOutcome': export['outcome'],
        'amGroupQualification': export['groupsQualification'],
        'amWholePositiveFailed': True,
        'amVerifiedLiftsForFailureCase': 0,
        'unrunPositiveCase': '.42/.18/+45',
        'qualification': ('Historical AM operands, read-only. A fresh measurement may '
                          'legitimately disagree; divergence is reported, never forced '
                          'onto these values. The per-case table carries the same '
                          'qualification so a single entry cannot be read alone.'),
    }


#: Field name in a recorded guard -> field name in the frozen history table.
GUARD_FIELDS = (('reason', 'guardReason'), ('passed', 'guardPassed'),
                ('candidateFault', 'candidateFaultExpected'))


def agree(case_id, historical, guard):
    """Compare a recorded guard against history without rewriting either side.

    The comparison is on the guard's *decision* only -- its pass flag, its reason
    and the candidate fault it produced. It is deliberately not a comparison of
    observed normals: the whole point of the campaign is that the fresh query may
    return a different normal than AM did, and treating that as a divergence would
    report the measurement's finding as if it were a contract violation.
    """
    if not isinstance(guard, dict):
        return False, {'reason': 'guard_record_missing'}
    if guard.get('caseId') not in (None, case_id):
        return False, {'field': 'caseId', 'historical': case_id, 'observed': guard.get('caseId')}
    for observed_field, historical_field in GUARD_FIELDS:
        if guard.get(observed_field) != historical[historical_field]:
            return False, {'field': observed_field, 'historical': historical[historical_field],
                           'observed': guard.get(observed_field)}
    return True, None
