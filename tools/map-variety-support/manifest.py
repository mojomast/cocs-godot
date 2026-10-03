"""Source-only resolver for the reviewed map-variety Moth packs (2026-10-03).

Reads the immutable ``candidate-v2`` base pack and its additive ``candidate-v3``
overlay, resolves exact channel PNGs by *stable material ID* (never array order,
glob order or name guessing) and verifies every byte it is about to hand to a
builder. No Blender, Godot, network or import is invoked.

All five base channels are linear (including albedo); callers must set Blender
image colour space to Non-Color and let the shared adapter convert glTF
base-colour encoding to sRGB. A normal channel is OpenGL +Y, rows-down/UV-v-up.

Unknown material, unknown channel, escaping path or hash mismatch is an error,
never a fallback to the pinned ``moth_finish.py`` registry.
"""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PACK_ROOT = ROOT / 'assets/moth/map-variety-20261003'
BASE_MANIFEST = PACK_ROOT / 'candidate-v2/manifest.json'
OVERLAY_MANIFEST = PACK_ROOT / 'candidate-v3/manifest.json'
SHA = re.compile(r'^[0-9a-f]{64}$')
CHANNELS = ('albedo', 'normal', 'roughness', 'height', 'wear')


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _read(path):
    return json.loads(Path(path).read_text())


def _checked_file(directory, descriptor):
    relative = descriptor.get('path')
    if not isinstance(relative, str) or not relative or relative.startswith(('res://', '/')):
        raise ValueError('Non repository-relative pack path: ' + str(relative))
    path = (Path(directory) / relative).resolve()
    if not path.is_relative_to(Path(directory).resolve()) or not path.is_file():
        raise ValueError('Missing pack channel: ' + relative)
    expected = descriptor.get('sha256')
    if not isinstance(expected, str) or not SHA.fullmatch(expected):
        raise ValueError('Missing channel sha256: ' + relative)
    actual = sha256(path)
    if actual != expected:
        raise ValueError('Pack channel hash mismatch: ' + relative)
    return path, actual


class Pack:
    def __init__(self, materials, textures, auxiliary, base_sha, overlay_sha, manifest_sha):
        self.materials = materials
        self.textures = textures
        self.auxiliary = auxiliary
        self.base_sha = base_sha
        self.overlay_sha = overlay_sha
        self.manifest_sha = manifest_sha

    def material(self, material_id):
        if material_id not in self.materials:
            raise KeyError('Unreviewed material ID: ' + str(material_id))
        return self.materials[material_id]

    def channel(self, material_id, channel):
        material = self.material(material_id)
        key = material['channels'].get(channel)
        if not key:
            raise KeyError('Material %s has no %s channel' % (material_id, channel))
        if key not in self.textures:
            raise KeyError('Channel key absent from pack: ' + key)
        return dict(self.textures[key])

    def bindings_plan(self, bindings):
        """Resolve a map's exact-GLB-name -> binding registry to concrete files.

        Binding: {"role": surface|team|preserve, "material": <stable id>,
        "normal": bool, "teamColorSource": "COLOR_0" | null}. Repeat density is
        read from the reviewed material tile size, never stored twice.
        """
        plan = {}
        for name in sorted(bindings):
            binding = bindings[name]
            role = binding.get('role')
            if role == 'preserve':
                if binding.get('material') or binding.get('normal'):
                    raise ValueError('Preserved material carries a pack binding: ' + name)
                plan[name] = {'role': 'preserve'}
                continue
            if role not in ('surface', 'team'):
                raise ValueError('Unreviewed role for %s: %s' % (name, role))
            material = self.material(binding['material'])
            albedo = self.channel(binding['material'], 'albedo')
            normal = self.channel(binding['material'], 'normal') if binding.get('normal') else None
            if binding.get('normal') and 'normal' not in material['channels']:
                raise ValueError('Normal-map binding without a normal channel: ' + name)
            if role == 'team' and binding.get('teamColorSource') != 'COLOR_0':
                raise ValueError('Team binding must preserve exported COLOR_0: ' + name)
            tiles = 1.0 / float(material['tileMeters'])
            if not 0 < tiles <= 16:
                raise ValueError('Invalid repeat density for ' + name)
            plan[name] = {
                'role': role,
                'material': binding['material'],
                'albedoFile': str(albedo['_path']),
                'albedoKey': material['channels']['albedo'],
                'albedoColorSpace': 'linear (Non-Color)',
                'normalFile': str(normal['_path']) if normal else None,
                'normalKey': material['channels'].get('normal') if normal else None,
                'normalConvention': material.get('normalConvention'),
                'tilesPerMeter': tiles,
                'teamColorSource': 'COLOR_0' if role == 'team' else None,
            }
        return plan


def load_pack(root=None):
    """Resolve the reviewed packs. `root` may override the repository root so a
    caller (e.g. a parent lane) can point at an explicit checkout; it defaults to
    this file's repository root."""
    repository = Path(root).resolve() if root else ROOT
    pack_root = repository / 'assets/moth/map-variety-20261003'
    base_manifest = pack_root / 'candidate-v2/manifest.json'
    overlay_manifest = pack_root / 'candidate-v3/manifest.json'
    base = _read(base_manifest)
    overlay = _read(overlay_manifest)
    if base.get('schema') != 'moth-map-material-pack/v1' or overlay.get('schema') != 'moth-map-material-overlay/v1':
        raise ValueError('Unexpected map-variety pack schema')
    base_sha = sha256(base_manifest)
    overlay_ref = overlay.get('basePack', {})
    resolved_base = (overlay_manifest.parent / overlay_ref.get('manifest', '')).resolve()
    if resolved_base != base_manifest.resolve() or overlay_ref.get('sha256') != base_sha:
        raise ValueError('Overlay base pack identity mismatch')

    materials, textures, auxiliary = {}, {}, {}
    for directory, manifest in ((base_manifest.parent, base), (overlay_manifest.parent, overlay)):
        for material in manifest.get('materials', []):
            materials[material['id']] = material
        for key, descriptor in manifest.get('textures', {}).items():
            path, digest = _checked_file(directory, descriptor)
            textures[key] = {**descriptor, '_path': path, '_sha256': digest}
        for key, descriptor in manifest.get('auxiliaryResources', {}).items():
            files = descriptor.get('files') or ([descriptor['file']] if 'file' in descriptor else [])
            resolved = [_checked_file(directory, item) for item in files]
            auxiliary[key] = {**descriptor,
                              '_files': resolved,
                              '_sha256': {item.get('path'): digest for item, digest in zip(files, [r[1] for r in resolved])}}
    overlay_sha = sha256(overlay_manifest)
    return Pack(materials, textures, auxiliary, base_sha, overlay_sha,
                {'base': base_sha, 'overlay': overlay_sha})


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('bindings', help='Repository-relative materials.bindings.json')
    parser.add_argument('--root', help='Repository root override; defaults to this checkout')
    args = parser.parse_args(argv)
    pack = load_pack(args.root)
    document = _read(ROOT / args.bindings)
    if 'materials' not in document:
        raise ValueError('Bindings file has no materials registry')
    plan = pack.bindings_plan(document['materials'])
    print(json.dumps({'map': document.get('map'), 'pack': pack.manifest_sha,
                      'materials': len(pack.materials), 'textures': len(pack.textures),
                      'auxiliary': len(pack.auxiliary), 'plan': plan}, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
