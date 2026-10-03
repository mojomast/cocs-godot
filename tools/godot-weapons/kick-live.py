#!/usr/bin/env python3
"""Bounded native ordinary-input kick evidence. Run only with the native grant."""
import argparse
import json
import os
from pathlib import Path
import select
import shutil
import signal
import struct
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]


def stop_group(process):
    if process is None:
        return None
    # Kill the owned group even when its leader already exited.
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        process.wait(timeout=4)
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait(timeout=4)
    return process.returncode


def validate(report, records, directory, scenario):
    """Read-only cross-check: authority, native observations and real PNG bytes."""
    accepted = [row for row in records if row.get('kind') == 'accepted']
    native = report.get('events', [])
    ids = [row['event']['id'] for row in accepted]
    checks = {
        'native_passed': report.get('passed') is True,
        'one_initial_setup': sum(row.get('kind') == 'setup' for row in records) == 1,
        'same_ordered_ids': ids == [row['event']['id'] for row in native] and len(ids) == len(set(ids)),
        'bounded_actions': len(ids) == (6 if scenario == 'chain' else 5),
        'normal_wire_melee': any(row.get('kind') == 'input' and row.get('input', {}).get('melee') is True for row in records),
        'cooldowns': all(b['event']['time']-a['event']['time'] >= .299 for a, b in zip(accepted, accepted[1:])),
    }
    if scenario == 'chain':
        checks['three_hits'] = len(accepted) >= 3 and all(row['event'].get('outcome') == 'hit' for row in accepted[:3])
        checks['normal_health_progression'] = len(accepted) >= 3 and [row['health'][1]['health'] for row in accepted[:3]] == [55, 10, 0]
        required = list(zip(ids[:3], [1, 2, 3]))
    else:
        checks['blocked_no_damage'] = len(accepted) >= 2 and all(row['event'].get('outcome') == 'blocked' and row['health'][1]['health'] == 100 for row in accepted[:2])
        required = list(zip(ids[:2], [1, 1]))
    for event_id, step in required:
        capture = next((row for row in report.get('captures', []) if row['event_id'] == event_id), {})
        pose = capture.get('pose', {})
        path = directory / Path(capture.get('path', 'missing')).name
        valid_png = False
        if path.is_file():
            header = path.read_bytes()[:24]
            valid_png = len(header) == 24 and header[:8] == b'\x89PNG\r\n\x1a\n' and struct.unpack('>II', header[16:24]) == (1280, 720) and path.stat().st_size > 10000
        checks[f'contact_{event_id}_step_{step}'] = bool(capture.get('saved') and pose.get('step') == step and pose.get('active') and .095 <= pose.get('age', 0) <= .16 and valid_png)
    return checks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN', shutil.which('godot') or ''))
    parser.add_argument('--execute-native', action='store_true', help='Explicitly run after receiving exclusive native grant')
    args = parser.parse_args()
    if not args.execute_native:
        parser.error('Source-only phase: use --execute-native only after the exclusive grant')
    if not args.godot:
        parser.error('--godot or GODOT_BIN required')
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    status = subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True)
    if status:
        parser.error('Evidence requires a clean source commit; write --output outside the worktree')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    summary = {'passed': False, 'revision': revision, 'source_status': status, 'normal_rate': True,
               'setup_only_actor_writes': True, 'scenarios': {}, 'cleanup': [], 'commands': []}
    children = []
    logs = []

    def launch(command, name, env):
        summary['commands'].append(command)
        handle = (output / name).open('w')
        logs.append(handle)
        child = subprocess.Popen(command, cwd=ROOT, env=env, stdout=handle, stderr=subprocess.STDOUT, start_new_session=True)
        children.append(child)
        return child

    def bounded(command, name, env, timeout):
        child = launch(command, name, env)
        code = child.wait(timeout=timeout)
        logs[-1].flush()
        text = (output / name).read_text()
        if code or 'SCRIPT ERROR' in text or 'ERROR:' in text:
            raise RuntimeError(f'{name} failed: exit {code}')
        return text

    def terminate(_signum, _frame):
        raise KeyboardInterrupt('runner interrupted')

    signal.signal(signal.SIGTERM, terminate)
    signal.signal(signal.SIGALRM, terminate)
    signal.alarm(900)  # Includes private project copy/import, unit fixtures and both journeys.
    try:
        with tempfile.TemporaryDirectory(prefix='kick-live-', dir='/tmp/opencode') as temporary:
            stage = Path(temporary)
            env = {**os.environ, 'HOME': str(stage), 'LIBGL_ALWAYS_SOFTWARE': '1', 'LP_NUM_THREADS': '2'}
            for key in ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_RUNTIME_DIR']:
                folder = stage / key
                folder.mkdir(mode=0o700)
                env[key] = str(folder)
            project = stage / 'godot'
            shutil.copytree(ROOT / 'godot', project, ignore=shutil.ignore_patterns('.godot'))
            bounded([args.godot, '--headless', '--path', str(project), '--editor', '--import'], 'import.log', env, 600)
            for fixture in ['first_person/kick_chains', 'first_person/lifecycle', 'protocol/melee_feedback']:
                bounded([args.godot, '--headless', '--path', str(project), '--script', f'res://tests/{fixture}.gd'], fixture.replace('/', '-')+'.log', env, 30)
            read_fd, write_fd = os.pipe()
            try:
                handle = (output / 'xvfb.log').open('w')
                logs.append(handle)
                display = subprocess.Popen(['Xvfb', '-displayfd', str(write_fd), '-screen', '0', '1280x720x24', '-nolisten', 'tcp'], pass_fds=[write_fd], env=env, stdout=handle, stderr=subprocess.STDOUT, start_new_session=True)
                children.append(display)
                os.close(write_fd)
                write_fd = -1
                if not select.select([read_fd], [], [], 10)[0]:
                    raise RuntimeError('Xvfb readiness timeout')
                number = os.read(read_fd, 64).decode().strip()
                if not number.isdecimal():
                    raise RuntimeError('Invalid Xvfb display')
                env['DISPLAY'] = ':' + number
            finally:
                os.close(read_fd)
                if write_fd >= 0:
                    os.close(write_fd)
            for scenario in ['chain', 'blocked']:
                directory = output / scenario
                directory.mkdir()
                ready = stage / (scenario + '.json')
                server = launch(['node', str(ROOT / 'tools/godot-weapons/kick-live-server.mjs'), str(ready), str(directory), scenario], scenario+'-server.log', env)
                try:
                    deadline = time.monotonic() + 10
                    while not ready.exists():
                        if server.poll() is not None or time.monotonic() > deadline:
                            raise RuntimeError('Authority readiness failed')
                        time.sleep(.05)
                    port = json.loads(ready.read_text())['port']
                    command = [args.godot, '--path', str(project), '--script', 'res://tests/first_person/kick_live.gd',
                               '--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy',
                               '--resolution', '1280x720', '--position', '0,0', '--', f'--endpoint=ws://127.0.0.1:{port}',
                               '--map=meridian-exchange', '--bots=1', '--operator=chatgpt', '--mute',
                               f'--evidence={directory}', f'--scenario={scenario}', f'--revision={revision}']
                    text = bounded(command, scenario+'-native.log', env, 45)
                    report = json.loads((directory / 'native-report.json').read_text())
                    records = [json.loads(line) for line in (directory / 'authority.jsonl').read_text().splitlines()]
                    checks = validate(report, records, directory, scenario)
                    checks['completion_marker'] = 'KICK_LIVE_DONE' in text
                    checks['revision'] = report.get('revision') == revision
                    summary['scenarios'][scenario] = {'checks': checks, 'passed': all(checks.values())}
                finally:
                    stop_group(server)
            summary['passed'] = len(summary['scenarios']) == 2 and all(row['passed'] for row in summary['scenarios'].values())
    except (Exception, KeyboardInterrupt) as error:
        summary['error'] = str(error)
    finally:
        signal.alarm(0)
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        for child in reversed(children):
            try:
                summary['cleanup'].append({'pid': child.pid, 'returncode': stop_group(child)})
            except Exception as error:
                summary['passed'] = False
                summary['cleanup'].append({'pid': child.pid, 'error': str(error)})
        for handle in logs:
            handle.close()
        (output / 'summary.json').write_text(json.dumps(summary, indent=2)+'\n')
    print(json.dumps(summary, indent=2))
    raise SystemExit(0 if summary['passed'] else 1)


if __name__ == '__main__':
    main()
