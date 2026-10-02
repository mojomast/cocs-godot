#!/usr/bin/env python3
"""Source/geometry proof only. Never launches Godot, Blender, renders or imports."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[3]
PARENT_ART = "c8432fcb8aad1bf9834bb80d234de14ef07da1a2"


def asset(path):
    relative = "godot/" + path.removeprefix("res://")
    local = ROOT / relative
    if local.exists():
        return local.read_bytes(), "worktree"
    return subprocess.check_output(["git", "show", f"{PARENT_ART}:{relative}"], cwd=ROOT), "parent-git-object-only"


def sample_floor(recipe, x, z):
    heights = []
    for surface in recipe["arena"]["terrain"]["surfaces"]:
        for triangle in surface["triangles"]:
            a, b, c = [surface["vertices"][i] for i in triangle]
            denominator = (b[2]-c[2])*(a[0]-c[0])+(c[0]-b[0])*(a[2]-c[2])
            if abs(denominator) < 1e-6:
                continue
            u = ((b[2]-c[2])*(x-c[0])+(c[0]-b[0])*(z-c[2]))/denominator
            v = ((c[2]-a[2])*(x-c[0])+(a[0]-c[0])*(z-c[2]))/denominator
            w = 1-u-v
            if min(u, v, w) >= -1e-5:
                heights.append(u*a[1]+v*b[1]+w*c[1])
    assert heights, "fight platform has no original terrain support"
    return max(heights)


def inside(point, origin):
    return abs(point[0]-origin[0]) <= 45 and -65 <= point[2]-origin[2] <= -4


def glb_crop(data, origin):
    size = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20+size])
    binary = data[28+size:]
    # This accepted export has root meshes and transformed wayfinding labels.
    # Reject unexpected hierarchy/matrix changes rather than ignore transforms.
    assert all("matrix" not in n and not n.get("children") for n in doc["nodes"])

    def transformed(vertex, node):
        scale = node.get("scale", [1,1,1])
        point = [v*s for v,s in zip(vertex,scale)]
        q = node.get("rotation", [0,0,0,1])
        def cross(a,b):
            return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
        first = cross(q[:3],point)
        second = cross(q[:3],[first[i]+q[3]*point[i] for i in range(3)])
        translation = node.get("translation",[0,0,0])
        return [point[i]+2*second[i]+translation[i] for i in range(3)]

    def values(index):
        accessor = doc["accessors"][index]
        view = doc["bufferViews"][accessor["bufferView"]]
        fmt = {5126:"f",5125:"I",5123:"H",5121:"B"}[accessor["componentType"]]
        width = {"SCALAR":1,"VEC3":3}[accessor["type"]]
        stride = view.get("byteStride", struct.calcsize(fmt)*width)
        offset = view.get("byteOffset",0)+accessor.get("byteOffset",0)
        return [struct.unpack_from("<"+fmt*width,binary,offset+i*stride) for i in range(accessor["count"])]

    kept, surfaces = 0, 0
    for node in doc["nodes"]:
        if "mesh" not in node:
            continue
        mesh = doc["meshes"][node["mesh"]]
        for primitive in mesh["primitives"]:
            vertices = [transformed(v,node) for v in values(primitive["attributes"]["POSITION"])]
            indices = [i[0] for i in values(primitive["indices"])] if "indices" in primitive else list(range(len(vertices)))
            count = sum(all(inside(vertices[j],origin) for j in indices[i:i+3]) for i in range(0,len(indices),3))
            kept += count
            surfaces += bool(count)
    assert kept > 0
    return kept, surfaces


def run():
    parser = argparse.ArgumentParser()
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    from gdtoolkit.parser import parser as gdparser
    files = sorted((ROOT / "godot/fighting").rglob("*.gd")) + sorted((ROOT / "godot/tests/fighting/presentation").rglob("*.gd"))
    for path in files:
        gdparser.parse(path.read_text())
    catalog = (ROOT / "godot/fighting/stages/catalog.gd").read_text()
    specs = [json.loads(m.group()) for m in re.finditer(r'\{"id"[^\n]*?\}',catalog)]
    stages = []
    for spec in specs:
        raw, location = asset(spec["recipe"])
        recipe = json.loads(raw)
        assert recipe["geometryHash"] == spec["geometry_hash"]
        origin = spec["origin"][:]
        origin[1] = sample_floor(recipe,origin[0],origin[2])
        if "glb" in spec:
            data, glb_location = asset(spec["glb"])
            assert hashlib.sha256(data).hexdigest() == spec["glb_sha256"]
            triangles, surfaces = glb_crop(data,origin)
        else:
            glb_location = None
            triangles, surfaces = 0, 0
            sources = recipe["arena"]["terrain"]["surfaces"] + (recipe["art"] if spec["id"] != "crown-array" else [])
            for surface in sources:
                count = sum(all(inside(surface["vertices"][j],origin) for j in triangle) for triangle in surface["triangles"])
                triangles += count
                surfaces += bool(count)
            assert triangles > 0
        stages.append({"id":spec["id"],"origin":origin,"geometry_hash":spec["geometry_hash"],"recipe_sha256":hashlib.sha256(raw).hexdigest(),"recipe_location":location,"glb_location":glb_location,"cropped_terrain_or_glb_triangles":triangles,"surface_count":surfaces,"native_art":"unrun","native_profile":"unrun"})

    # Camera extrema, both world sides and all jump heights at requested sizes.
    source = (ROOT / "godot/fighting/presentation/camera.gd").read_text()
    jump = float(re.search(r'MAX_JUMP := ([\d.]+)',source)[1])
    top = float(re.search(r'TOP_MARGIN := ([\d.]+)',source)[1])
    bottom = float(re.search(r'BOTTOM_MARGIN := ([\d.]+)',source)[1])
    cases = 0
    for width, height in [(760,520),(1280,800),(1920,1080)]:
        aspect = width/height
        for left in range(-8,9):
            for right in range(left,9):
                for locked in (False,True):
                    lo, hi = (-8,8) if locked else (left,right)
                    extent = max((jump+2.4)/(1-top-bottom),(hi-lo+3.2)/aspect)
                    cx = max(-4,min(4,(lo+hi)*0.5))
                    cy = extent*(0.5-bottom)
                    assert left-1.6 >= cx-extent*aspect*0.5-1e-6
                    assert right+1.6 <= cx+extent*aspect*0.5+1e-6
                    assert math.isclose(cy-extent*0.5,-extent*bottom)
                    assert jump+2.4 <= cy+extent*0.5-extent*top+1e-6
                    cases += 1
    router = (ROOT / "godot/fighting/presentation/input_router.gd").read_text()
    main = (ROOT / "godot/fighting/main.gd").read_text()
    assert "InputMap." not in router and "InputMap." not in main
    assert "simulation.step(commands)" in main and "simulation.configure(roster,rules)" in main
    for forbidden in ("OS.create_process", "OS.execute", "PortNetwork", "MENU_ROUTE", "Career."):
        assert forbidden not in main
    assert "const IDS" not in main
    assert "held |= pressed" in router, "subtick taps must reach held-history core"
    assert "effects.present_projectiles(state.projectiles,state.fighters)" in main
    assert "effects.present_fighter(state.fighters[p],visuals[p])" in main
    assert "effects.set_paused(paused or not focused)" in main
    for method in ("_process", "_tick", "_present_snapshot_effects"):
        body = main.split(f"func {method}(",1)[1].split("\nfunc ",1)[0]
        assert "effects.configure(" not in body, "FX pools cannot rebuild every frame/tick"
    report = {"status":"READY_FOR_ENGINE_DEPENDENCY_INTEGRATION","grammar_files":[str(p.relative_to(ROOT)) for p in files],"camera_cases":cases,"stages":stages,"mapper_behavior":"prepared real InputEvent gate; unrun without engine grant","native_journey":"prepared; unrun","render_acceptance":"unrun","gpu_profile":"unrun"}
    args.evidence.mkdir(parents=True,exist_ok=True)
    (args.evidence / "source-proof.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps(report,indent=2))


if __name__ == "__main__":
    run()
