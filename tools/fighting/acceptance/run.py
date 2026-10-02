"""Source-only by default; native work requires the merged finish supervisor + grant."""
import argparse
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import uuid

from source import inspect

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools/godot-dev'))
from gate_runner import save_report

EVIDENCE = Path('/home/mojo/.tmp-on-disk/cocs-fighting-verification-evidence-20261002')
PLAN = ROOT / 'port/fighting/acceptance/plan.json'


def identity(root):
    tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).decode().split('\0')
    names = {n for n in tracked if n and not n.startswith(('reports/', 'port/reports/'))}
    for directory in ('godot/fighting', 'godot/tests/fighting/acceptance', 'tools/fighting/acceptance', 'port/fighting/acceptance'):
        names.update(str(p.relative_to(root)) for p in (root / directory).rglob('*')
                     if p.is_file() and '__pycache__' not in p.parts)
    files = {n: hashlib.sha256((root / n).read_bytes()).hexdigest() if (root / n).is_file() else 'MISSING'
             for n in sorted(names)}
    return {'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root).decode().strip(),
            'sha256': hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest(), 'files': files}


def dependencies(root, job):
    return [name for name in job['requires'] if not (root / name).is_file()]


def judge(result, output, marker, artifact):
    """The older shared gate runner does not enforce markers: enforce both here."""
    if result.get('status') != 'passed':
        return result
    reason = None
    if marker not in output.splitlines():
        reason = 'missing-exact-success-marker'
    elif not artifact.is_file():
        reason = 'missing-native-report'
    else:
        try:
            data = json.loads(artifact.read_text())
            if data.get('status') != 'passed' or not data.get('checks') or data.get('failures') or data.get('unrun'):
                reason = 'incomplete-native-report'
        except (ValueError, OSError):
            reason = 'invalid-native-report'
    return {**result, 'status': 'failed' if reason else 'passed', 'failure_reason': reason}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['plan', 'source', 'native'])
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--evidence', type=Path, default=EVIDENCE)
    parser.add_argument('--gate', default='journeys')
    parser.add_argument('--heavy-grant', help='Explicit parent-issued resource grant reference; never inferred')
    parser.add_argument('--godot', type=Path)
    args = parser.parse_args(argv)
    root = args.root.resolve()
    plan = json.loads(PLAN.read_text())
    if args.mode == 'plan':
        print(json.dumps({**plan, 'dependency_inventory': {j['id']: dependencies(root, j) for j in plan['jobs']}}, indent=2))
        return 0
    run = args.evidence / (datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:10])
    run.mkdir(parents=True, exist_ok=False)
    report = {'version': 1, 'mode': args.mode, 'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'candidate': identity(root), 'status': 'unrun', 'native_art': 'unrun', 'jobs': []}
    save_report(run / 'manifest.json', report)
    if args.mode == 'source':
        report['source'] = inspect(root)
        report['status'] = report['source']['status']
    else:
        job = next((j for j in plan['jobs'] if j['id'] == args.gate), None)
        if job is None:
            parser.error('Unknown gate')
        missing = dependencies(root, job)
        supervisor = root / 'tools/godot-dev/finish_runner.py'
        reason = ('explicit-heavy-grant-required' if not args.heavy_grant else
                  'merged-finish-supervisor-required' if not supervisor.is_file() else
                  'dependencies-absent' if missing else
                  'native-entrypoint-not-prepared' if not job.get('script') else
                  'godot-binary-required' if not args.godot or not args.godot.is_file() else None)
        if reason:
            report['jobs'].append({'id': job['id'], 'status': 'deferred', 'reason': reason, 'missing': missing})
            report['status'] = 'deferred'
        else:
            # Reuse parent-owned, subreaper-aware implementation, not a parallel framework.
            spec = importlib.util.spec_from_file_location('fighting_finish_supervisor', supervisor)
            finish = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(finish)
            import fcntl
            lock_path = Path('/tmp/opencode/cocs-fighting-acceptance.lock')
            with lock_path.open('a') as lock:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                env = finish.isolated_environment(run / 'user')
                env['FIGHTING_ACCEPTANCE_OUTPUT'] = str(run / 'native.json')
                env['FIGHTING_ACCEPTANCE_EVIDENCE'] = str(run)
                command = [str(args.godot.resolve())]
                if not job.get('rendered', False):
                    command.append('--headless')
                command += ['--path', str(root / 'godot'), '--script', job['script']]
                report['grant'] = args.heavy_grant
                report['binary_sha256'] = hashlib.sha256(args.godot.read_bytes()).hexdigest()
                save_report(run / 'manifest.json', report)
                result = finish.run_bounded(command, root, env, run / 'native.log', job['timeout_seconds'])
                result = judge(result, (run / 'native.log').read_text(), job['marker'], run / 'native.json')
                result.update(id=job['id'], command=command)
                report['jobs'].append(result)
                report['status'] = result['status']
    report['candidate_after'] = identity(root)['sha256']
    if report['candidate_after'] != report['candidate']['sha256']:
        report['status'] = 'failed'
        report['failure_reason'] = 'candidate-mutated-during-run'
    report['completed_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    save_report(run / 'manifest.json', report)
    # Final inventory is immutable evidence; each invocation always uses a new directory.
    hashes = {str(p.relative_to(run)): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in run.rglob('*') if p.is_file()}
    (run / 'SHA256SUMS.json').write_text(json.dumps(hashes, indent=2) + '\n')
    print(json.dumps({'status': report['status'], 'manifest': str(run / 'manifest.json')}, indent=2))
    return 0 if report['status'] == 'passed' else 2 if report['status'] == 'deferred' else 1


if __name__ == '__main__':
    raise SystemExit(main())
