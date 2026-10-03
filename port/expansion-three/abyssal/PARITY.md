# Abyssal source/native contract

This is the original source-ready contract. The grant-I production revision,
new exact geometry identity and native outcomes are in [PRODUCTION_I.md](PRODUCTION_I.md).

Inspected implementations:

- `game/core.mjs`: highest-XZ floor support, `moveActor`, `navigation`,
  `rayWorld`, CTF pickup/carry/capture and `Match.step`.
- `game/objectives.mjs`: capture presence, zone scoring and Holdout quorum/window.
- `game/map-schema.mjs`: current source map schema.
- `tools/godot-multiplayer/worlds/{recipes,build}.mjs`: existing recipe format.
- `port/multiplayer-worlds/{catalog,match,build-world-catalog}.mjs`: canonical
  hash, source arena-assignment seam and existing overhead conversion.
- `godot/multiplayer_worlds/map.gd`: AABB `baseY` support; terrain triangle and
  individual wall collision; visual GLB loaded without gameplay collision.

The lane builder emits both the port-owned recipe and the fully compiled native
arena. `recipeHash` hashes the exact recipe bytes; `geometryHash` uses the existing
canonical serializer. Native `spawnPoints` use real source `floorAt` results.
The art script consumes the recipe directly and does not re-expand overhead.

The source fixture subclasses the frozen `Match` with the same arena-assignment
seam used by the existing world adapter. Only controlled initial spawn/team setup
is used. CTF and zone rounds subsequently use ordinary `Match.step` movement and
source objective logic. Scores, owners, flag carriers and winning states are not
injected. This is controlled source-input evidence, not connected native input.

Source core SHA-256 checked unchanged:
`58ff1b9c7467a53da00638f16edfd3df2e1e6fd06480ff081ad13c88fb64bdb9`.
Frozen source pin `515daf07589150dd3241f4ae1425cc1b093912f5` and reviewed derivative
`0326b435a2fdd88e6e7a01b8a7325feccc4d15cb` receive no edits.

## Parent integration contract

Owned artifacts:

1. `port/native-multiplayer-worlds/worlds/abyssal-pressureworks.json`
2. `godot/multiplayer_worlds/generated/abyssal-pressureworks.json`
3. Named authoring directory under `tools/godot-multiplayer/new-maps/`
4. `tests/new_maps/abyssal_pressureworks/source.test.mjs`
5. This lane's documentation.

Parent owns adding the stable ID and accepted modes to shared source/native
catalogs, menus, manifests, derivative registries and package closures. Invoke
the standalone builder for regeneration; avoid routing this already-complete
terrain through any additional slab expansion. No shared hook commit is needed.

Geometry hash:
`994bc6fda8b7f71d1c38b5d6f07fa906dddf74d3e72155400fc86fd965e14509`.
Recipe hash:
`c8573bbe9acc330b3d032a375778f57e288c8707ac9fc0830aff6f2f457d9c97`.

Pending parity evidence: native collider probes, actual rendered clearances and
glazing, hosted wire-mode objective journeys, and graphical/HUD inspection.
