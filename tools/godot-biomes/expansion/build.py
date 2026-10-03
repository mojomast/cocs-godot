"""Explicit-slot-only Blender build. Node owns the exact triangulated recipe.

Editable named components remain in masters/ (outside godot). Export copies are
joined by material, at most four surfaces/LOD. Reopen validation is a separate job.
"""
from pathlib import Path
import hashlib
import json
import bpy
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools/asset-production'))
from moth_finish import finish_scene
HERE = Path(__file__).resolve().parent
RAW = (HERE / "meshes.json").read_bytes()
DATA = json.loads(RAW)
CATALOG = json.loads((ROOT / "godot/biomes/expansion/catalog.json").read_text())
assert hashlib.sha256(RAW).hexdigest() == CATALOG["recipeSha256"]


def material(name, spec):
    color, roughness, metallic = spec
    mat = bpy.data.materials.new("biome4_" + name)
    mat.use_nodes = True
    rgb = [int(color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    # Palette is sRGB; Blender node colors are linear.
    rgb = [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb]
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    mat.diffuse_color = (*rgb, 1)
    return mat


def build(asset):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = {key: material(key, value) for key, value in DATA["palette"].items()}
    sources = []
    for part in asset["parts"]:
        mesh = bpy.data.meshes.new(part["name"])
        # Blender Z-up -> glTF Y-up: (x, -z, y).
        mesh.from_pydata([(x, -z, y) for x, y, z in part["vertices"]], [], part["triangles"])
        mesh.update()
        obj = bpy.data.objects.new(part["name"], mesh)
        bpy.context.collection.objects.link(obj)
        obj.data.materials.append(mats[part["material"]])
        obj["biome4_detail"] = part["detail"]
        obj["biome4_material"] = part["material"]
        sources.append(obj)
    scene = bpy.context.scene
    scene["recipe_sha256"] = CATALOG["recipeSha256"]
    scene["seed"] = DATA["seed"]
    scene["chapter"] = asset["chapter"]
    scene["reviewed_block"] = asset["block"]
    master = HERE / "masters" / (asset["id"] + ".blend")
    master.parent.mkdir(exist_ok=True)
    placement = next(p for p in CATALOG['chapters'][asset['chapter']]['placements'] if p['asset'] == asset['id'])
    sx, sy, sz = placement['scale']
    finish_scene(ROOT, 'scenery', (sx, sz, sy))
    # Generated-image pack() writes channel values directly. The shared finish
    # supplies linear shader tints; encode them for the exported sRGB PNG so
    # Godot's sRGB decode restores the authored color rather than darkening twice.
    # Local producer fix: never alter the shared finisher or linear normal maps.
    for image in bpy.data.images:
        if not image.name.startswith('MothLocal_'):
            continue
        pixels = list(image.pixels[:])
        for i in range(0, len(pixels), 4):
            for channel in range(3):
                value = pixels[i + channel]
                pixels[i + channel] = 12.92 * value if value <= .0031308 else 1.055 * value ** (1 / 2.4) - .055
        image.pixels.foreach_set(pixels)
        image.pack()
    scene['scenery_albedo_transfer'] = 'linear-to-srgb-packed-v1'
    bpy.ops.wm.save_as_mainfile(filepath=str(master))
    output = ROOT / "godot/biomes/expansion/art"
    output.mkdir(parents=True, exist_ok=True)
    for lod in (0, 1):
        copies = []
        for original in sources:
            if lod == 1 and original["biome4_detail"]:
                continue
            copy = original.copy()
            copy.data = original.data.copy()
            bpy.context.collection.objects.link(copy)
            copies.append(copy)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in copies:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = copies[0]
        bpy.ops.object.join()
        joined = bpy.context.object
        joined.name = asset["id"] + "_LOD" + str(lod)
        bpy.ops.export_scene.gltf(filepath=str(output / (asset["id"] + "-" + str(lod) + ".glb")),
                                  export_format="GLB", use_selection=True, export_yup=True, export_extras=True,
                                  export_animations=False, export_cameras=False, export_lights=False)
        glb = output / (asset["id"] + "-" + str(lod) + ".glb")
        source = "res://biomes/expansion/art/" + glb.name
        imported = "res://.godot/imported/" + glb.name + "-" + hashlib.md5(source.encode()).hexdigest() + ".scn"
        preset = ('[remap]\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\n'
                  f'path="{imported}"\n\n[deps]\nsource_file="{source}"\n'
                  f'dest_files=["{imported}"]\n\n[params]\n'
                  'meshes/generate_lods=false\nmeshes/create_shadow_meshes=false\nmeshes/force_disable_compression=true\n'
                  'meshes/light_baking=1\nanimation/import=false\nmaterials/extract=0\n')
        Path(str(glb) + ".import").write_text(preset)
        bpy.data.objects.remove(joined, do_unlink=True)
    print("BIOME4_BUILT", asset["id"], len(sources))


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--asset', choices=[a['id'] for a in DATA['assets']])
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    for entry in DATA["assets"]:
        if args.asset is None or entry['id'] == args.asset:
            build(entry)
