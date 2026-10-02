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
    rows = []
    for mesh in model['meshes']:
        for primitive in mesh['primitives']:
            material = model['materials'][primitive['material']]
            attrs = primitive['attributes']
            uv = model['accessors'][attrs['TEXCOORD_0']] if 'TEXCOORD_0' in attrs else None
            pos = model['accessors'][attrs['POSITION']]
            rows.append(dict(mesh=mesh.get('name'), material=material.get('name'),
                             uv0=uv is not None and uv['type'] == 'VEC2' and uv['count'] == pos['count'],
                             tangent='TANGENT' in attrs, material_traits=material))
    return rows


def resource(root, path):
    assert isinstance(path, str) and path.startswith('res://source_operators/moth_finish/assets/') and '..' not in path
    result = root / 'godot' / path.removeprefix('res://')
    assert result.is_file(), f'missing texture: {path}'
    return result


def check_provenance(manifest, root, textures):
    """Accept nested path/sha256 records and source_path/source_sha256 pairs.

    This checks file identity, not the appearance or engine authority of pixels.
    The content lane's deterministic reproduction command remains a separate gate.
    """
    verified = {}
    sources = set()

    def walk(value):
        if isinstance(value, list):
            for child in value:
                walk(child)
        if not isinstance(value, dict):
            return
        for prefix in ('', 'source_', 'moth_source_'):
            path = value.get(prefix + 'path')
            sha = value.get(prefix + 'sha256')
            if not isinstance(path, str) or not isinstance(sha, str):
                continue
            relative = ('godot/' + path[6:]) if path.startswith('res://') else path
            file = (root / relative).resolve()
            assert file.is_relative_to(root.resolve()), 'provenance path escape'
            assert file.is_file(), f'missing provenance file: {path}'
            actual = hashlib.sha256(file.read_bytes()).hexdigest()
            assert actual == sha, f'provenance hash mismatch: {path}'
            verified[file] = actual
            if file.is_relative_to((root / 'godot/moth').resolve()) or file == (root / 'game/moth-baked.mjs').resolve():
                sources.add(str(file.relative_to(root.resolve())))
            if path in textures:
                for dimension in ('width', 'height'):
                    assert value.get(dimension) == textures[path][dimension], f'provenance dimension mismatch: {path}'
        for child in value.values():
            walk(child)

    walk(manifest)
    assert sources, 'no hash-verified existing Moth source provenance'
    for path, traits in textures.items():
        assert verified.get(resource(root, path).resolve()) == traits['sha256'], f'texture lacks hash/dimension record: {path}'
    return sorted(sources)


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
            textures[finish[channel]] = dict(width=w, height=h, sha256=hashlib.sha256(data).hexdigest())
    coverage = []
    for row in rows:
        name = row['material']
        rule = bindings.get(name)
        status = 'matched' if rule else ('excluded' if name in preserved else 'unmatched')
        if rule:
            assert isinstance(rule['role'], str) and rule['role']
            assert row['uv0'], f'missing UV0: {operator}/{row["mesh"]}'
            material = row['material_traits']
            assert not any(material.get('emissiveFactor', [])), f'emissive binding: {name}'
            assert material.get('alphaMode', 'OPAQUE') == 'OPAQUE'
            assert 'baseColorTexture' not in material.get('pbrMetallicRoughness', {})
        coverage.append(dict(mesh=row['mesh'], material=name, status=status, uv0=row['uv0'],
                             tangent_in_glb=row['tangent']))
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
    result = json.dumps(report, indent=2) + '\n'
    if args.output:
        args.output.write_text(result)
    else:
        print(result)


if __name__ == '__main__':
    main()
