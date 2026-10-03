"""Exact integration contract requested from the shared (Sol-owned) material adapter.

This file only imports the adapter; it never implements Moth binding itself, so
the builder cannot silently guess an unfinished adapter. Sol owns
`tools/map-variety-pipeline/material_adapter.py`.

Required callable::

    load_materials(root: pathlib.Path, bindings: dict) -> (materials, density)

  materials : {exact_binding_name: bpy.types.Material} for every key in
              ``bindings['materials']`` (preserved names included).
  density   : {exact_binding_name: tiles-per-metre float, 0 < value <= 16}.

The adapter MUST:

  * read ``bindings['materials'][name].resource`` and resolve the merged
    candidate-v2 + candidate-v3 pack through
    ``materials[].channels`` -> ``textures[].path`` (IDs, not file order);
  * set every base channel image to **Non-Color** colourspace: all five pack
    channels are linear, including albedo. Albedo connects to the shader's
    linear base color; the glTF base-color sRGB encoding is the exporter's job;
  * wire normal as Normal Map (OpenGL +Y, tangent, strength =
    binding ``normalStrength``), roughness into Roughness, and leave height/wear
    as decorative inputs only (never collision authority);
  * keep preserved materials (glass/water/emissive/letter) free of Moth textures;
  * reject unknown resource ids and missing channels instead of reusing a
    fallback material.
"""
import importlib


class MissingAdapter(RuntimeError):
    """Raised when the shared adapter has not been delivered yet."""


REQUIRED = ('load_materials',)


def load_adapter(module_name='material_adapter'):
    try:
        adapter = importlib.import_module(module_name)
    except ImportError as error:
        raise MissingAdapter(
            "MISSING SOL ADAPTER HOOK: " + module_name + ".load_materials(root, bindings) is not "
            "importable. Deliver tools/map-variety-pipeline/" + module_name + ".py per "
            "tools/godot-multiplayer/new-maps/map_variety/ADAPTER_CONTRACT.md before --build.") from error
    missing = [name for name in REQUIRED if not callable(getattr(adapter, name, None))]
    if missing:
        raise MissingAdapter('Shared adapter missing callables: ' + ', '.join(missing))
    return adapter
