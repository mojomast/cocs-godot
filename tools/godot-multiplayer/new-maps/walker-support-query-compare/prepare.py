"""Write-once offline source record. No grant writer, no stage, no engine.

``build`` seals the predetermined comparison proposal -- the two authorized
cases, the frozen down32 operand constants, the two omitted exact-zero
observations and the frozen AM history -- into a single exclusive-create record
plus a seal manifest. Nothing is staged into ``godot/`` and no grant is created,
so this package cannot leave a runnable native fixture behind.

``validate_record`` is fail-closed: exact contract equality, exact seal
verification, no unexpected files and no symlinks. It refuses to accept a record
whose attempt name, case set, case order or frozen constants were changed.
"""
import argparse
import re
from pathlib import Path

from . import history
from . import hook
from . import policy
from . import seals

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
ATTEMPT = re.compile(r'support-query-compare-[a-z0-9]+(?:-[a-z0-9]+)*')
RECORD_NAME = 'source-record.json'
MANIFEST_NAME = 'seal-manifest.json'
#: The single seal role in this package. Drift is rejected by ``validate_record``.
RECORD_ROLE = 'support-query-compare-source-record'
#: Frozen source references this package's contract is derived from. Verified by
#: ``verify_references``; drift here means the contract below is stale.
REFERENCES = {
    'godot/tests/walker_step_up/response_guard.gd':
        'ff242f1c352755e3655666440731115911b59dc431f0ec7c37807e8c8ec281b0',
    'godot/tests/walker_step_up/sweep_proposal.gd':
        'b253464820a84d8de7e1cfc5abf7d3852f392e055ac6e71d42ce6a678d538d41',
    'godot/tests/walker_parity_admission/candidate.gd':
        '0aae2ac30347e21286e09fc1b8f1a6b8937f37aef447d99af083a12700261314',
    'godot/tests/walker_parity_response/planner.gd':
        '7dadd0a3fb018de12afe867ff5a688663347e99bd6335f92353519d136e76b31',
    'godot/exploration/walker.gd':
        '3015de90c925eb86093bb41086fe0725c3f6be9dbb23e3abdfb8b5d43dc440d8',
}
DESIGN_REVIEW = 'port/finish/map-variety/WALKER_SUPPORT_QUERY_DESIGN_REVIEW.md'
DESIGN_REVIEW_SHA256 = '647e9302889dc4b99bfb85ba05ad1a2e1167072aba0753fce04e25ea478797d4'
DESIGN_REFERENCE = ('godot_space_3d.cpp:698-699 divides motion by its length without a zero '
                    'check; Vector3 division is componentwise and the direction reaches '
                    'collision-distance solving, so exact-zero semantics are not established')
ATTEMPT_MAX = 64


#: The one file a supervisor may add to a validated source record: its refusal.
#: It is evidence of *non*-execution, and its presence is expected, so it is
#: allowed while any other extra file remains a hard error.
REFUSAL_FILENAME = 'native-refusal.json'


class PrepareError(ValueError):
    """The source record cannot be built or does not validate."""


def verify_references(root=ROOT):
    """Every frozen reference this contract was derived from must be unchanged.

    A missing or unreadable reference is reported as :class:`PrepareError` too,
    so a caller can rely on one exception type for "this contract's basis is not
    intact" rather than having to catch OS errors separately.
    """
    verified = {}
    try:
        for name, expected in REFERENCES.items():
            path = seals.relative(root, name)
            if seals.sha(path) != expected:
                raise PrepareError('frozen source reference drift: ' + name)
            verified[name] = expected
        review = seals.relative(root, DESIGN_REVIEW)
        if seals.sha(review) != DESIGN_REVIEW_SHA256:
            raise PrepareError('approved design review drift')
        verified[DESIGN_REVIEW] = DESIGN_REVIEW_SHA256
    except (OSError, ValueError) as error:
        if isinstance(error, PrepareError):
            raise
        raise PrepareError('frozen reference unreadable: %r' % (error,)) from error
    return verified


def namespace(attempt):
    if not isinstance(attempt, str) or len(attempt) > ATTEMPT_MAX or not ATTEMPT.fullmatch(attempt):
        raise PrepareError('canonical lowercase attempt name required')
    return attempt


def _reject_engine_tree(dest, root=ROOT):
    """This source package may never place anything inside the Godot project tree."""
    engine_tree = (Path(root) / 'godot').resolve()
    if Path(dest).resolve().is_relative_to(engine_tree):
        raise PrepareError('a source-only record may not be staged into the Godot project tree')


def contract(attempt, *, params=None, root=ROOT):
    """The exact, deterministic source contract. No clock, no randomness."""
    namespace(attempt)
    references = verify_references(root)
    frozen_history = history.reference(policy.case_ids(), policy.canonical(), root=root)
    params = params or {'margin': 0.0199999995529652}
    proposal_shape = {
        'frozenConstants': hook.frozen_operands(params, body_rid=1),
        'preUpRequestName': hook.PRE_UP_NAME,
        'duplicateRequestName': hook.DUPLICATE_NAME,
        'guardRequestName': hook.GUARD_NAME,
        'observationSites': [{'ordinal': ordinal, 'site': site, 'disposition': disposition}
                             for ordinal, site, disposition in hook.SITES],
        'omissionReason': hook.OMISSION_REASON,
        'omissionBasis': hook.OMISSION_BASIS,
        'epsilonSubstitutionUsed': False,
        'limit': hook.LIMIT,
        'maxCollisions': hook.MAX_CONTACTS,
    }
    return {
        'attempt': attempt,
        'phase': policy.PHASE,
        'mode': policy.MODE,
        'group': policy.GROUP,
        'scope': policy.SCOPE,
        'cases': policy.canonical(),
        'allowedCases': list(policy.CASES),
        'caseCount': policy.CASE_COUNT,
        'candidateResponseBudget': policy.CANDIDATE_RESPONSE_BUDGET,
        'eventOrder': list(policy.EVENT_LOG),
        'executableObservationCount': policy.EXECUTED_OBSERVATIONS,
        'omittedObservationCount': policy.OMITTED_OBSERVATIONS,
        'proposal': proposal_shape,
        'history': frozen_history,
        'references': references,
        'designBasis': DESIGN_REFERENCE,
        'engineIdentity': policy.ENGINE,
        'engineInvocations': 0,
        'grant': None,
        'autoStart': False,
        'queued': False,
        'nativeStepAdmission': False,
        'positiveAdmission': False,
        'productionPromotion': False,
        'candidateMapWalks': 0,
        'physicalCallCounts': None,
        'nativeReadiness': {'ready': False,
                            'blockingReasons': list(policy.NATIVE_READINESS_BLOCKERS)},
        'qualification': ('Source-only. Nothing here is a native result, a grant or '
                          'evidence that support is walkable.'),
    }


def build(attempt, parent, *, root=ROOT, params=None):
    """Create the write-once record and its seal manifest. Raises if either exists."""
    parent = Path(parent).absolute()
    dest = parent / namespace(attempt)
    _reject_engine_tree(dest, root)
    if parent.exists() and (parent.is_symlink() or parent.resolve() != parent):
        raise PrepareError('symlinked run parent refused')
    record = contract(attempt, params=params, root=root)
    dest.mkdir(parents=True)
    seals.write_once(dest / RECORD_NAME, record)
    manifest = seals.manifest(dest, [RECORD_NAME], role=RECORD_ROLE)
    seals.write_once(dest / MANIFEST_NAME, manifest)
    return dest


def validate_record(dest, *, root=ROOT):
    """Fail-closed validation of a written record plus its seals."""
    dest = Path(dest).absolute()
    _reject_engine_tree(dest, root)
    namespace(dest.name)
    allowed = {RECORD_NAME, MANIFEST_NAME, REFUSAL_FILENAME}
    for path in dest.rglob('*'):
        if path.is_symlink():
            raise PrepareError('symlink inside the source record refused')
        if path.is_file() and path.relative_to(dest).as_posix() not in allowed:
            raise PrepareError('unexpected file inside the source record: '
                               + path.relative_to(dest).as_posix())
    if not (dest / RECORD_NAME).is_file() or not (dest / MANIFEST_NAME).is_file():
        raise PrepareError('source record and seal manifest are both required')
    manifest = seals.load(dest / MANIFEST_NAME)
    if not isinstance(manifest, dict) or set(manifest) != {'utc', 'root', 'role', 'seals',
                                                           'sealsVerified', 'sealedBytes'}:
        raise PrepareError('exact seal manifest schema required')
    if not seals.UTC.fullmatch(manifest['utc'] or ''):
        raise PrepareError('seal manifest timestamp format required')
    if manifest['root'] != str(dest) or manifest['role'] != RECORD_ROLE:
        raise PrepareError('seal manifest root or role substitution')
    if any(entry['role'] != RECORD_ROLE for entry in manifest['seals']):
        raise PrepareError('seal entry role substitution')
    try:
        verified = seals.verify_seals(dest, manifest['seals'])
    except ValueError as error:
        raise PrepareError('seal verification failed: ' + str(error)) from error
    if verified['sealsVerified'] != manifest['sealsVerified'] or \
            verified['sealedBytes'] != manifest['sealedBytes']:
        raise PrepareError('seal manifest totals disagree with the verified seals')
    record = seals.load(dest / RECORD_NAME)
    expected = contract(dest.name, root=root)
    if record != expected:
        # Report the first differing top-level key so a reviewer editing the record
        # by hand is told which field drifted instead of only that "something" did.
        differing = sorted(k for k in set(record) | set(expected) if record.get(k) != expected.get(k))
        raise PrepareError('source record contract mismatch at: ' + ','.join(differing))
    for key in ('grant', 'autoStart', 'queued', 'nativeStepAdmission', 'positiveAdmission',
                'productionPromotion'):
        if record[key] is not False and record[key] is not None:
            raise PrepareError('explicit negative authority field required: ' + key)
    policy.validate_case_set(record['allowedCases'])
    return record


def verify_only(attempt, *, root=ROOT):
    """Read-only re-verification of an existing record. Writes nothing."""
    dest = Path(attempt)
    record = validate_record(dest, root=root)
    return {'attempt': record['attempt'], 'cases': record['allowedCases'],
            'caseCount': record['caseCount'],
            'candidateResponseBudget': record['candidateResponseBudget'],
            'engineInvocations': record['engineInvocations'],
            'nativeReadiness': record['nativeReadiness'],
            'qualification': 'Offline re-verification only; no native readiness implied.'}


def cli(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    sub = parser.add_subparsers(dest='operation', required=True)
    builder = sub.add_parser('build')
    builder.add_argument('attempt')
    builder.add_argument('--parent', required=True)
    verifier = sub.add_parser('verify')
    verifier.add_argument('record', help='path to an existing source record directory')
    args = parser.parse_args(argv)
    if args.operation == 'build':
        print(build(args.attempt, args.parent))
    else:
        print(verify_only(args.record))
    return 0


def main(argv=None):
    """CLI entry point. ``SystemExit`` is reserved for argument misuse."""
    return cli(argv)


__all__ = ['PrepareError', 'DESIGN_REFERENCE', 'MANIFEST_NAME', 'RECORD_NAME', 'RECORD_ROLE',
           'REFUSAL_FILENAME', 'build', 'cli', 'contract', 'main', 'namespace', 'validate_record',
           'verify_only', 'verify_references']
