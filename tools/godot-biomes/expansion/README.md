# Campaign biome expansion four

Source-only checkpoint: 12 additive original architecture/natural assemblies,
three per production chapter. Read
[`DESIGN.md`](../../../port/expansion-four/scenery/DESIGN.md) and
[`ACCEPTANCE.md`](../../../port/expansion-four/scenery/ACCEPTANCE.md).

- `recipe.mjs`: named editable triangulated geometry, deterministic seed/palettes.
- `compile.mjs`: source-bound placement catalog and byte-stable `meshes.json`.
- `build.py`: explicit-slot-only Blender master and two-LOD GLB export.
- `reopen.py`: explicit-slot-only independent master reopening.
- `masters/`: future native `.blend` outputs; intentionally outside `godot/`.
- `godot/biomes/expansion/`: isolated runtime catalog/adapter and future GLBs.
- `godot/tests/biome_assets/`: source proof and prepared production-native runners.

Do not invoke Blender/Godot until the parent explicitly grants the heavy slot.
