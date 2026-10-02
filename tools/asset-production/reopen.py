"""Explicit-slot independent master AND GLB reopen, never a source preflight."""
import json
import hashlib
from pathlib import Path
import sys
import bpy

ROOT = Path(__file__).resolve().parents[2]
plan = json.loads((ROOT/'port/finish/ASSET_PRODUCTION.json').read_text())
id_ = next(a.split('=',1)[1] for a in sys.argv if a.startswith('--unit='))
unit = next(u for u in plan['units'] if u['id']==id_)
source_hashes = {path: hashlib.sha256((ROOT/path).read_bytes()).hexdigest()
                 for path in unit['recipePaths'] + [plan['common']['finishScript']]}
fingerprint = hashlib.sha256(json.dumps(source_hashes, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
for kind in ('masters','exports'):
    paths = sorted(ROOT.glob(unit[kind]['glob']))
    assert len(paths)==unit[kind]['count'], (kind,len(paths),unit[kind]['count'])
    for path in paths:
        if kind=='masters':
            bpy.ops.wm.open_mainfile(filepath=str(path))
            assert bpy.context.scene.get('moth_finish_version')==1, 'Master missing real surface finish'
            assert bpy.context.scene.get('asset_source_fingerprint')==fingerprint, 'Stale master recipe/builder fingerprint'
        else:
            bpy.ops.wm.read_factory_settings(use_empty=True)
            bpy.ops.import_scene.gltf(filepath=str(path))
        meshes = [o for o in bpy.context.scene.objects if o.type=='MESH']
        assert meshes
        for obj in meshes:
            assert obj.data.vertices and obj.data.polygons
            needs_uv = any(mat and mat.name.split('.')[0] not in plan['common']['texturePreserveNames'] for mat in obj.data.materials)
            assert not needs_uv or obj.data.uv_layers, 'Missing attachment-local UV on '+obj.name
        textured = [mat for obj in meshes for mat in obj.data.materials if mat and mat.use_nodes and any(n.type=='TEX_IMAGE' and n.image for n in mat.node_tree.nodes)]
        assert textured, 'Flat-only export/master is not production ready'
        print('ASSET_REOPEN',kind,str(path.relative_to(ROOT)),len(meshes),len(textured))
