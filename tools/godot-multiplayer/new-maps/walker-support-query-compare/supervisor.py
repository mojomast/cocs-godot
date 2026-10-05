"""Source-only supervisor. It records a refusal; it never launches an engine.

The approved design assigned "a new bounded driver, observational hook, seals,
validator and supervisor" for independent review, and explicitly withheld native
readiness and any grant. This module is that supervisor in its only honest form
for this deliverable: it performs the full fail-closed preflight a real
supervisor would perform -- namespace, record contract, seals, frozen
references, AM history, grant schema, hash binding, expiry -- and then refuses.

The refusal is a written, sealed, write-once record of *why* the campaign cannot
run. It is not a dry run and not a stub: this module imports no process-spawning
module at all, so there is no code path from here to an engine. ``test_supervisor``
asserts both the absence of spawning imports and that the refusal fires after
every preflight check has already passed.
"""
import argparse
from pathlib import Path

from . import history
from . import policy
from . import prepare
from . import seals

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
REFUSAL_NAME = prepare.REFUSAL_FILENAME
#: Recorded so a reviewer can see exactly what would have been attempted. This is
#: a description, not a command: nothing here is executed.
#: The argv a future supervisor would build, with named substitution slots. This is
#: a description for review, not a command: nothing here is executed, the engine
#: path and fixture path are deliberately left unsubstituted because no such stage
#: exists. ``planned_argv`` fills only the four named slots.
PLANNED_ARGV_TEMPLATE = [
    '{engine}', '--headless', '--single-threaded-scene',
    '--path', '{fixture}',
    '--script', 'res://tests/walker_support_query_compare/driver.gd', '--',
    '--group=' + policy.GROUP,
    '--mode=' + policy.MODE,
    '--case={case}',
    '--grant-id={grant_id}',
    '--grant-sha256={grant_sha256}',
    '--dependencies-sha256={dependencies_sha256}',
]
PLANNED_ARGV_SLOTS = ('engine', 'fixture', 'case', 'grant_id', 'grant_sha256',
                      'dependencies_sha256')
NATIVE_ARGV_STAGED = False
NATIVE_LAUNCH_PATHS = 0


class SupervisorRefusal(ValueError):
    """The preflight failed. Raised before any refusal record is written."""


def preflight(record_dir, *, grant_path=None, now=0.0):
    """Every check a real supervisor would make, performed read-only.

    Returns a summary of what was verified. Raises :class:`SupervisorRefusal`
    with a specific reason when any check fails, so a future reviewer can see
    which precondition is still missing rather than a blanket denial.
    """
    destination = Path(record_dir).absolute()
    contract = prepare.validate_record(destination)
    references = prepare.verify_references(ROOT)
    frozen = history.reference(policy.case_ids(), policy.canonical(), root=ROOT)
    checks = {
        'namespace': destination.name,
        'recordContractMatches': True,
        'sealsVerified': True,
        'frozenReferencesVerified': len(references),
        'amHistoryVerified': len(frozen['cases']),
        'amWholePositiveStillFailed': frozen['amWholePositiveFailed'] is True,
        'allowedCases': list(contract['allowedCases']),
        'caseCount': contract['caseCount'],
        'candidateResponseBudget': contract['candidateResponseBudget'],
        'grantPresent': grant_path is not None,
        'grantValidated': False,
        'engineResolved': False,
    }
    if grant_path is not None:
        grant_file = Path(grant_path).absolute()
        if not grant_file.is_file() or grant_file.is_symlink():
            raise SupervisorRefusal('grant must be a regular non-symlink file')
        grant = seals.load(grant_file)
        policy.validate_grant(grant, case_ids_in=contract['allowedCases'],
                              source_hash=seals.sha(grant_file.parent / prepare.RECORD_NAME),
                              engine_hash=policy.ENGINE, now=now)
        checks['grantValidated'] = True
        checks['grantSha256'] = seals.sha(grant_file)
    return checks


#: The engine and fixture slots stay unfilled: no native stage exists for them.
PLANNED_ARGV_UNSET = '{engine}', '{fixture}'


def planned_argv(*, grant_id, grant_sha256, dependencies_sha256, case_id):
    """The argv a future supervisor would build. Built and returned, never run.

    Only the four grant/case slots are filled; ``{engine}`` and ``{fixture}``
    remain as explicit placeholders because resolving either would mean a native
    stage exists. Slot names are matched literally, so a supplied value cannot
    inject a further placeholder.
    """
    if not policy.case_allowed(case_id):
        raise SupervisorRefusal('only the two authorized cases could ever be requested')
    # A refusal may legitimately describe a campaign that has no grant, so the
    # "no grant exists" placeholders are accepted. Real grant values must still be
    # plain strings with no slot braces.
    for name, value in (('grant_id', grant_id), ('grant_sha256', grant_sha256),
                        ('dependencies_sha256', dependencies_sha256)):
        if not isinstance(value, str) or not value or '{' in value or '}' in value:
            raise SupervisorRefusal(name + ' required and must contain no slot braces')
        if value.startswith('<') and value not in (NO_GRANT, NO_DEPENDENCIES):
            raise SupervisorRefusal(name + ' placeholder is not recognized: ' + value)
    filled = {'case': case_id, 'grant_id': grant_id, 'grant_sha256': grant_sha256,
              'dependencies_sha256': dependencies_sha256}
    argv = []
    for token in PLANNED_ARGV_TEMPLATE:
        for name, value in filled.items():
            token = token.replace('{' + name + '}', value)
        argv.append(token)
    # Positive check: the engine and fixture slots must still be literal
    # placeholders. Filling either would imply a resolved binary or a staged
    # fixture, neither of which exists in this source package.
    if argv[0] != PLANNED_ARGV_UNSET[0] or PLANNED_ARGV_UNSET[1] not in argv:
        raise SupervisorRefusal('the engine and fixture slots must remain unset here')
    return argv


#: Placeholders used when no grant exists. They are not values a validator would
#: accept, so a refusal built with them can never be mistaken for an authorized one.
NO_GRANT = '<no grant exists>'
NO_DEPENDENCIES = '<no dependencies record>'


def refuse(record_dir, *, reason=None, now=None, grant_id=NO_GRANT,
           grant_sha256=NO_GRANT, dependencies_sha256=NO_DEPENDENCIES,
           case_id=policy.CASES[0], checks=None, planned_argv_tokens=None):
    """Write the sealed, write-once refusal. Returns the refusal record.

    ``planned_argv_tokens`` may supply an already-built argv for a reviewer who
    wants to see a specific hypothetical. It is copied into the refusal as data
    and is never executed; omitting it uses the template.
    """
    destination = Path(record_dir).absolute()
    argv = list(planned_argv_tokens) if planned_argv_tokens is not None else planned_argv(
        grant_id=grant_id, grant_sha256=grant_sha256,
        dependencies_sha256=dependencies_sha256, case_id=case_id)
    refusal = {
        'phase': policy.PHASE,
        'mode': policy.MODE,
        'group': policy.GROUP,
        'scope': 'source-only-supervision',
        'attempt': destination.name,
        'utc': seals.utc() if now is None else now,
        'refused': True,
        'reason': reason or 'native readiness and any grant are explicitly out of scope',
        'blockingReasons': list(policy.NATIVE_READINESS_BLOCKERS),
        'preflightChecks': checks or {},
        'plannedArgv': argv,
        'plannedArgvSlots': list(PLANNED_ARGV_SLOTS),
        'plannedArgvUnsetSlots': list(PLANNED_ARGV_UNSET),
        'plannedArgvIsADescriptionNotACommand': True,
        'engineSlotDeliberatelyUnresolved': True,
        'fixtureSlotDeliberatelyUnresolved': True,
        'grantExists': grant_id != NO_GRANT,
        'nativeArgvStaged': NATIVE_ARGV_STAGED,
        'nativeLaunchPaths': NATIVE_LAUNCH_PATHS,
        'engineInvocations': 0,
        'engineResolutionAttempted': False,
        'nativeReadiness': {'ready': False,
                            'blockingReasons': list(policy.NATIVE_READINESS_BLOCKERS)},
        'positiveAdmission': False,
        'nativeStepAdmission': False,
        'productionPromotion': False,
        'amWholePositiveFailed': True,
        'unrunPositiveCase': '.42/.18/+45',
        'candidateMapJourneysUnrun': 60,
        'staticVesperFailuresUnresolved': 184,
        'productionAccountingOpen': True,
    }
    return seals.write_once(destination / REFUSAL_NAME, refusal)


def main(argv=None):
    """Run the full preflight, then write the sealed refusal and stop.

    There is no branch here that launches anything. Returning success means the
    refusal was recorded; it never means a measurement was taken.
    """
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument('--record', required=True, help='the source record directory to supervise')
    parser.add_argument('--grant', default=None)
    args = parser.parse_args(argv)
    checks = preflight(args.record, grant_path=args.grant)
    refusal_path = refuse(args.record, checks=checks)
    refusal = seals.load(refusal_path)
    print(refusal['reason'])
    print(refusal_path)
    print('engine invocations: %d; native readiness: %s'
          % (refusal['engineInvocations'], refusal['nativeReadiness']['ready']))
    return 0


def cli():
    return main()


__all__ = ['NATIVE_ARGV_STAGED', 'NATIVE_LAUNCH_PATHS', 'NO_DEPENDENCIES', 'NO_GRANT',
           'PLANNED_ARGV_SLOTS', 'PLANNED_ARGV_TEMPLATE', 'PLANNED_ARGV_UNSET', 'REFUSAL_NAME',
           'SupervisorRefusal', 'cli', 'main', 'planned_argv', 'preflight', 'refuse']
