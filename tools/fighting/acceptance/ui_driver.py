"""Bounded production UI producer. Source/receipt operations never launch engines."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import sys
import uuid
import zlib

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools/godot-dev'))
from gate_runner import save_report
import finish_runner as finish
from finish_receipts import checked_file, require_complete, sha, validate_output_checks
from run import identity
from ui_os_bridge import Bridge

STAGES = ('basalt-reach', 'canopy-divide', 'crown-array', 'helix-conservatory')
PROFILES = ('wide100', 'compact150')
GATE = 'fighting-four-stage-training-review'
SCRIPT = 'res://tests/fighting/acceptance/ui_journey.gd'
MARKER = 'FIGHTING_UI_JOURNEY_OK'
ERRORS = re.compile(r'SCRIPT ERROR|Parse Error|ERROR:|ObjectDB instances leaked|resources still in use|RID[^\n]*leak', re.I)
REQUIRED_LABELS = {
    'training frame advance executes exactly one step',
    'training replay matches saved state at EVERY recorded tick',
    'training replay terminal state exact', 'public reset clears completed replay',
    'recorded training attack produces real damage/contact',
    'AI executes exactly once per active fight tick',
    'paused simulation and AI clock/RNG/history do not advance',
    'resume advances live AI without catch-up burst',
    'inactive selection preserves AI/simulation exactly',
    'focus loss releases both actors and queued edges',
    'focus return never replays stale held inputs',
    'both actors accept fresh edges after focus recovery',
    'disconnect releases BOTH actors', 'cannot resume with missing assigned device',
    'device label never claims keyboard while routing disconnected pad',
    'actual Home scene entered', 'Home frees fighting scene and observers hold no owning reference',
    'all sampled real body envelopes remain HUD-safe',
}
REVIEW_UNITS = set(STAGES) | {'training-reset-input', 'AI-pause-resume', 'two-actor-device-loss',
                            'responsive-camera-readability', 'camera-smoothing-reset', 'pose-cache-build-and-frame-cost'}


def require(value, message):
    if not value:
        raise ValueError(message)


def post_exit(result, log):
    require(result.get('status') == 'passed' and result.get('exit_code') == 0 and not result.get('failure_reason'), 'native process did not exit cleanly')
    require(result.get('cleanup') == {'signalled': [], 'remaining': []}, 'native descendants leaked or cleanup inventory absent')
    require(not ERRORS.search(log), 'post-exit engine/parser/resource-leak error')


def png_dimensions(raw):
    require(raw[:8] == b'\x89PNG\r\n\x1a\n', 'actual PNG required')
    offset, kinds, dimensions = 8, [], None
    while offset < len(raw):
        require(offset + 12 <= len(raw), 'truncated PNG chunk')
        size = struct.unpack_from('>I', raw, offset)[0]
        kind = raw[offset+4:offset+8]
        require(offset + 12 + size <= len(raw), 'truncated PNG payload')
        payload = raw[offset+8:offset+8+size]
        checksum = struct.unpack_from('>I', raw, offset+8+size)[0]
        require(zlib.crc32(kind + payload) & 0xffffffff == checksum, 'PNG CRC mismatch')
        if kind == b'IHDR':
            require(not kinds and size == 13, 'PNG IHDR order/size')
            dimensions = struct.unpack_from('>II', payload)
        kinds.append(kind)
        offset += size + 12
        if kind == b'IEND':
            require(size == 0 and offset == len(raw), 'PNG trailing/truncated data')
            break
    require(dimensions and b'IDAT' in kinds and kinds[-1] == b'IEND', 'incomplete PNG image')
    return dimensions


def validate_native(data, directory):
    require_complete(data)
    checks = data.get('checks', [])
    require(checks and all(c.get('passed') is True for c in checks), 'all native assertions must execute and pass')
    require(REQUIRED_LABELS <= {c.get('label') for c in checks}, 'missing lifecycle/input/replay coverage')
    require(data.get('replay_frames', 0) > 30, 'actual tick-by-tick recorded replay required')
    cases = data.get('cases', [])
    neutral = [c for c in cases if c['id'].endswith('/neutral')]
    require({(c['stage'], 'compact150' if c['scale'] == 1.5 else 'wide100') for c in neutral}
            == {(s, p) for s in STAGES for p in PROFILES} and len(neutral) == 8, 'exact four-stage/two-layout coverage required')
    require({operator for c in neutral for operator in c['operators']}
            == set('chatgpt claude grok meta gemini deepseek mistral kimi qwen'.split()), 'nine actual rigs must appear in representative production views')
    for case in cases:
        name = Path(case['image'])
        require(not name.is_absolute() and len(name.parts) == 1, 'invalid native image scope')
        image = directory / name
        require(image.is_file() and not image.is_symlink(), 'missing retained native PNG')
        raw = image.read_bytes()
        width, height = png_dimensions(raw)
        require(width > 0 and height > 0 and case['tick'] > 0 and case['render_frame'] > 0, 'capture has no real frame/tick')
        require(case['camera'].get('inside') is True and len(case['camera'].get('poses', [])) == 2, 'native body/HUD containment missing')
        require(case.get('controls') and case.get('utc'), 'capture lacks HUD bounds/time metadata')
        if case['scale'] == 1.5:
            require(case['window'] == [760, 520] and case['fullscreen'] is False, 'actual compact UI150 window required')
        else:
            require(case['scale'] == 1.0 and case['fullscreen'] is True, 'actual wide fullscreen UI100 required')
    events = [row['event'] for row in data.get('contacts', [])]
    for actor in (0, 1):
        for kind in ('throw_start', 'throw_hit', 'throw_tech'):
            require(any(e.get('actor') == actor and e.get('type') == kind for e in events), f'actual actor {actor} {kind} missing')
    disconnects = [c.get('measured', {}).get('disconnected_actor') for c in checks if c.get('label') == 'disconnect releases BOTH actors']
    require(sorted(disconnects) == [0, 1], 'both distinct virtual-pad disconnections required')
    samples = data.get('camera_samples', [])
    require(len(samples) > 50 and all(s.get('inside') is True for s in samples), 'all real pose projections must be safe')
    require(any(s.get('sampling_usec', 0) > 0 for s in samples), 'actual per-frame pose timing required')
    require('physical controller unplug' in data.get('not_claimed', []), 'virtual inputs cannot certify physical hardware')
    return {'stage_layouts': len(neutral), 'native_images': len(cases), 'replay_frames': data['replay_frames'],
            'camera_samples': len(samples), 'real_event_count': len(events)}


def anchor_identity(root, matrix_path, anchor_path):
    anchor = json.loads(anchor_path.read_text())
    matrix = finish.load_matrix(matrix_path, root=root)
    observed = finish.input_identity(root, matrix, anchor['input_identity']['environment'])
    require(observed == anchor['input_identity'], 'exact canonical finish anchor differs; create a new anchor before execution')
    require(anchor.get('queue') == matrix['jobs'], 'canonical queue differs from anchor')
    return observed, matrix


def worker(args):
    """Executed only as an owned child under the grant-gated serial supervisor."""
    directory = args.output.resolve()
    require(isinstance(args.token, str) and re.fullmatch(r'[a-f0-9]{32}', args.token)
            and os.environ.get('FIGHTING_UI_WORKER_TOKEN') == args.token
            and os.environ.get('FIGHTING_UI_GRANT')
            and not os.environ['FIGHTING_UI_GRANT'].startswith('ROBOT-'), 'worker requires owned grant-bound launch token')
    env = dict(os.environ)
    env.update(FIGHTING_ACCEPTANCE_EVIDENCE=str(directory), LP_NUM_THREADS='1')
    camera_command = [str(args.godot), '--headless', '--path', str(args.root / 'godot'), '--script',
                      'res://tests/fighting/presentation/camera_gate.gd']
    camera = finish.run_bounded(camera_command, args.root, env, directory / 'camera.log', 60)
    post_exit(camera, (directory / 'camera.log').read_text())
    validate_output_checks({'output_checks': [{'prefix': 'FIGHTING_CAMERA_GATE'}]}, (directory / 'camera.log').read_text())
    bridge = Bridge(directory, env['DISPLAY'], args.token[:12])
    bridge.start()
    try:
        command = [str(args.godot), '--path', str(args.root / 'godot'), '--resolution', '1280x800',
                   '--script', SCRIPT]
        result = finish.run_bounded(command, args.root, env, directory / 'native.log', 600)
    finally:
        bridge_report = bridge.close()
        save_report(directory / 'os-bridge.json', bridge_report)
    text = (directory / 'native.log').read_text()
    post_exit(result, text)
    require(text.splitlines().count(MARKER) == 1, 'exact native success marker absent or repeated')
    validate_output_checks({'output_checks': [{'prefix': 'FIGHTING_UI_RESULT'}]}, text)
    require(not bridge_report['failures'], 'OS bridge failed or leaked')
    measured = validate_native(json.loads((directory / 'ui-native.json').read_text()), directory)
    save_report(directory / 'worker.json', {'status': 'passed', 'executed': True, 'camera': camera,
                'native': result, 'command': command, 'checks': measured, 'failures': [], 'unrun': []})
    return 0


def native(args):
    require(args.heavy_grant, 'explicit UI/native heavy grant required; robot grant is not transferable')
    require(not args.heavy_grant.startswith('ROBOT-'), 'robot-production grant cannot authorize fighting UI execution')
    require(args.godot and args.godot.is_file(), 'explicit Godot binary required')
    require(os.access('/dev/uinput', os.W_OK), '/dev/uinput write access required for real virtual hotplug; no injected-signal fallback')
    require(shutil.which('Xvfb') and shutil.which('xdotool'), 'private Xvfb and xdotool required')
    root = args.root.resolve()
    directory = args.output.resolve() / ('ui-' + uuid.uuid4().hex)
    directory.mkdir(parents=True, exist_ok=False)
    token = uuid.uuid4().hex
    report = {'version': 1, 'status': 'running', 'executed': False, 'grant': args.heavy_grant,
              'candidate': identity(root), 'binary_sha256': sha(args.godot), 'failures': [], 'unrun': []}
    from ui_source import audit
    report['source'] = audit(root)
    matrix = None
    if args.finish_anchor:
        report['input_identity'], matrix = anchor_identity(root, args.finish_matrix, args.finish_anchor)
        report['finish_anchor'] = {'path': str(args.finish_anchor.resolve()), 'sha256': sha(args.finish_anchor)}
    save_report(directory / 'producer.json', report)
    # Shared parent runner may already own its cohort lock. A separate fighting
    # lock prevents nested fighting producers without deadlocking delegated runs.
    import fcntl
    with Path('/tmp/opencode/cocs-fighting-acceptance.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        env = finish.isolated_environment(directory / 'user')
        env['FIGHTING_UI_WORKER_TOKEN'] = token
        env['FIGHTING_UI_GRANT'] = args.heavy_grant
        command = [sys.executable, str(root / 'tools/godot-dev/xvfb_run.py'), sys.executable,
                   str(Path(__file__).resolve()), 'worker', '--root', str(root), '--output', str(directory),
                   '--godot', str(args.godot.resolve()), '--token', token]
        result = finish.run_bounded(command, root, env, directory / 'supervisor.log', 700)
    report['process'] = result
    try:
        post_exit(result, (directory / 'supervisor.log').read_text())
        executed = json.loads((directory / 'worker.json').read_text())
        require_complete(executed)
        report['checks'] = validate_native(json.loads((directory / 'ui-native.json').read_text()), directory)
        report['candidate_after'] = identity(root)['sha256']
        require(report['candidate_after'] == report['candidate']['sha256'], 'candidate mutated during native execution')
        if matrix is not None:
            require(finish.input_identity(root, matrix, report['input_identity']['environment']) == report['input_identity'], 'canonical input anchor changed during native run')
        report.update(status='passed', executed=True)
    except (ValueError, OSError, KeyError) as error:
        report.update(status='failed')
        report['failures'].append(str(error))
    report['artifacts'] = {str(p.relative_to(directory)): {'path': str(p.resolve()), 'sha256': sha(p)}
                           for p in directory.rglob('*') if p.is_file() and p.name != 'producer.json'}
    save_report(directory / 'producer.json', report)
    print(json.dumps({'status': report['status'], 'report': str(directory / 'producer.json')}))
    if report['status'] == 'passed':
        print('FIGHTING_PRODUCTION_UI_DRIVER_OK')
    return 0 if report['status'] == 'passed' else 1


def receipt(args):
    """Export typed owner closure only after actual execution AND explicit review.

    Never re-anchor old evidence. An unanchored standalone run cannot be promoted.
    The existing receipt-only job also requires human stage/readability/GPU review,
    so numerical UI success alone is intentionally insufficient.
    """
    producer = json.loads(args.producer.read_text())
    require_complete(producer)
    require(producer.get('input_identity') and producer.get('finish_anchor'), 'run was not bound to a finish anchor at launch')
    for artifact in producer['artifacts'].values():
        checked_file(artifact)
    current, matrix = anchor_identity(args.root, args.finish_matrix, args.finish_anchor)
    require(current == producer['input_identity'], 'historical producer cannot be re-stamped for another anchor')
    job = next(j for j in matrix['jobs'] if j['id'] == GATE)
    require(job.get('receipt_only') and job['evidence_kind'] == 'native-stage-training-lifecycle', 'parent receipt contract changed')
    require(set(job['units']) == REVIEW_UNITS, 'parent review units changed; do not auto-bless new critical coverage')
    review = json.loads(args.review.read_text())
    require(review.get('status') == 'passed' and review.get('reviewer') and review.get('notes'), 'explicit owner review required')
    require(review.get('producer_sha256') == sha(args.producer) and review.get('input_identity') == current, 'review does not bind these exact executed bytes')
    required_reviews = {'four-stage-art-and-crop-seams', 'floor-head-hand-foot-contact-readability', 'camera-growth-shrink-hitstop-reset', 'hardware-gpu-frame-cost'}
    require(set(review.get('judgements', {})) == required_reviews and all(v == 'passed' for v in review['judgements'].values()), 'manual/GPU criticals remain unreviewed')
    require(review.get('artifacts'), 'review requires retained inspection/GPU evidence')
    for item in review['artifacts'].values():
        checked_file(item)
    native_file = checked_file(producer['artifacts']['ui-native.json'])
    validate_native(json.loads(native_file.read_text()), native_file.parent)
    artifacts = {**producer['artifacts'], 'producer': {'path': str(args.producer.resolve()), 'sha256': sha(args.producer)},
                 'owner-review': {'path': str(args.review.resolve()), 'sha256': sha(args.review)},
                 **{'review/' + name: item for name, item in review['artifacts'].items()}}
    closure = {'version': 1, 'gate': GATE, 'status': 'passed', 'executed': True, 'owner': review['reviewer'],
               'input_identity': current, 'resource_class': job['cohort'], 'evidence_kind': job['evidence_kind'],
               'units': {unit: 'passed' for unit in job['units']}, 'artifacts': artifacts,
               'execution_report': 'ui-native.json', 'failures': [], 'unrun': [],
               'scope': 'Executed production UI plus separately bound owner visual/GPU review; physical pad testing and human balance not claimed'}
    args.output.mkdir(parents=True, exist_ok=True)
    path = args.output / ('ui-owner-closure-' + uuid.uuid4().hex + '.json')
    save_report(path, closure)
    reference = path.with_suffix('.reference.json')
    save_report(reference, {'gate': GATE, 'adapter': 'owner-closure', 'report': {'path': str(path.resolve()), 'sha256': sha(path)}})
    print(json.dumps({'reference': str(reference)}))
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('source', 'native', 'worker', 'receipt'))
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--godot', type=Path)
    parser.add_argument('--heavy-grant')
    parser.add_argument('--token')
    parser.add_argument('--finish-anchor', type=Path)
    parser.add_argument('--finish-matrix', type=Path, default=ROOT / 'port/finish/final_matrix.json')
    parser.add_argument('--producer', type=Path)
    parser.add_argument('--review', type=Path)
    args = parser.parse_args()
    try:
        if args.mode == 'source':
            from ui_source import audit
            report = audit(args.root)
            args.output.mkdir(parents=True, exist_ok=True)
            path = args.output / ('ui-source-' + uuid.uuid4().hex + '.json')
            save_report(path, report)
            print(json.dumps({'status': report['status'], 'native': 'pending', 'report': str(path)}))
            return 0
        if args.mode == 'worker':
            return worker(args)
        if args.mode == 'native':
            return native(args)
        require(args.producer and args.review and args.finish_anchor, 'receipt needs producer, reviewed evidence and original finish anchor')
        return receipt(args)
    except (ValueError, OSError, KeyError, StopIteration) as error:
        print(json.dumps({'status': 'blocked' if args.mode == 'native' else 'failed', 'reason': str(error)}))
        return 2 if args.mode == 'native' else 1


if __name__ == '__main__':
    raise SystemExit(main())
