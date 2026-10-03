#!/usr/bin/env python3
"""Check Moth depth variants without starting Godot or importing the project."""

from pathlib import Path
import re

MOTH = Path(__file__).resolve().parents[2] / "moth"
priority = (MOTH / "surface.gdshader").read_text()
opaque = (MOTH / "surface_opaque.gdshader").read_text()
bias = "DEPTH = FRAGCOORD.z + (vertex_tint ? UV.x * 0.000001 : 0.0);"


def statements(source: str) -> list[str]:
    return [
        line.strip()
        for line in source.splitlines()
        if line.strip() and not line.lstrip().startswith("//")
    ]


assert priority.count(bias) == 1, "priority bias must remain exact"
assert len(re.findall(r"\bDEPTH\s*=", priority)) == 1, "unexpected priority depth assignment"
assert not re.search(r"\bDEPTH\s*=", opaque), "opaque shader writes depth"
assert [line for line in statements(priority) if line != bias] == statements(opaque), (
    "shader uniforms, lighting, normals, or LUT logic diverged"
)
print("MOTH_SHADER_PARITY_OK")
