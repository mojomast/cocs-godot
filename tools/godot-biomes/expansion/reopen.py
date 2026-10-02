"""Granted-slot follow-up: independently reopen every editable master."""
from pathlib import Path
import json
import bpy

HERE = Path(__file__).resolve().parent
data = json.loads((HERE / "meshes.json").read_text())
for asset in data["assets"]:
    bpy.ops.wm.open_mainfile(filepath=str(HERE / "masters" / (asset["id"] + ".blend")))
    objects = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    assert len(objects) == len(asset["parts"])
    assert {o.name for o in objects} == {p["name"] for p in asset["parts"]}
    assert bpy.context.scene["reviewed_block"] == asset["block"]
    for obj in objects:
        assert len(obj.data.vertices) > 0 and len(obj.data.polygons) > 0
        assert "biome4_material" in obj
    print("BIOME4_REOPEN", asset["id"], len(objects))
