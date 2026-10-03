"""Exact integration contract requested from the shared (Sol-owned) material adapter.

This file only imports the adapter; it never implements Moth binding itself, so
the builder cannot silently guess an unfinished adapter. Sol owns
`tools/map-variety-pipeline/material_adapter.py`.

Required callable::

    load_materials(root, bindings, *, output_dir=None, with_report=False)

  bindings  : {exact_name: {material: pack ID, role: surface|team, normal: bool}}
  materials : {exact_binding_name: bpy.types.Material} for these PBR keys only.
  density   : {exact_binding_name: tiles-per-metre float, 0 < value <= 16}.

The adapter MUST:

  * read ``bindings[name].material`` and resolve the merged
    candidate-v2 + candidate-v3 pack through
    ``materials[].channels`` -> ``textures[].path`` (IDs, not file order);
  * retain immutable linear source images; derive sRGB albedo PNGs and bind
    those as sRGB images for Blender and glTF. Ordinary glTF export must not
    be assumed to re-encode a Non-Color source. Record derived hashes separately;
  * wire normal as Normal Map (OpenGL +Y, tangent, strength =
    binding ``normalStrength``), roughness into Roughness, and leave height/wear
    as decorative inputs only (never collision authority);
  * reject preserved materials; map_materials.py authors explicit map palettes
    outside the PBR adapter and merges materials/densities before Kit creation;
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
