"""Read-only binding to Sol's authored data and paired placement contract."""
import hashlib
import json
from glb import GLB, source_rig
from recipes import OPERATORS, library


def inputs(root,roster_path=None):
    paths = {'roster':roster_path or root/'godot/fighting/data/roster.json',
             'rules':root/'godot/fighting/data/rules.json',
             'coverage':root/'port/fighting/content/ANIMATION_COVERAGE.json'}
    docs = {k:json.loads(p.read_text()) for k,p in paths.items()}
    hashes = {k:hashlib.sha256(p.read_bytes()).hexdigest() for k,p in paths.items()}
    roster = {o['id']:o for o in docs['roster']['operators']}
    pairs = {(p['attacker'],p['move']):p for p in docs['coverage']['paired_timelines']}
    rigs = {o:source_rig(GLB(root/'godot/source_operators/generated'/f'{o}.glb')) for o in OPERATORS}
    assert all(rig==rigs['meta'] for rig in rigs.values()), 'source rests changed; shared library requires review'
    libraries = {o:library(o) for o in OPERATORS}
    for operator in OPERATORS:
        entry = next(o for o in docs['coverage']['operators'] if o['id']==operator)
        required = set(entry['states'])|{c['clip'] for c in entry['combat']}|set(entry['victim_clips'])
        assert set(libraries[operator])==required, (operator,set(libraries[operator])^required)
    for (operator,move),pair in pairs.items():
        data = roster[operator]['moves'][move]
        meta = data.get('throw',data.get('counter',{}))
        assert pair['contact']==meta.get('from',data['startup'])
        assert pair['damage']==meta['damage_frame'] and pair['release']==meta['release_frame']
    return roster,pairs,rigs,libraries,hashes
