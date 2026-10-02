#!/usr/bin/env python3
"""Source-only material/UV/resource closure gate; never launches native tools."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct

OPS = 'chatgpt claude grok meta gemini deepseek mistral kimi qwen'.split()


def glb(path):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from('<III', data)
    assert magic == 0x46546C67 and version == 2 and length == len(data)
    size, kind = struct.unpack_from('<II', data, 12)
    assert kind == 0x4E4F534A
    return json.loads(data[20:20 + size])


def inventory(path):
    model = glb(path)
    parents = {child: index for index, node in enumerate(model['nodes']) for child in node.get('children', [])}
    owners = {}
    for index, node in enumerate(model['nodes']):
        if 'mesh' not in node: continue
        ancestry = []
        current = index
        while True:
            ancestry.append(model['nodes'][current].get('name', str(current)))
            if current not in parents: break
            current = parents[current]
        owners.setdefault(node['mesh'], []).append(ancestry)
    rows = []
    for index, mesh in enumerate(model['meshes']):
        for primitive in mesh['primitives']:
            material = model['materials'][primitive['material']]
            attrs = primitive['attributes']
            uv = model['accessors'][attrs['TEXCOORD_0']] if 'TEXCOORD_0' in attrs else None
            pos = model['accessors'][attrs['POSITION']]
            rows.append(dict(mesh=mesh.get('name'), material=material.get('name'),
                             uv0=uv is not None and uv['type'] == 'VEC2' and uv['count'] == pos['count'],
                             tangent='TANGENT' in attrs, material_traits=material,
                             ancestry=owners.get(index, [])))
    return rows


def resource(root, path):
    assert isinstance(path, str) and path.startswith('res://source_operators/moth_finish/assets/') and '..' not in path
    result = root / 'godot' / path.removeprefix('res://')
    assert result.is_file(), f'missing texture: {path}'
    return result


def check_provenance(manifest, root, textures):
    """Verify the delivered keyed texture table and explicit Moth source graph."""
    assert isinstance(manifest.get('textures'), dict), 'missing texture audit table'
    assert isinstance(manifest.get('provenance'), dict), 'missing provenance'
    provenance = manifest['provenance']

    def verify(path, expected):
        relative = ('godot/' + path[6:]) if path.startswith('res://') else path
        file = (root / relative).resolve()
        assert file.is_relative_to(root.resolve()), 'provenance path escape'
        assert file.is_file(), f'missing provenance file: {path}'
        assert hashlib.sha256(file.read_bytes()).hexdigest() == expected, f'provenance hash mismatch: {path}'
        return file

    registry_path = 'godot/moth/generated/manifest.json'
    verify(registry_path, provenance['moth_manifest_sha256'])
    registry = json.loads((root / registry_path).read_text())
    verify('godot/source_operators/generated/manifest.json', provenance['operator_catalog_manifest_sha256'])
    verify(provenance['generator'], provenance['generator_sha256'])
    verify(provenance['moth_baked_source']['path'], provenance['moth_baked_source']['sha256'])
    assert provenance['moth_baked_source']['path'] == registry['provenance']['source']
    assert provenance['moth_baked_source']['sha256'] == registry['provenance']['source_sha256']
    for path, sha in provenance['art_reference_sources'].items(): verify(path, sha)
    for operator in OPS:
        verify(f'godot/source_operators/generated/{operator}.glb', provenance['source_glbs'][operator])

    sources = {}
    for name, source in provenance['moth_sources'].items():
        original = registry['textures'][name]
        assert source['registry_key'] == 'textures/' + name
        assert source['path'] == original['path']
        assert source['png_sha256'] == original['png_sha256']
        assert source['rgba_pixel_sha256'] == original['pixel_sha256']
        assert source['registry_color_space'] == original['color_space']
        file = verify(source['path'], source['png_sha256'])
        dimensions = list(struct.unpack_from('>II', file.read_bytes(), 16))
        assert dimensions == source['dimensions'] == [original['width'], original['height']]
        sources[source['registry_key']] = str(file.relative_to(root.resolve()))
    assert sources, 'no hash-verified existing Moth source provenance'
    assert set(manifest['textures']) == set(textures), 'orphan or unrecorded derived texture'
    for path, traits in textures.items():
        record = manifest['textures'][path]
        assert record['png_sha256'] == traits['sha256'], f'texture hash mismatch: {path}'
        assert record['dimensions'] == [traits['width'], traits['height']], f'texture dimension mismatch: {path}'
        assert record['channels'] == traits['channels'], f'texture channel mismatch: {path}'
        assert record['color_space'] == ('srgb' if path.endswith('-albedo.png') else 'linear')
        assert record['moth_keys'] and all(key in sources for key in record['moth_keys']), f'unverified Moth input: {path}'
        assert isinstance(record['derivation'], dict) and record['derivation']['resolution'] == traits['width']
        assert isinstance(record['pixel_sha256'], str) and len(record['pixel_sha256']) == 64
    assert provenance['recipe'], 'missing deterministic derivation recipe'
    return sources


def check_profile(profile, manifest, operator, rows, root):
    assert profile['version'] == manifest['version'] == 1 and profile['operator_id'] == operator
    assert isinstance(profile['bindings'], list) and isinstance(profile['preserve_materials'], list)
    assert isinstance(profile['overlay_finishes'], dict)
    bindings = {b['source_material']: b for b in profile['bindings']}
    preserved = {b['source_material']: b['reason'] for b in profile['preserve_materials']}
    assert len(bindings) == len(profile['bindings']) and len(preserved) == len(profile['preserve_materials'])
    assert not bindings.keys() & preserved.keys(), 'conflicting preserve/bind rule'
    assert 'sourceTeamIvory' in preserved, 'team shape material must be preserved'
    available = {r['material'] for r in rows}
    assert not bindings.keys() - available, 'unmatched material binding'
    assert available == bindings.keys() | preserved.keys(), 'unclassified or nonexistent source material'
    selected = {b['finish'] for b in bindings.values()} | set(profile['overlay_finishes'].values())
    assert set(profile['overlay_finishes']) == {'panel', 'board', 'vent'}, 'incomplete overlay coverage'
    textures = {}
    for key in selected:
        finish = manifest['finishes'][key]
        assert finish['albedo_mode'] == 'modulate'
        for scalar in ('metallic', 'roughness_gain', 'normal_strength'):
            value = finish[scalar]
            assert type(value) in (float, int) and math.isfinite(value) and 0 <= value <= 1
        for channel in ('albedo', 'normal', 'roughness'):
            if channel != 'albedo' and channel not in finish:
                continue
            path = resource(root, finish[channel])
            data = path.read_bytes()
            assert data[:8] == b'\x89PNG\r\n\x1a\n', 'expected derived PNG resource'
            w, h = struct.unpack_from('>II', data, 16)
            assert w > 0 and h > 0
            bit_depth, color_type = data[24:26]
            channels = {0: 1, 2: 3, 6: 4}.get(color_type)
            assert bit_depth == 8 and channels == (1 if channel == 'roughness' else 3), f'wrong map encoding: {finish[channel]}'
            textures[finish[channel]] = dict(width=w, height=h, channels=channels, sha256=hashlib.sha256(data).hexdigest())
    coverage = []
    for row in rows:
        name = row['material']
        rule = bindings.get(name)
        status = 'matched' if rule else ('excluded' if name in preserved else 'unmatched')
        if rule:
            assert isinstance(rule['role'], str) and rule['role']
            assert row['uv0'], f'missing UV0: {operator}/{row["mesh"]}'
            material = row['material_traits']
            ancestry = {name.lower() for chain in row.get('ancestry', []) for name in chain}
            assert not ancestry & {'weapon', 'gunanchor', 'worldweapon'}, f'weapon ancestry bound: {name}'
            assert not any(name.startswith('teambar') for name in ancestry), 'team marker bound'
            assert not any(material.get('emissiveFactor', [])), f'emissive binding: {name}'
            assert material.get('alphaMode', 'OPAQUE') == 'OPAQUE'
            assert 'baseColorTexture' not in material.get('pbrMetallicRoughness', {})
        coverage.append(dict(mesh=row['mesh'], material=name, status=status, uv0=row['uv0'],
                             tangent_in_glb=row['tangent'], ancestry=row.get('ancestry', [])))
    assert any(c['status'] == 'matched' for c in coverage), 'no body coverage'
    return dict(coverage=coverage, textures=textures,
                native_gate='Imported tangent availability; FIGHT UV/skin/export preservation and visual inspection pending')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument('--inventory-only', action='store_true')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    report = {}
    finish_root = args.root / 'godot/source_operators/moth_finish'
    manifest = None if args.inventory_only else json.loads((finish_root / 'manifest.json').read_text())
    for operator in OPS:
        rows = inventory(args.root / f'godot/source_operators/generated/{operator}.glb')
        assert rows and all(r['uv0'] for r in rows), f'{operator}: UV0 drop'
        report[operator] = rows if args.inventory_only else check_profile(
            json.loads((finish_root / f'profiles/{operator}.json').read_text()), manifest, operator, rows, args.root)
    if manifest is not None:
        textures = {key: value for entry in report.values() for key, value in entry['textures'].items()}
        report['verified_moth_source_files'] = check_provenance(manifest, args.root, textures)
        used = {binding['finish'] for operator in OPS for binding in json.loads((finish_root / f'profiles/{operator}.json').read_text())['bindings']}
        used.update(finish for operator in OPS for finish in json.loads((finish_root / f'profiles/{operator}.json').read_text())['overlay_finishes'].values())
        assert used == set(manifest['finishes']), 'unreferenced or missing finish ID'
        report['summary'] = dict(finishes=len(used), unique_textures=len(textures),
                               source_primitives=sum(len(report[op]['coverage']) for op in OPS),
                               matched=sum(c['status'] == 'matched' for op in OPS for c in report[op]['coverage']),
                               excluded=sum(c['status'] == 'excluded' for op in OPS for c in report[op]['coverage']),
                               unmatched=sum(c['status'] == 'unmatched' for op in OPS for c in report[op]['coverage']))
        report['tangent_import_configuration'] = {}
        for operator in OPS:
            settings_path = args.root / f'godot/source_operators/generated/{operator}.glb.import'
            configured = settings_path.is_file() and 'meshes/ensure_tangents=true' in settings_path.read_text()
            assert configured, f'{operator}: normal-map profiles require configured tangent generation'
            report['tangent_import_configuration'][operator] = 'ensure_tangents=true; native result still unverified'
    result = json.dumps(report, indent=2) + '\n'
    if args.output:
        args.output.write_text(result)
    else:
        print(result)


if __name__ == '__main__':
    main()
