# Source/native contract

Read: `game/core.mjs`, `game/terrain.mjs` API usage, map schema, existing world
recipes, `port/multiplayer-worlds/build-world-catalog.mjs`, scoped Match intake,
and `godot/multiplayer_worlds/map.gd`.

The recipe emits the complete authority once, including non-walkable ceilings.
`build.mjs` writes only these owned files:

* `port/native-multiplayer-worlds/worlds/vesper-viaduct.json`
* `godot/multiplayer_worlds/generated/vesper-viaduct.json`

The latter uses the existing schema-1 envelope, canonical geometry hash, recipe
hash and actual source floor heights for spawn points. There is no repeated
overhead expansion. `build.mjs --check` verifies deterministic byte identity.

The Blender master exporter maps source `(x,y,z)` to Blender `(x,-z,y)` and exports
Y-up glTF. All authoritative surfaces and wall triangles are represented exactly
and tagged `source_authority`. Decorative meshes are art-only. No GLB collision
is consumed. A reopened master must match the current recipe SHA before export.

## Parent integration dependencies

Parent owns registries, shared loaders and final packaging. No shared edits are
included in this lane. After visual/native approval:

1. Register `vesper-viaduct` / `Vesper Viaduct` with only verified modes.
2. Canonical consolidation already corrected the asset target to
   `res://multiplayer_worlds/art/worlds/vesper-viaduct.glb`; production `map.gd`
   loads it without a resolver change. The existing `art.ground` marker indicates
   that the GLB contains visible source surfaces, avoiding double drawing.
3. Include the generated JSON and GLB in the usual shared manifests and package
   audit. Exclude tests and keep the `.blend` outside `godot/`.

Frozen core SHA remains
`58ff1b9c7467a53da00638f16edfd3df2e1e6fd06480ff081ad13c88fb64bdb9`.
No source-rule or source registry change is required by this recipe.
