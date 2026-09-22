#!/usr/bin/env python3
"""Compare GLB logical resources, allowing async embedded-image buffer ordering."""
import argparse
import hashlib
import json
from pathlib import Path
import struct


class GLB:
    def __init__(self, path):
        self.data = Path(path).read_bytes()
        length = struct.unpack_from("<I", self.data, 12)[0]
        self.json = json.loads(self.data[20:20 + length])
        self.binary = self.data[28 + length:]

    def view(self, index):
        view = self.json["bufferViews"][index]
        start = view.get("byteOffset", 0)
        return self.binary[start:start + view["byteLength"]]

    def accessor(self, index):
        accessor = self.json["accessors"][index]
        view = self.json["bufferViews"][accessor["bufferView"]]
        components = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[accessor["type"]]
        fmt = "<" + {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}[accessor["componentType"]] * components
        start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        stride = view.get("byteStride", struct.calcsize(fmt))
        return [struct.unpack_from(fmt, self.binary, start + i * stride) for i in range(accessor["count"])]


def compare(before, after, *, repaired):
    a, b = GLB(before), GLB(after)
    # Preserve complete scene hierarchy, primitive mappings, materials and images.
    for key in set(a.json) | set(b.json):
        if key not in {"bufferViews", "images", "accessors"}:
            assert a.json[key] == b.json[key], key
    assert len(a.json["images"]) == len(b.json["images"])
    for old, new in zip(a.json["images"], b.json["images"]):
        assert old["mimeType"] == new["mimeType"]
        assert a.view(old["bufferView"]) == b.view(new["bufferView"])
    assert len(a.json["accessors"]) == len(b.json["accessors"])
    changed = {i for i in range(len(a.json["accessors"])) if a.accessor(i) != b.accessor(i)}
    affected = []
    expected = set()
    for i, mesh in enumerate(a.json["meshes"]):
        for primitive in mesh["primitives"]:
            index = primitive.get("indices")
            if index not in changed:
                continue
            attrs = primitive["attributes"]
            assert primitive.get("mode", 4) == 4
            old = a.accessor(index)
            new = b.accessor(index)
            assert len(old) % 3 == 0
            for j in range(0, len(old), 3):
                assert new[j:j+3] == [old[j], old[j+2], old[j+1]]
            assert b.accessor(attrs["NORMAL"]) == [tuple(-x for x in normal) for normal in a.accessor(attrs["NORMAL"])]
            assert not b.json["materials"][primitive["material"]].get("doubleSided", False)
            expected.update([index, attrs["NORMAL"]])
            affected.append({"mesh": i, "triangles": len(old)//3,
                             "position_bounds": {key: a.json["accessors"][attrs["POSITION"]][key] for key in ["min", "max"]}})
    assert changed == expected
    assert len(affected) == (2 if repaired else 0), affected
    return {"before_sha256": hashlib.sha256(a.data).hexdigest(), "after_sha256": hashlib.sha256(b.data).hexdigest(),
            "changed_accessors": sorted(changed), "affected_meshes": affected,
            "unchanged_accessors": len(a.json["accessors"])-len(changed), "unchanged_images": len(a.json["images"]),
            "hierarchy_materials_transforms_uvs_colors_positions_identical": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before", required=True)
    parser.add_argument("--after", required=True)
    parser.add_argument("--historical")
    args = parser.parse_args()
    result = {"repair": compare(args.before, args.after, repaired=True)}
    if args.historical:
        result["historical_vs_fresh_original"] = compare(args.historical, args.before, repaired=False)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
