"""Explicit serial-grant corrective build; never invoked by source tests.

python3 native_harness.py --output-root /tmp/opencode/abyssal-corrective-<grant> run
Requires an exclusive heavy grant, Blender 4.5.14 and Godot 4.5.1. One run,
one immutable output directory. Each phase has a bounded process group.
"""
import argparse
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
sys.path.insert(0, str(ROOT / 'tools/godot-multiplayer/new-maps/map_variety'))
from glb_geometry import EmbeddedGlb

IDENTITY = 'ee979520743dd4c73ac0d825774a2c99b5a8d85800a6eead5170f261abe61bea'
OLD_GLB = '925883eff465b7d470a36e215107420228ca8f537a08f2e3a7a879231668bfe7'
LOCK = Path('/tmp/opencode/cocs-finish-acceptance.lock')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def guard_output(path):
    """No implicit defaults, symlink traversal, archival names, or existing output."""
    path = Path(path).expanduser().absolute()
    forbidden = ('native-t-20261003', 'revision2', 'worlds', 'generated',
                 'accepted', 'production', 'stormglass')
    if any(token in str(path).lower() for token in forbidden):
        raise ValueError('Output path overlaps a frozen or accepted namespace')
    if any(p.is_symlink() for p in (path, *path.parents)):
        raise ValueError('Output path traverses symlink')
    if path.exists() or not path.parent.is_dir():
        raise ValueError('Output must be a new directory with an existing parent')
    if path == ROOT or ROOT in path.parents or path in ROOT.parents:
        raise ValueError('Output must be outside the source repository')
    if 'abyssal-corrective-' not in path.name.lower():
        raise ValueError('Output directory name must include abyssal-corrective-<grant>')
    return path


def inventory():
    found = []
    for stat in Path('/proc').glob('[0-9]*/stat'):
        try:
            line = stat.read_text()
            fields = line[line.rfind(')') + 2:].split()
            found.append({'pid': int(stat.parent.name), 'pgid': int(fields[2]),
                          'startTicks': int(fields[19]),
                          'comm': (stat.parent / 'comm').read_text().strip()})
        except (OSError, IndexError, ValueError):
            continue
    return found


def atomic_json(path, payload):
    tmp = path.with_suffix(path.suffix + '.part')
    tmp.write_text(json.dumps(payload, indent=2) + '\n')
    tmp.replace(path)


def run_phase(output, label, command, seconds, *, cwd=ROOT):
    # Never adopt or kill unrelated groups. A process is ours only if its PID
    # and Linux kernel start tick still match the launch receipt.
    before = inventory()
    log = output / (label + '.log')
    receipt = output / (label + '.receipt.json')
    with log.open('xb') as stream:
        process = subprocess.Popen(command, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        launched = next(p for p in inventory() if p['pid'] == process.pid)
        record = {'label': label, 'command': [str(c) for c in command], 'cwd': str(cwd),
                  'launched': launched, 'baseline': [p for p in before if any(
                      s in p['comm'].lower() for s in ('godot', 'blender', 'xvfb', 'ffmpeg'))],
                  'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'timeoutSeconds': seconds}
        atomic_json(receipt, record)
        try:
            code = process.wait(timeout=seconds)
        except subprocess.TimeoutExpired:
            record['timedOut'] = True
            code = 124
        finally:
            # Also clean surviving children of successful launches; three
            # successive empty owned-group audits are required for closure.
            for sig in (signal.SIGTERM, signal.SIGKILL):
                live = inventory()
                if any(p['pid'] == launched['pid'] and p['startTicks'] != launched['startTicks'] for p in live):
                    break  # PID recycled: never signal the new group.
                if not any(p['pgid'] == launched['pgid'] and p['startTicks'] >= launched['startTicks'] for p in live):
                    break
                try:
                    os.killpg(launched['pgid'], sig)
                except ProcessLookupError:
                    pass
                time.sleep(.5)
            audits = []
            for _ in range(3):
                owned = [p for p in inventory() if p['pgid'] == launched['pgid'] and p['startTicks'] >= launched['startTicks']]
                audits.append(owned)
                time.sleep(.2)
            record.update({'exitCode': code, 'ownedGroupAudits': audits, 'logSha256': sha(log)})
            atomic_json(receipt, record)
        if code or any(audits):
            raise RuntimeError('%s failed/left owned processes: %s' % (label, receipt))


def validate_export(path, report):
    if sha(path) != report['glbSha256'] or sha(path) == OLD_GLB:
        raise ValueError('Missing, changed or rejected T export')
    glb = EmbeddedGlb(path.read_bytes())
    parts, count, used = glb.geometry()
    if (len(parts) != report['glbPrimitives'] or count != report['glbTriangles'] or
            len(parts) > 64 or not used or report['geometryHash'] != IDENTITY or
            count != report['exportTriangles']):
        raise ValueError('Full scene primitive/triangle/identity mismatch')
    return {'primitives': len(parts), 'triangles': count, 'materialIndices': sorted(used)}


def stage(output, report):
    """A separate throwaway Godot copy, never the accepted art/JSON checkout."""
    project = output / 'project'
    # Owner worktrees use a sparse checkout. Copying the on-disk godot/ subtree
    # silently omitted Binder, material language, shaders and autoloads in V1.
    # Archive exactly committed HEAD:godot into the private stage instead.
    import tarfile
    project.mkdir()
    archive = subprocess.Popen(['git', 'archive', 'HEAD', 'godot'], cwd=ROOT, stdout=subprocess.PIPE)
    stage_prefixes = ('godot/moth/', 'godot/moth_scenery/', 'godot/material_language/',
                      'godot/multiplayer_worlds/dressing/',
                      'godot/tests/new_maps/abyssal_pressureworks/corrective/')
    stage_exact = ('godot/multiplayer_worlds/map.gd',
                   'godot/multiplayer_worlds/abyssal_presentation.gd',
                   'godot/multiplayer_worlds/art/worlds/abyssal-pressureworks.glb',
                   'godot/multiplayer_worlds/generated/abyssal-pressureworks.json')
    try:
        with tarfile.open(fileobj=archive.stdout, mode='r|') as tar:
            for member in tar:
                relative = Path(member.name)
                if not relative.parts or relative.parts[0] != 'godot' or '..' in relative.parts or member.issym() or member.islnk():
                    raise ValueError('Unexpected Git project archive member: ' + member.name)
                if not member.name.startswith(stage_prefixes) and member.name not in stage_exact:
                    continue
                dest = project.joinpath(*relative.parts[1:])
                if member.isdir():
                    dest.mkdir(parents=True, exist_ok=True)
                elif member.isfile():
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    with tar.extractfile(member) as source, dest.open('xb') as target:
                        shutil.copyfileobj(source, target)
        if archive.wait(timeout=120):
            raise ValueError('Committed Godot project archive failed')
    finally:
        archive.stdout.close()
        if archive.poll() is None:
            archive.kill()
            archive.wait()
    (project / 'project.godot').write_text(
        'config_version=5\n[application]\nconfig/name="Abyssal Corrective V Isolated Test Stage"\n'
        '[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
        'renderer/rendering_method.mobile="gl_compatibility"\n'
        'environment/defaults/default_clear_color=Color(0.035, 0.05, 0.08, 1)\n')
    target = project / 'tests/new_maps/abyssal_pressureworks/corrective'
    target.mkdir(parents=True, exist_ok=True)
    shutil.copy2(output / 'corrective.glb', target / 'corrective.glb')
    shutil.copy2(HERE / 'candidate.json', target / 'candidate.json')
    shutil.copy2(HERE / 'probes.json', target / 'probes.json')
    if sha(target / 'corrective.glb') != report['glbSha256']:
        raise ValueError('Staged art differs from audited export')
    if sha(target / 'candidate.json') != sha(HERE / 'candidate.json'):
        raise ValueError('Staged authority differs from corrected source')
    probes = json.loads((target / 'probes.json').read_text())
    if probes['geometryHash'] != IDENTITY or len(probes['points']) != 501:
        raise ValueError('Staged route probes are not corrective source')
    # A copy-local exact identity in the real production Binder schema; never
    # edit the source checkout's accepted identities or material definitions.
    schema = project / 'multiplayer_worlds/dressing/profile.gd'
    text = schema.read_text()
    needle = 'const IDENTITIES := {\n'
    if text.count(needle) != 1 or '"abyssal-pressureworks":' in text:
        raise ValueError('Unexpected accepted dressing schema identity')
    schema.write_text(text.replace(needle, needle + '\t"abyssal-pressureworks": "' + IDENTITY + '",\n'))
    exported = EmbeddedGlb((target / 'corrective.glb').read_bytes())
    _, _, used_materials = exported.geometry()
    selectors = sorted(exported.doc['materials'][i]['name'] for i in used_materials)
    profile = {'version': 1, 'map_id': 'abyssal-pressureworks', 'geometry_hash': IDENTITY,
               'materials': [], 'panels': [], 'signs': [], 'pockets': [
                   {'id': 'corrective-service-vent-sw', 'kind': 'vent', 'position': [-94, 10.3, -94],
                    'size': [1.5, 1.5, 1.5], 'color': 'a9d5de', 'count': 6},
                   {'id': 'corrective-service-vent-se', 'kind': 'vent', 'position': [91, 4.3, -90],
                    'size': [1.5, 1.5, 1.5], 'color': 'a9d5de', 'count': 6}],
               'preserve_materials': selectors,
               'budgets': {'material_variants': 0, 'panels': 0, 'signs': 0, 'motes': 12}}
    profile_path = project / 'multiplayer_worlds/dressing/profiles/abyssal-pressureworks.json'
    atomic_json(profile_path, profile)
    manifest = {'geometryHash': IDENTITY, 'candidateSha256': sha(target / 'candidate.json'),
                'glbSha256': sha(target / 'corrective.glb'), 'masterSha256': report['masterSha256'],
                'probesSha256': sha(target / 'probes.json'),
                'reportSha256': sha(output / 'material-report.json'),
                'stageSchemaSha256': sha(schema), 'stageProfileSha256': sha(profile_path),
                'stage': 'isolated test-only project; production Binder with candidate-only preserve-PBR profile; weather not present in parent snapshot; no runtime promotion',
                'pending': ['production weather/finish assessment', 'host modes', 'camera sweep']}
    atomic_json(target / 'stage-manifest.json', manifest)
    atomic_json(output / 'stage-manifest.json', manifest)
    return project


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-root', required=True, help='NEW non-symlink external corrective namespace')
    parser.add_argument('--blender', default='blender')
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--grant', required=True, help='Exact exclusive grant label recorded in every V attempt')
    parser.add_argument('--prior-root', type=Path, help='Read-only verified prior V attempt when resuming stage')
    parser.add_argument('command', choices=['run', 'resume-stage'])
    args = parser.parse_args(argv)
    output = guard_output(args.output_root)
    candidate = json.loads((HERE / 'candidate.json').read_text())
    if candidate['geometryHash'] != IDENTITY:
        raise ValueError('Corrective source identity drift')
    with LOCK.open('a+') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)  # no waiting on U or another owner
        output.mkdir(mode=0o700)
        atomic_json(output / 'inputs.json', {'grant': args.grant, 'geometryHash': IDENTITY,
                    'candidateSha256': sha(HERE / 'candidate.json'),
                    'bindingsSha256': sha(HERE / 'materials.bindings.json'),
                    'authorSha256': sha(HERE / 'author.py'),
                    'builderSha256': sha(ROOT / 'tools/map-variety-support/build_entry.py'),
                    'git': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                    'blender': args.blender, 'godot': args.godot,
                    'startedUtc': datetime.datetime.now(datetime.timezone.utc).isoformat()})
        blend = output / 'corrective.blend'
        glb = output / 'corrective.glb'
        report_path = output / 'material-report.json'
        if args.command == 'run':
            run_phase(output, '01-build', [args.blender, '-b', '-t', '1', '--python-exit-code', '1',
                  '--python', str(HERE / 'author.py'), '--', '--root', str(ROOT),
                  '--blend', str(blend), '--glb', str(glb), '--report', str(report_path)], 1800)
        else:
            if not args.prior_root or not args.prior_root.is_dir() or args.prior_root.resolve() == output:
                raise ValueError('resume-stage requires an explicit distinct prior V attempt')
            prior = args.prior_root.resolve()
            old_inputs = json.loads((prior / 'inputs.json').read_text())
            if old_inputs['geometryHash'] != IDENTITY or old_inputs['candidateSha256'] != sha(HERE / 'candidate.json') or old_inputs['bindingsSha256'] != sha(HERE / 'materials.bindings.json'):
                raise ValueError('Prior V candidate inputs differ')
            for label in ('01-build', '02-reopen', '03-master-reexport', '04-geometry-audit'):
                receipt = json.loads((prior / (label + '.receipt.json')).read_text())
                if receipt.get('exitCode') != 0 or any(receipt['ownedGroupAudits']) or receipt['logSha256'] != sha(prior / (label + '.log')):
                    raise ValueError('Prior V phase is not verified: ' + label)
            for name in ('corrective.blend', 'corrective.glb', 'reexport.glb', 'material-report.json', 'geometry-audit.json'):
                shutil.copyfile(prior / name, output / name)
            atomic_json(output / 'resume-lineage.json', {'sourceAttempt': str(prior), 'grant': args.grant,
                         'readOnlyHashes': {name: sha(prior / name) for name in
                            ('corrective.blend', 'corrective.glb', 'reexport.glb', 'material-report.json', 'geometry-audit.json')}})
        report = json.loads(report_path.read_text())
        if sha(blend) != report['masterSha256'] or report['geometryHash'] != IDENTITY:
            raise ValueError('Builder master/authority mismatch')
        validate_export(glb, report)
        if args.command == 'run':
            run_phase(output, '02-reopen', [args.blender, '-b', '-t', '1', '--python-exit-code', '1',
                      '--python', str(ROOT / 'tools/map-variety-support/verify_master.py'), '--',
                      '--blend', str(blend), '--report', str(report_path)], 480)
            run_phase(output, '03-master-reexport', [args.blender, '-b', '-t', '1', '--python-exit-code', '1',
                      '--python', str(HERE / 'reexport_master.py'), '--', '--blend', str(blend),
                      '--output', str(output / 'reexport.glb'), '--report', str(report_path)], 600)
        # Compare independent geometry and pixels even on a read-only resume.
        run_phase(output, '04-geometry-audit' if args.command == 'run' else '04-resumed-geometry-audit',
                  [sys.executable, str(HERE / 'audit_corrective.py'), '--output-root', str(output)], 360)
        project = stage(output, report)
        run_phase(output, '05-import', [args.godot, '--headless', '--path', str(project), '--editor', '--import', '--quit'], 360)
        run_phase(output, '06-world-check', [args.godot, '--headless', '--path', str(project), '--script',
                  'res://tests/new_maps/abyssal_pressureworks/corrective/world_check.gd', '--',
                  '--report=' + str(output / 'world-check.json')], 360)
        run_phase(output, '07-paired-capture', ['xvfb-run', '-a', '-s', '-screen 0 1280x720x24',
                  args.godot, '--display-driver', 'x11', '--path', str(project), '--script',
                  'res://tests/new_maps/abyssal_pressureworks/corrective/capture.gd', '--',
                  '--output=' + str(output / 'captures')], 600)
        capture = json.loads((output / 'captures/capture-report.json').read_text())
        if len(capture['captures']) != 16 or any(
                sha(item['file']) != item['sha256'] or item['width'] != 1280 or item['height'] != 720
                for item in capture['captures']):
            raise ValueError('Paired capture PNG inventory or original hashes incomplete')
        print(json.dumps({'status': 'native checks and paired images recorded; host-mode review pending',
                          'output': str(output), 'manifest': str(output / 'stage-manifest.json')}))


if __name__ == '__main__':
    main()
