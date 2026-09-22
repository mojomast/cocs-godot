#!/usr/bin/env python3
"""Check retained receipts/provenance; PNG visual inspection is documented separately."""
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
BIN = Path('/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64')
DEPS = Path('/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules')

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def git(*args): return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()
def digest(files): return hashlib.sha256(json.dumps(files, sort_keys=True, separators=(',', ':')).encode()).hexdigest()

def main():
    lock = json.loads((ROOT / 'port/contracts/source-lock.json').read_text())
    source_paths = git('ls-files', 'game', 'server', 'package.json', 'package-lock.json').splitlines()
    if git('diff', lock['source_commit'], '--', *source_paths): raise RuntimeError('Source differs from lock')
    runtime_paths = [p for p in git('ls-files', 'godot').splitlines() if p.endswith(('.gd', '.tscn', '.godot')) and '/tests/' not in p]
    if git('diff', '99c0a93', '--', *runtime_paths): raise RuntimeError('Runtime differs from delivery')
    source = {p:sha(ROOT / p) for p in source_paths}
    runtime = {p:sha(ROOT / p) for p in runtime_paths}
    selected = []
    for resolution in ['960x640', '1280x800']:
        for sport, right, targets in [('ion-speedway', '00-spawn', ['gate']), ('aurora-stadium', '00b-right', ['ball', 'opponent'])]:
            directory = OUT / 'live' / (sport + '-' + resolution + ('-goal' if sport == 'aurora-stadium' else ''))
            for label, side in [(right, 'Right'), ('02-turn', 'Left')]:
                receipt = json.loads((directory / (label + '.json')).read_text())
                png = directory / (label + '.png')
                dimensions = struct.unpack('!II', png.read_bytes()[16:24])
                if list(dimensions) != receipt['viewport']: raise RuntimeError('PNG/viewport mismatch')
                if receipt['png_error'] or not receipt['eligible']: raise RuntimeError('Invalid capture')
                for target in targets:
                    projection = receipt['projections'][target]
                    x, y = projection['pixel']
                    if projection['behind_camera'] or not (0 < x < dimensions[0] and 0 < y < dimensions[1]): raise RuntimeError('Target outside view')
                    if (x > dimensions[0]/2) != (side == 'Right'): raise RuntimeError('Wrong projected side')
                    prefix = {'gate':'Next gate 1', 'ball':'Ball', 'opponent':'Opponent goal'}[target]
                    expected = prefix + (' · ' if target == 'gate' else ' ') + side
                    if expected not in receipt['hud']: raise RuntimeError('HUD disagrees with camera projection')
                    source_target = receipt['race']['gates'][0] if target == 'gate' else (receipt['race']['ball'] if target == 'ball' else receipt['race']['goals'][1])
                    # The demo's presentation selection can precede its newest network
                    # snapshot by one frame. Ball projection reads that actual held
                    # selection; seq/race describe the newest snapshot at capture.
                    # Do not silently attribute the earlier ball to the newer seq.
                    if target != 'ball' and projection['source'] != source_target: raise RuntimeError('Static source geometry changed')
                    selected.append(dict(png=str(png.relative_to(OUT)), target=target, side=side, latest_seq=receipt['seq'], pixel=projection['pixel'],
                        selection_matches_latest_snapshot=projection['source'] == source_target,
                        source_basis='demo.soccer_guidance.selection.ball (accepted public snapshot)' if target == 'ball' else 'latest accepted race geometry'))
    cleanups = []
    for directory in sorted((OUT / 'live').iterdir()):
        cleanup = json.loads((directory / 'cleanup.json').read_text())
        wire = json.loads((directory / 'wire.json').read_text())
        if not cleanup['port_closed'] or not all(cleanup['pids_absent'].values()): raise RuntimeError('Cleanup failed')
        if wire['cleanup'] != {'serverClosed':True, 'sockets':0}: raise RuntimeError('Server cleanup failed')
        if 'ERROR:' in (directory / 'native.log').read_text(): raise RuntimeError('Native runtime error')
        cleanups.append(dict(case=directory.name, **cleanup))
    before_sources = {
        'ion-right-labelled-left.png':'race/07-restart.png',
        'soccer-ball-right-labelled-left.png':'soccer/02-driving.png',
        'soccer-goal-right-labelled-left.png':'soccer/04-stationary-bearing.png',
    }
    before = {}
    for name, path in before_sources.items():
        obj = '29b0a595f3be79fdef784526a8011cacd7e7edb8:port/native-usability-audit/' + path
        original = subprocess.check_output(['git', 'show', obj], cwd=ROOT)
        if (OUT / 'before' / name).read_bytes() != original: raise RuntimeError('Before image changed')
        before[name] = dict(git_object=git('rev-parse', obj), source=path, sha256=sha(OUT / 'before' / name))
    ws = {str(p.relative_to(DEPS)):sha(p) for p in sorted((DEPS / 'ws').rglob('*')) if p.is_file()}
    evidence = {str(p.relative_to(OUT)):sha(p) for folder in ['before', 'live', 'tests'] for p in sorted((OUT / folder).rglob('*')) if p.is_file()}
    report = dict(status='PASS', baseline=git('rev-parse', '5445295'), runtime_commit=git('rev-parse', '99c0a93'), source_commit=lock['source_commit'],
        environment=dict(godot=subprocess.check_output([str(BIN), '--version'], text=True).strip(), godot_binary=str(BIN), godot_sha256=sha(BIN), node=subprocess.check_output(['node','--version'],text=True).strip(), python=sys.version, deps=str(DEPS), ws_files=ws),
        source_files=source, source_tree_sha256=digest(source), runtime_files=runtime, runtime_tree_sha256=digest(runtime),
        semantic_manifest_sha256=sha(ROOT / 'godot/content/generated/manifest.json'),
        observer_sha256=sha(ROOT / 'godot/tests/sports/bearing_observe.gd'), before=before,
        projected_sidedness_receipts=selected, cleanup=cleanups, evidence_sha256=evidence,
        limits='Receipt validation corroborates separately opened PNGs. No human/OS feel, exported package, lap/goal or aggregate-suite claim.')
    (OUT / 'provenance.json').write_text(json.dumps(report, indent=2)+'\n')
    print('PASS: 12 source-snapshot projected-side/HUD receipts, 5 clean sessions, 3 exact auditor PNGs; source/runtime hashes recorded')

if __name__ == '__main__': main()
