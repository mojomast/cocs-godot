"""Post-grant only: reopen each real master and skeletal GLB; fail on bad rig.
Run separately from build.py so in-memory authoring state cannot hide errors.
"""
import math
from pathlib import Path
import sys
import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from recipe import SKINS


def check(label):
    rigs = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']
    assert len(rigs) == 1, (label, 'one skeleton required')
    rig = rigs[0]
    assert {'Chassis', 'Turret', 'Weapon', 'Hip0', 'Shin0'} <= set(rig.data.bones.keys())
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH':
            continue
        assert len(obj.data.polygons) > 0
        assert any(m.type == 'ARMATURE' and m.object == rig for m in obj.modifiers)
        for vertex in obj.data.vertices:
            assert all(math.isfinite(v) for v in vertex.co)
            weights = [g.weight for g in vertex.groups]
            assert len(weights) == 1 and abs(sum(weights)-1) < 1e-6, (label, obj.name, weights)
    # Exporter may namespace action names; inspect substrings rather than fabricate clips.
    names = [a.name.lower() for a in bpy.data.actions]
    for clip in ['idle', 'walk', 'attack', 'react', 'death']:
        assert any(clip in n for n in names), (label, 'missing clip', clip, names)
    print('SWITCHYARD_RIG_OK', label, len(rig.data.bones))


for skin in SKINS:
    bpy.ops.wm.open_mainfile(filepath=str(HERE / 'masters' / f'{skin}.blend'))
    check(skin + ':master')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(HERE / 'masters' / f'{skin}_skeletal.glb'))
    check(skin + ':reopened-glb')
