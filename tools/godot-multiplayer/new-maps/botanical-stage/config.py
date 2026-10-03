"""Closed botanical test lane. Importing this module starts no engine or jobs."""
import hashlib
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
DEST = ROOT / 'godot/tests/new_maps/botanical_stage'
R5 = ROOT / 'tools/godot-multiplayer/new-maps/gravemill-foundry/revision5'
BLENDER = '/home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender'
GODOT = '/tmp/opencode/cocs-horde-e353522a-package/toolchain/Godot_v4.5.2-stable_linux.x86_64'
MAPS = {
    'helix-conservatory': ('revision-3', '5755ec9fba17d4b88d99d90e1717d86ce5ae9983a5c2bc290a93b5b366585140',
        'helix-conservatory', ['deathmatch','teamdeathmatch','ctf','domination','koth']),
    'parallax-observatory': ('districts-v3', 'abaea5a6f13cca985f380d9c2f98c856ae5264325e219303219328ee47ab900c',
        'parallax-observatory/revisions/districts-v3', ['deathmatch','teamdeathmatch','ctf','koth','uplink','holdout']),
    'vesper-viaduct': ('urban-v2', 'c044bc54cfd96e99e3b29d61c5bc66bc9c470f8f3823176c063d2fe6ee9474ad',
        'vesper-viaduct/revisions/urban-v2', ['deathmatch','teamdeathmatch','ctf','domination','koth','uplink']),
}

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def read(path):
    return json.loads(Path(path).read_text())

def write(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, allow_nan=False)+'\n')

def entry(map_id):
    revision, geometry, author, modes = MAPS[map_id]
    module_path = ROOT/'tools/godot-multiplayer/new-maps'/author/'asset_author.py'
    spec = importlib.util.spec_from_file_location('botanical_author_'+map_id, module_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)  # pure entrypoint; bpy imports only in build
    data = read(module.AUTHORITY)
    if data['geometryHash'] != geometry or data['id'] != map_id:
        raise ValueError('Candidate identity changed: '+map_id)
    accepted = ROOT/f'godot/multiplayer_worlds/generated/{map_id}.json'
    accepted_art = ROOT/f'godot/multiplayer_worlds/art/{map_id}/{map_id}.glb'
    if map_id == 'vesper-viaduct':
        accepted_art = ROOT/f'godot/multiplayer_worlds/art/worlds/{map_id}.glb'
    return module, data, accepted, accepted_art, modes

def res(path):
    return 'res://'+str(Path(path).relative_to(ROOT/'godot'))

def source_manifest():
    maps = {}
    for map_id in MAPS:
        author, data, accepted, art, modes = entry(map_id)
        plan = author.plan()
        if plan['expectedMaster'] != str(author.MASTER.relative_to(ROOT)) or plan['expectedGlb'] != str(author.EXPORT.relative_to(ROOT)):
            raise ValueError('Author plan/output path mismatch')
        maps[map_id] = {
            'revision': MAPS[map_id][0], 'geometryHash': data['geometryHash'],
            'authority': str(author.AUTHORITY.relative_to(ROOT)), 'authoritySha256': sha(author.AUTHORITY),
            'author': str(Path(author.__file__).relative_to(ROOT)),
            'master': plan['expectedMaster'], 'glb': plan['expectedGlb'],
            'acceptedAuthority': res(accepted), 'acceptedAuthoritySha256': sha(accepted),
            'acceptedGeometryHash': read(accepted)['geometryHash'],
            'acceptedArt': res(art), 'acceptedArtSha256': sha(art),
            'modes': modes, 'artifactStatus': 'pending-build', 'glbSha256': None,
            'nativeStatus': 'pending-grant-and-engine-validation',
        }
    return {'schema': 'botanical-stage/v1', 'status': 'source-only-prepared',
            'foundation': '32eba401155856e50e31698b41d132f6ded0a50c',
            'r5Reference': '7ae3f2f5', 'maps': maps}

if __name__ == '__main__':
    print(json.dumps(source_manifest(), indent=2))
