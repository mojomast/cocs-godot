"""Serial, opt-in finish acceptance. Source checks never imply native acceptance."""
import argparse
import ctypes
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import time
import uuid

from gate_runner import save_report
from finish_receipts import accept_reference, sha, validate_artifact_checks, validate_output_checks

ROOT = Path(__file__).resolve().parents[2]
MATRIX = ROOT / 'port/finish/matrix.json'
EVIDENCE = Path('/home/mojo/.tmp-on-disk/cocs-finish-acceptance-evidence-20261002')
COHORT_LOCK = Path('/tmp/opencode/cocs-finish-acceptance.lock')


def load_matrix(path=MATRIX, ancestors=(), root=ROOT):
    path = Path(path).resolve()
    if path in ancestors:
        raise ValueError('Matrix inheritance cycle')
    data = json.loads(Path(path).read_text())
    if data.get('extends'):
        base = load_matrix(path.parent / data['extends'], (*ancestors, path), root)
        data = {**base, **data, 'jobs': base['jobs'] + data['jobs'],
                'defaults': {**base.get('defaults', {}), **data.get('defaults', {})},
                'dynamic_dependencies': sorted(set(base['dynamic_dependencies'] + data.get('dynamic_dependencies', [])))}
    for delegated in data.pop('delegated_plans', []):
        plan_path = (path.parent / delegated['path']).resolve()
        plan_relative = plan_path.relative_to(ROOT)
        plan_path = root / plan_relative
        plan = json.loads(plan_path.read_text())
        for entry in plan['jobs']:
            resource = entry['resource']
            cohort = 'external' if resource == 'blender-exclusive' else 'audio' if 'audio' in resource else 'engine'
            job = {'id': delegated['prefix'] + entry['id'], 'cohort': cohort,
                   'owner': delegated['owner'], 'timeout': entry['timeout_seconds'] + 40,
                   'requires': entry['requires'] + ['tools/fighting/acceptance/run.py'],
                   'after': ['native-import'], 'units': [entry['id']],
                   'evidence_kind': 'delegated-fighting-' + resource,
                   'criteria': entry.get('reason', 'Existing independent fighting gate must pass all actual checks'),
                   'next_action': 'Use existing fighting acceptance producer under explicit grant; inspect failed/unrun cases',
                   'delegated_plan': str(plan_relative), 'delegated_job': entry}
            if entry['id'] == 'native-assets':
                roster_path = root / 'godot/fighting/data/roster.json'
                if roster_path.is_file():
                    job['units'] = [op['id'] for op in json.loads(roster_path.read_text())['operators']]
            if entry.get('script'):
                job['command'] = ['{python}', 'tools/fighting/acceptance/run.py', 'native', '--gate', entry['id'],
                                  '--evidence', '{out}', '--godot', '{godot}', '--heavy-grant', '{grant_reference}']
                if entry.get('rendered'):
                    job['command'] = ['{python}', 'tools/godot-dev/xvfb_run.py'] + job['command']
                job['needs_grant_reference'] = True
                job['artifact_checks'] = [{'kind': 'fighting-manifest', 'path': '*/manifest.json'}]
            else:
                job['receipt_only'] = True
                job['next_action'] = entry.get('reason', 'Owner must finish this producer before execution')
            data['jobs'].append(job)
    for job in data['jobs']:
        if job.get('units_from_roster') == 'combos':
            roster_path = root / 'godot/fighting/data/roster.json'
            if roster_path.is_file():
                roster = json.loads(roster_path.read_text())
                job['units'] = [f"{op['id']}/{combo['name']}/{facing}" for op in roster['operators']
                                for combo in op['combos'] for facing in (1, -1)]
        defaults = data.get('defaults', {}).get(job['cohort'], {})
        for key, value in defaults.items():
            job.setdefault(key, value)
    ids = [job['id'] for job in data['jobs']]
    if len(ids) != len(set(ids)):
        raise ValueError('Duplicate gate IDs')
    seen = set()
    for job in data['jobs']:
        if job['timeout'] <= 0 or job['cohort'] not in ('source', 'engine', 'audio', 'manual', 'external'):
            raise ValueError('Invalid bounded gate: ' + job['id'])
        if not set(job.get('after', [])) <= seen:
            raise ValueError('Dependencies must precede gate: ' + job['id'])
        if not job.get('criteria') or not job.get('evidence_kind'):
            raise ValueError('Missing acceptance semantics: ' + job['id'])
        seen.add(job['id'])
    return data


def input_identity(root, matrix, environment):
    """Hash bytes, not only HEAD: dirty and ignored runtime inputs matter too."""
    tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).decode().split('\0')
    paths = {p for p in tracked if p and not p.startswith(('port/reports/', 'reports/'))}
    for job in matrix['jobs']:
        paths.update(p for p in dependency_inventory(root, job)['files'] if not p.startswith('outside-root:'))
    for directory in matrix['dynamic_dependencies']:
        base = root / directory
        if base.is_dir():
            paths.update(str(p.relative_to(root)) for p in base.rglob('*') if p.is_file())
    digest = hashlib.sha256()
    for implementation in (Path(__file__), Path(__file__).with_name('gate_runner.py'),
                           Path(__file__).with_name('finish_receipts.py')):
        digest.update(implementation.read_bytes())
    digest.update(json.dumps(matrix, sort_keys=True).encode())
    digest.update(json.dumps(environment, sort_keys=True).encode())
    missing = []
    for name in sorted(paths):
        p = root / name
        digest.update(name.encode() + b'\0')
        if not p.is_file():
            missing.append(name)
            digest.update(b'MISSING')
        else:
            with p.open('rb') as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b''):
                    digest.update(block)
    binary = environment.get('GODOT_BIN', '')
    if binary and Path(binary).is_file():
        with open(binary, 'rb') as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b''):
                digest.update(block)
    return {'sha256': digest.hexdigest(), 'files': len(paths), 'missing_tracked': missing,
            'environment': environment}


def dependency_inventory(root, job):
    """Resolve literal imports/preloads; dynamic resource families stay explicit in matrix."""
    pending = list(job.get('requires', []))
    files, missing, packages = set(), set(), set()
    # new URL is also used for optional output stores (server/history.json), so
    # input JSON/resources belong in requires rather than guessing read vs write.
    pattern = re.compile(r'(?:from\s*|import\s*\(?|preload\s*\(|extends\s*)'
                         r'[\s]*[\'\"]([^\'\"]+)[\'\"]')
    while pending:
        name = pending.pop()
        if name in files:
            continue
        files.add(name)
        path = root / name
        if not path.exists():
            missing.add(name)
            continue
        if path.suffix not in ('.mjs', '.js', '.gd'):
            continue
        for target in pattern.findall(path.read_text()):
            if target.startswith('res://'):
                target_path = root / 'godot' / target[6:]
            elif target.startswith('.'):
                target_path = path.parent / target
            elif not target.startswith('node:'):
                packages.add(target)
                continue
            else:
                continue
            try:
                pending.append(str(target_path.resolve().relative_to(root.resolve())))
            except ValueError:
                missing.add('outside-root:' + target)
    return {'files': sorted(files), 'missing': sorted(missing), 'node_packages': sorted(packages),
            'dynamic_resources': job.get('dynamic_resources', [])}


def descendants():
    """All descendants of this serial supervisor, including orphaned setsid peers."""
    rows = {}
    for path in Path('/proc').glob('[0-9]*/stat'):
        try:
            tail = path.read_text().rsplit(')', 1)[1].split()
            rows[int(path.parent.name)] = (int(tail[1]), tail[0], tail[19])
        except (OSError, ValueError, IndexError):
            continue
    owned = {os.getpid()}
    while True:
        more = {pid for pid, (parent, _, _) in rows.items() if parent in owned}
        if more <= owned:
            break
        owned |= more
    return {pid: rows[pid] for pid in owned if pid != os.getpid()}


def cleanup_children():
    signalled = set()
    for sig, duration in ((signal.SIGTERM, .5), (signal.SIGKILL, 2)):
        end = time.monotonic() + duration
        while True:
            rows = descendants()
            for pid, (_, state, _) in rows.items():
                if state != 'Z':
                    try:
                        os.kill(pid, sig)
                        signalled.add(pid)
                    except ProcessLookupError:
                        pass
            while True:
                try:
                    pid, _ = os.waitpid(-1, os.WNOHANG)
                    if pid == 0:
                        break
                except ChildProcessError:
                    break
            if not descendants() or time.monotonic() >= end:
                break
            time.sleep(.02)
    return {'signalled': sorted(signalled), 'remaining': sorted(descendants())}


def run_bounded(command, cwd, env, log, timeout):
    # Linux subreaper keeps detached grandchildren owned after their launcher exits.
    # Group-only timeout killing is insufficient for the existing detached Xvfb peers.
    if ctypes.CDLL(None, use_errno=True).prctl(36, 1, 0, 0, 0) != 0:
        raise OSError(ctypes.get_errno(), 'PR_SET_CHILD_SUBREAPER')
    start = time.monotonic()
    process = None
    reason = None
    code = None
    old_handlers = {}
    def interrupt(signum, _frame):
        raise InterruptedError('signal ' + str(signum))
    for sig in (signal.SIGINT, signal.SIGTERM):
        old_handlers[sig] = signal.signal(sig, interrupt)
    try:
        with Path(log).open('x') as stream:
            try:
                process = subprocess.Popen(command, cwd=cwd, env=env, stdin=subprocess.DEVNULL,
                                           stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
                while process.poll() is None:
                    if time.monotonic() - start >= timeout:
                        reason = 'timeout'
                        break
                    time.sleep(.02)
                code = process.poll()
            except InterruptedError as error:
                reason = 'interrupted'
                stream.write(str(error) + '\n')
            except OSError as error:
                reason = 'launch-error'
                stream.write(str(error) + '\n')
    finally:
        for sig in old_handlers:
            signal.signal(sig, signal.SIG_IGN)
        cleanup = cleanup_children()
        if process is not None:
            process.wait(timeout=3)
        for sig, handler in old_handlers.items():
            signal.signal(sig, handler)
    if cleanup['remaining']:
        reason = 'descendants-survived'
    elif reason is None and cleanup['signalled']:
        reason = 'leaked-descendants'
    text = Path(log).read_text(errors='replace')
    if reason is None:
        if code != 0:
            reason = 'nonzero-exit'
        elif re.search(r'SCRIPT ERROR|Parse Error|ERROR:', text):
            reason = 'engine-error'
    return {'status': 'passed' if reason is None else 'failed', 'failure_reason': reason,
            'exit_code': code, 'duration_seconds': round(time.monotonic() - start, 3),
            'owned_process_group': process.pid if process is not None else None,
            'cleanup': cleanup}


def isolated_environment(directory):
    env = dict(os.environ)
    # Never inherit release/user store locations or an unrelated lane grant.
    for key in list(env):
        if key.startswith(('COCS_', 'PLAYER_GAMEPLAY_', 'CHALLENGE_', 'LATTICE_', 'THREE_AUDIO_')) or key in (
                'OPERATORS', 'SHARED_SCENARIO', 'MODE_EVIDENCE', 'EVIDENCE_DIR', 'AUDIO_EVIDENCE_DIR',
                'BLACKWATER_HEADLESS_FIXTURE', 'GODOT_BIN', 'AUDIO_DRIVER'):
            del env[key]
    for key, suffix in {
        'HOME': 'home', 'XDG_DATA_HOME': 'data', 'XDG_CONFIG_HOME': 'config', 'XDG_CACHE_HOME': 'cache',
        'COCS_CAREER_ROOT': 'career', 'EVIDENCE_DIR': 'artifacts', 'PLAYER_GAMEPLAY_EVIDENCE': 'artifacts',
        'MODE_EVIDENCE': 'artifacts', 'LATTICE_EVIDENCE': 'artifacts', 'AUDIO_EVIDENCE_DIR': 'artifacts',
        'COCS_REPLAY_EVIDENCE': 'artifacts', 'HORDE_EVIDENCE_DIR': 'artifacts',
    }.items():
        path = directory / suffix
        path.mkdir(parents=True, exist_ok=True)
        env[key] = str(path)
    for key, suffix in {'COCS_SETTINGS_PATH': 'settings.json', 'COCS_BINDINGS_PATH': 'bindings.json',
                        'COCS_CAREER_CREDENTIALS_PATH': 'credentials.json'}.items():
        env[key] = str(directory / suffix)
    env.update(LP_NUM_THREADS='1', PORT='0')
    return env


def summarize(report, jobs):
    latest = {key: value[-1]['status'] for key, value in report['attempts'].items() if value}
    report['incomplete_critical'] = [j['id'] for j in jobs if j.get('critical', True) and latest.get(j['id']) != 'passed']
    report['status'] = 'incomplete' if report['incomplete_critical'] else 'passed'
    engineering = [j for j in jobs if j.get('critical', True) and j['cohort'] in ('source', 'engine')]
    # All receipts belong to this ledger's identity, enforced by strict resume.
    # This label is engineering completion, not playtest or release certification.
    report['integration_ready'] = bool(engineering and report.get('input_identity', {}).get('sha256')) and all(
        latest.get(j['id']) == 'passed' for j in engineering)
    blockers = {cohort: {'unrun': [], 'failing': []}
                for cohort in ('source', 'engine', 'audio', 'manual', 'external')}
    for job in jobs:
        status = latest.get(job['id'])
        if job.get('critical', True) and status != 'passed':
            blockers[job['cohort']]['failing' if status == 'failed' else 'unrun'].append(job['id'])
    report['blockers_by_cohort'] = blockers
    report['completion_ledger'] = []
    for job in jobs:
        history = report['attempts'].get(job['id'], [])
        attempt = history[-1] if history else {}
        missing = attempt.get('dependencies', {}).get('missing', [])
        dependencies = [dep for dep in job.get('after', []) if latest.get(dep) != 'passed']
        status = latest.get(job['id'], 'unrun')
        report['completion_ledger'].append({
            'id': job['id'], 'owner': job.get('owner', 'combined acceptance / parent'),
            'cohort': job['cohort'], 'critical': job.get('critical', True), 'execution_status': status,
            'preparation': 'blocked' if missing or dependencies else
                           'owner-receipt-required' if job.get('receipt_only') or not job.get('command') else 'ready-to-run',
            'missing_inputs': missing, 'dependencies': job.get('after', []), 'incomplete_dependencies': dependencies,
            'next_action': job.get('next_action', job.get('criteria', 'Complete the critical gate under its owner grant')),
            'units': {unit: attempt.get('units', {}).get(unit, status) for unit in job.get('units', [job['id']])},
            'skip_reason': attempt.get('skip_reason'), 'failure_reason': attempt.get('failure_reason')})
    # Feature acceptance is not packaging, production art, listening, or publication.
    report['release_ready'] = False


def accept_attestation(path, report, jobs):
    """Explicit owner review only; evidence must exist and bind this exact input."""
    receipt = json.loads(Path(path).read_text())
    gate = next((j for j in jobs if j['id'] == receipt.get('gate')), None)
    if not gate or gate['cohort'] not in ('manual', 'external'):
        raise ValueError('Attestations cannot replace executable gates')
    if gate.get('receipt_only'):
        raise ValueError('This closure requires the typed exact-anchor receipt adapter')
    if receipt.get('input_sha256') != report['input_identity']['sha256']:
        raise ValueError('Attestation input hash mismatch')
    if receipt.get('verdict') != 'passed' or not receipt.get('reviewer') or not receipt.get('notes') or not receipt.get('evidence'):
        raise ValueError('Explicit reviewer, passed verdict, notes and evidence required')
    for item in receipt['evidence']:
        evidence = Path(item['path'])
        if not evidence.is_absolute() or not evidence.is_file():
            raise ValueError('Attestation evidence must be an existing absolute file')
        if hashlib.sha256(evidence.read_bytes()).hexdigest() != item['sha256']:
            raise ValueError('Attestation evidence hash mismatch')
    report['attempts'].setdefault(gate['id'], []).append(
        {'status': 'passed', 'at': time.time(), 'evidence_kind': gate['evidence_kind'],
         'attestation': receipt, 'receipt_sha256': hashlib.sha256(Path(path).read_bytes()).hexdigest()})


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--matrix', type=Path, default=MATRIX)
    parser.add_argument('--evidence', type=Path, default=EVIDENCE)
    parser.add_argument('--run', action='store_true', help='default only plans; no child processes')
    parser.add_argument('--grant', action='append', choices=['engine', 'audio', 'horde-boss'], default=[])
    parser.add_argument('--select', action='append', default=[], help='exact ID; unselected cases remain incomplete')
    parser.add_argument('--resume', type=Path, help='same-input report only; successes are never rerun')
    parser.add_argument('--retry-failed', action='store_true', help='explicit new attempt, preserving all failures')
    parser.add_argument('--budget-seconds', type=float, default=1800, help='invocation budget; do not start a gate whose deadline will not fit (default 1800)')
    parser.add_argument('--attest', action='append', type=Path, default=[], help='same-hash explicit manual/external owner receipt; requires --resume')
    parser.add_argument('--receipt', action='append', type=Path, default=[], help='verified existing exact-anchor producer reference; never runs producer')
    parser.add_argument('--grant-reference', default='', help='actual parent grant identifier for delegated producers')
    args = parser.parse_args(argv)
    if args.budget_seconds <= 0:
        parser.error('--budget-seconds must be positive')
    if args.attest and not args.resume:
        parser.error('--attest requires an existing --resume report')
    matrix = load_matrix(args.matrix, root=args.root)
    jobs = matrix['jobs']
    unknown = set(args.select) - {j['id'] for j in jobs}
    if unknown:
        parser.error('Unknown IDs: ' + ', '.join(sorted(unknown)))
    environment = {key: os.environ.get(key, '') for key in ('GODOT_BIN', 'AUDIO_DRIVER', 'PATH', 'DISPLAY',
                   'PULSE_SERVER', 'XDG_RUNTIME_DIR', 'LIBGL_ALWAYS_SOFTWARE')}
    identity = input_identity(args.root, matrix, environment)
    args.evidence.mkdir(parents=True, exist_ok=True)
    # One entire cohort at a time across separate invocations and evidence roots.
    lock_path = COHORT_LOCK
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open('a') as cohort_lock:
        fcntl.flock(cohort_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if args.resume:
            report_path = args.resume.resolve()
            report = json.loads(report_path.read_text())
            if report['input_identity'] != identity:
                parser.error('Input hash/environment changed: create a fresh report; old evidence is retained')
            run_dir = report_path.parent
        else:
            run_dir = Path(tempfile.mkdtemp(prefix='run-', dir=args.evidence.resolve()))
            report_path = run_dir / 'report.json'
            report = {'schema': 1, 'input_identity': identity, 'root': str(args.root.resolve()),
                      'attempts': {}, 'queue': jobs, 'created': time.time()}
            head = subprocess.run(['git', 'rev-parse', '--verify', 'HEAD'], cwd=args.root,
                                  text=True, capture_output=True)
            report['port_commit'] = head.stdout.strip() if head.returncode == 0 else None
            report['port_worktree_dirty'] = bool(subprocess.check_output(
                ['git', 'status', '--porcelain'], cwd=args.root, text=True).strip())
        started = time.monotonic()
        report.setdefault('invocations', []).append({'at': time.time(), 'run': args.run, 'grants': args.grant,
                                                   'grant_reference': args.grant_reference,
                                                   'budget_seconds': args.budget_seconds,
                                                   'select': args.select, 'retry_failed': args.retry_failed})
        for receipt in args.attest:
            accept_attestation(receipt, report, jobs)
        for receipt in args.receipt:
            try:
                accept_reference(receipt, report, jobs, args.root, run_dir / 'receipts')
            except (ValueError, KeyError, OSError, TypeError, AttributeError) as error:
                report.setdefault('rejected_receipts', []).append({'path': str(receipt), 'reason': str(error), 'at': time.time()})
                summarize(report, jobs)
                save_report(report_path, report)
                print('Receipt rejected: ' + str(error), file=sys.stderr)
                return 1
        selected = set(args.select) if args.select else {j['id'] for j in jobs}
        for job in jobs:
            history = report['attempts'].setdefault(job['id'], [])
            if history and history[-1]['status'] == 'passed':
                continue
            if history and history[-1]['status'] == 'failed' and not args.retry_failed:
                continue
            dependencies = dependency_inventory(args.root, job)
            missing = dependencies['missing']
            missing_hooks = [p + ': ' + token for p, token in job.get('required_source_tokens', {}).items()
                             if not (args.root / p).is_file() or token not in (args.root / p).read_text()]
            reason = None
            if job['id'] not in selected:
                reason = 'not selected'
            elif not args.run:
                reason = 'plan only'
            elif job.get('blocked'):
                reason = job['blocked']
            elif job['cohort'] in ('manual', 'external'):
                reason = 'separate owner/human evidence required'
            elif missing:
                reason = 'requires integration/resources: ' + ', '.join(missing)
            elif missing_hooks:
                reason = 'requires parent launcher/integration hook: ' + ', '.join(missing_hooks)
            elif job.get('receipt_only') or not job.get('command'):
                reason = 'owner execution and typed exact-anchor receipt required'
            elif job.get('needs_grant_reference') and not args.grant_reference:
                reason = 'actual parent grant reference required for delegated producer'
            elif job['cohort'] != 'source' and 'engine' not in args.grant:
                reason = 'explicit parent engine grant absent'
            elif job['cohort'] == 'audio' and ('audio' not in args.grant or environment['AUDIO_DRIVER'] in ('', 'Dummy')):
                reason = 'explicit audio grant and real AUDIO_DRIVER required'
            elif job.get('grant') and job['grant'] not in args.grant:
                reason = 'inspect chain, then obtain separate ' + job['grant'] + ' grant'
            elif job['cohort'] != 'source' and not environment['GODOT_BIN']:
                reason = 'pinned GODOT_BIN required'
            elif any(not report['attempts'].get(dep) or report['attempts'][dep][-1]['status'] != 'passed'
                     for dep in job.get('after', [])):
                reason = 'prerequisite incomplete: ' + ', '.join(job['after'])
            elif time.monotonic() - started + job['timeout'] + 6 > args.budget_seconds:
                reason = 'invocation budget cannot fit gate deadline and cleanup; resume later'
            if reason:
                history.append({'status': 'unrun', 'skip_reason': reason, 'dependencies': dependencies, 'at': time.time()})
                summarize(report, jobs)
                save_report(report_path, report)
                continue
            directory = run_dir / job['id'] / (str(len(history) + 1) + '-' + uuid.uuid4().hex[:8])
            directory.mkdir(parents=True)
            env = isolated_environment(directory)
            substitutions = {'out': str(directory / 'artifacts'), 'godot': environment['GODOT_BIN'],
                             'audio_driver': environment['AUDIO_DRIVER'], 'python': sys.executable,
                             'grant_reference': args.grant_reference, 'root': str(args.root.resolve()),
                             # Stable path, mutable contents: saved with the running
                             # attempt below before any producer reads its anchor.
                             'finish_anchor': str(report_path.resolve()),
                             'finish_matrix': str(args.matrix.resolve())}
            env.update({k: v for k, v in environment.items() if v and k not in ('PATH',)})
            env.update({key: value.format(**substitutions) for key, value in job.get('env', {}).items()})
            command = [arg.format(**substitutions) for arg in job['command']]
            attempt = {'status': 'running', 'command': command, 'cwd': str(args.root.resolve()),
                       'scope': str(directory), 'at': time.time(), 'timeout': job['timeout'],
                       'dependencies': dependencies,
                       'environment': {k: v for k, v in env.items() if k not in os.environ or os.environ[k] != v}}
            history.append(attempt)
            summarize(report, jobs)
            save_report(report_path, report)
            attempt.update(run_bounded(command, args.root, env, directory / 'output.log', job['timeout']))
            if attempt['status'] == 'passed' and job.get('version_lock'):
                expected = json.loads((args.root / job['version_lock']).read_text())['godot_version']
                if (directory / 'output.log').read_text().strip() != expected:
                    attempt.update(status='failed', failure_reason='version-mismatch')
            if attempt['status'] == 'passed':
                absent = [p for p in job.get('artifacts', []) if not list((directory / 'artifacts').glob(p))]
                if absent:
                    attempt.update(status='failed', failure_reason='missing evidence: ' + ', '.join(absent))
            for index, check in enumerate(job.get('post_commands', [])):
                if attempt['status'] != 'passed':
                    break
                remaining = job['timeout'] - (time.time() - attempt['at'])
                if remaining <= 0:
                    attempt.update(status='failed', failure_reason='post-check-budget-exhausted')
                    break
                result = run_bounded([a.format(**substitutions) for a in check], args.root, env,
                                     directory / ('post-' + str(index) + '.log'), min(30, remaining))
                attempt.setdefault('post_checks', []).append(result)
                if result['status'] != 'passed':
                    attempt.update(status='failed', failure_reason='post-check-failed')
            bad_logs = []
            for log in (directory / 'artifacts').rglob('*.log'):
                if re.search(r'SCRIPT ERROR|Parse Error|ERROR:', log.read_text(errors='replace')):
                    bad_logs.append(str(log))
            if bad_logs:
                attempt.update(status='failed', failure_reason='nested-engine-error', error_logs=bad_logs)
            # Preserve per-route actual failures as well as successes, without
            # letting a partial combo result turn the containing gate green.
            if job.get('units_from_roster') == 'combos':
                combo_report = directory / 'artifacts/actual-combos.json'
                if combo_report.is_file():
                    try:
                        rows = json.loads(combo_report.read_text()).get('results', [])
                        attempt['units'] = {f"{r['operator']}/{r['name']}/{r['facing']}":
                                            'passed' if r.get('passed') is True else 'failed' for r in rows}
                    except (ValueError, KeyError, TypeError, AttributeError):
                        attempt.update(status='failed', failure_reason='invalid combo report')
            if attempt['status'] == 'passed':
                try:
                    validate_output_checks(job, (directory / 'output.log').read_text())
                    if job.get('success_marker') and job['success_marker'] not in (directory / 'output.log').read_text():
                        raise ValueError('Missing required native success marker')
                    attempt['units'] = validate_artifact_checks(job, directory / 'artifacts', args.root)
                except (ValueError, KeyError, OSError, TypeError) as error:
                    attempt.update(status='failed', failure_reason='producer-evidence: ' + str(error))
            attempt['artifact_hashes'] = {str(p.relative_to(directory)): sha(p) for p in directory.rglob('*')
                                          if p.is_file() and not p.is_symlink()}
            summarize(report, jobs)
            save_report(report_path, report)
            print(job['id'] + ': ' + attempt['status'], flush=True)
            if attempt.get('failure_reason') in ('interrupted', 'descendants-survived'):
                break
        summarize(report, jobs)
        save_report(report_path, report)
        print(str(report_path))
        return 1 if report['incomplete_critical'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
