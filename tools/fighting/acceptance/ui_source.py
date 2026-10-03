"""Source contract and real export identity checks for the production UI journey."""
import hashlib
import json
from pathlib import Path
import re

from source import IDS, STATES, read_glb, require


def audit(root):
    root = Path(root)
    fixture = root / 'godot/tests/fighting/acceptance/ui_journey.gd'
    script = fixture.read_text()
    # These paths would make an input-driven UI proof a disguised core driver.
    forbidden = [r'shell\.[\w.]+\s*=(?!=)', r'shell\.[\w.]+\s*\+=',
                 r'shell\.simulation\.(step|load_state|training_reset|start_match)\(',
                 r'shell\._\w+\(', r'\.notification\(', r'joy_connection_changed\.emit\(',
                 r'shell\.(start_match|resume_match|show_\w+|go_home)\(']
    for pattern in forbidden:
        require(not re.search(pattern, script), 'fixture bypasses production controls: ' + pattern)
    for source in ('Input.parse_input_event', 'change_scene_to_file("res://fighting/main.tscn")',
                   'shell.ai.save_state()', 'shell.simulation.save_state()', 'PoseBounds.new()',
                   'shell.camera.unproject_position', 'shell.router.bindings'):
        require(source in script, 'missing real observation/input contract: ' + source)
    roster_path = root / 'godot/fighting/data/roster.json'
    roster = json.loads(roster_path.read_text())
    content_hashes = {name: hashlib.sha256((root / path).read_bytes()).hexdigest() for name, path in {
        'roster': 'godot/fighting/data/roster.json', 'rules': 'godot/fighting/data/rules.json',
        'coverage': 'port/fighting/content/ANIMATION_COVERAGE.json'}.items()}
    outputs = {}
    for oid in IDS:
        base = root / 'godot/fighting/assets/operators' / oid
        manifest_path = base.with_suffix('.json')
        glb_path = base.with_suffix('.glb')
        manifest = json.loads(manifest_path.read_text())
        require(manifest['operator_id'] == oid and manifest['version'] == 1, oid + ' manifest identity')
        require(manifest['content_hashes'] == content_hashes, oid + ' canonical content timing hashes')
        require(manifest['sha256'] == hashlib.sha256(glb_path.read_bytes()).hexdigest(), oid + ' real GLB identity')
        doc, _ = read_glb(glb_path)
        actual = {a['name'] for a in doc.get('animations', [])}
        profile = next(o for o in roster['operators'] if o['id'] == oid)
        needed = set(STATES) | {m['animation'] for m in profile['moves'].values()}
        needed |= {'victim_' + attacker['id'] + '_' + mid for attacker in roster['operators']
                   for mid, move in attacker['moves'].items() if 'throw' in move or move.get('counter', {}).get('strike')}
        require(needed <= manifest['clips'].keys(), oid + ' state/combat/victim manifest coverage')
        # Current production is self-contained. Do not demand duplicate storage
        # when the production manifest eventually supplies a proved alias transport.
        require(manifest['shared_victims']['transport'] == 'self_contained_glb_until_native_shared_library_proof',
                oid + ' clip transport changed; coordinate real alias resolution, do not waive coverage')
        require(set(manifest['clips']) == actual, oid + ' exact exported clip resolution')
        for name, clip in manifest['clips'].items():
            keys = clip['seek_keys']
            require(len(keys) >= 2 and clip['duration'] > 0, oid + ':' + name + ' bounded seek map')
            require(all(a[0] < b[0] and a[1] <= b[1] for a, b in zip(keys, keys[1:])), oid + ':' + name + ' seek order')
        imported = Path(str(glb_path) + '.import').read_text()
        for token in ('animation/fps=60', 'skins/use_named_skins=true', '"compression/enabled": false', '"optimizer/enabled": false'):
            require(token in imported, oid + ' immutable lossless import setting: ' + token)
        outputs[oid] = {'glb_sha256': manifest['sha256'], 'manifest_sha256': hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
                        'import_sha256': hashlib.sha256(imported.encode()).hexdigest(), 'resolved_stored_clips': len(actual)}
    return {'status': 'passed', 'scope': 'source contracts and actual exported identities only',
            'exports': outputs, 'content_hashes': content_hashes, 'native_execution': 'pending',
            'not_claimed': ['native UI execution', 'contact anatomy waiver', 'signature motion waiver', 'human review']}
