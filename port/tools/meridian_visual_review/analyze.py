#!/usr/bin/env python3
"""Validate causal-run records and inspect the original sphere's binary winding."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import struct


def read_json(path):
    """Fresh runs use JSON; archived inventories retain identical bytes in gzip."""
    if path.is_file():
        return json.loads(path.read_bytes())
    return json.loads(gzip.decompress(path.with_suffix(path.suffix + ".gz").read_bytes()))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run", type=Path)
    parser.add_argument("--glb", type=Path, required=True)
    parser.add_argument("--original-image", type=Path, required=True)
    args = parser.parse_args()
    records = {name: read_json(args.run / (name + ".json"))
               for name in ["baseline", "source-cull-only", "camera-inside"]}
    baseline, restored, inside = (records[name] for name in records)
    assert baseline["imported_inventory"] == restored["imported_inventory"] == inside["imported_inventory"]
    assert baseline["camera_after"] == restored["camera_after"] == [110, 125, 140]
    assert inside["camera_after"] == [55, 62.5, 70]
    expected = dict(baseline["sky_material_after"], cull_mode=1)
    assert restored["sky_material_after"] == expected
    assert inside["sky_material_after"] == baseline["sky_material_after"]
    assert args.original_image.read_bytes() == (args.run / "baseline.png").read_bytes()
    run = json.loads((args.run / "run.json").read_text())
    data = args.glb.read_bytes()
    assert hashlib.sha256(data).hexdigest() == run["input_glb_sha256"]
    length = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20:20 + length])
    binary_start = 20 + length + 8

    def accessor(index):
        a = gltf["accessors"][index]
        view = gltf["bufferViews"][a["bufferView"]]
        components = {"SCALAR": 1, "VEC3": 3}[a["type"]]
        fmt = "<" + {5123: "H", 5125: "I", 5126: "f"}[a["componentType"]] * components
        start = binary_start + view.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = view.get("byteStride", struct.calcsize(fmt))
        return [struct.unpack_from(fmt, data, start + i * stride) for i in range(a["count"])]

    def minus(a, b):
        return [x - y for x, y in zip(a, b)]

    def cross(a, b):
        return [a[1]*b[2] - a[2]*b[1], a[2]*b[0] - a[0]*b[2], a[0]*b[1] - a[1]*b[0]]

    def dot(a, b):
        return sum(x*y for x, y in zip(a, b))

    primitive = gltf["meshes"][48]["primitives"][0]
    vertices = accessor(primitive["attributes"]["POSITION"])
    normals = accessor(primitive["attributes"]["NORMAL"])
    indices = [v[0] for v in accessor(primitive["indices"])]
    counts = {"outward": 0, "inward": 0, "degenerate": 0}
    for index in range(0, len(indices), 3):
        a, b, c = (vertices[i] for i in indices[index:index+3])
        direction = dot(cross(minus(b, a), minus(c, a)), a)
        counts["outward" if direction > 1e-6 else "inward" if direction < -1e-6 else "degenerate"] += 1
    assert counts["outward"] > 0 and counts["inward"] == 0
    assert all(dot(v, n) > 0 for v, n in zip(vertices, normals))
    result = {
        "checks_passed": ["historical PNG byte-identical to new baseline", "all imported inventories identical",
                          "cull-only camera unchanged", "cull-only material differs only CULL_BACK -> CULL_FRONT",
                          "camera-inside materials unchanged", "historical GLB SHA matches", "sky winding/normals outward"],
        "gltf_sky_triangle_winding": counts,
        "gltf_sky_vertex_normals": "all outward",
        "baseline_png_sha256": hashlib.sha256(args.original_image.read_bytes()).hexdigest(),
        "camera_distance": baseline["camera_distance"], "sphere_radius": 185,
        "mesh_count": baseline["mesh_count"], "native_sky_path": baseline["sky_path"],
        "visual_review": "Images must be separately read; numerical checks are causal controls, not parity acceptance.",
    }
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
