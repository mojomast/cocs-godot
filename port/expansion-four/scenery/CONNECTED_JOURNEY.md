# Scenery transaction and connected campaign journey

Source-only implementation started on canonical `ce084d50`. Robot grant D has
completed; grant E now belongs exclusively to the vehicle producer. No Blender,
engine, import, render, audio, encoding or
authority journey ran here. Generic asset production, robot builders, source
physics, scenery recipes, package tools and cinematic interfaces were not edited.

## Adapter repair

`godot/biomes/expansion/scenery_pack.gd` now prepares all six chapter instances
before publishing `_installed`, `loaded_assets` or `recipe_hash`. Every early
failure frees pending instances immediately; rebuild starts from an empty owned
pack. `clear()` is synchronous and idempotent and touches only installed groups.
Null/non-PackedScene resources, empty scenes, non-Node3D roots, scripts, collisions,
non-visual classes, missing meshes and nonfinite/singular transforms are rejected.
Placement scales must be finite and positive; the exact chapter SHA/geometry
binding is still required. Three unique assets / two LODs are mandatory.

`last_build` provides `status`, `code`, and the exact offending resource path:
optional startup records `fallback`, while required loading records `failed` and
reports an error. Both return false with zero installed groups/asset bookkeeping.
Success records `installed`. Existing `BiomeExpansionFour`, root names,
`biome4_lod`, `reviewed_block`, `loaded_assets`, `recipe_hash` and the 85 m switch
are retained for production/cinematic callers. There is no terrain-hook change.

Imported material overrides are private to each instance; mesh/texture resources
remain shared. Tinting one instance cannot mutate the cached source material or
another LOD. No host/workshop/terrain material is accessed by this preparation.

Prepared engine contract (synthetic injection, **not real asset proof**):

```sh
"$GODOT_BIN" --headless --path godot --script res://tests/biome_assets/atomic_lifecycle.gd
```

After a grant only. The fixture injects late null/wrong-resource/wrong-root,
collision, singular-transform, empty-mesh and missing-import cases; checks required
versus optional diagnostics and synchronous disposal; then checks private material
ownership, repeated reduced-detail switches, clear, rebuild and failure after a
previous success. Expected failure diagnostics are captured by its test subclass.
It does not weaken normal production reporting or substitute cubes for acceptance.

## Real connected gameplay commands

Build/reopen/import the actual scenery pack first and run the existing exact
imported-geometry gate. Then, **under an explicitly assigned scenery grant**:

```sh
python3 tools/godot-biomes/expansion/run-journey.py --map rootfall-verge --granted
python3 tools/godot-biomes/expansion/run-journey.py --map siltwake-crossing --granted
python3 tools/godot-biomes/expansion/run-journey.py --map emberline-ascent --granted
python3 tools/godot-biomes/expansion/run-journey.py --map crown-array --granted
```

Add `--compact` for 760×520/UI150; default is 1280×800/UI100. The wrapper acquires
the shared nonwaiting exclusive lock, creates one owned process group and bounds
each chapter to 1200 seconds. Campaign and subsequent Home processes are serial.
Each chapter requires exactly its three reviewed assemblies and both imported
LODs. Missing output files fail before authority construction; malformed imported
scenes fail the required build. Each journey independently compares all six actual
imported meshes against the exact reviewed recipe triangles using the existing
geometry oracle (now static/reusable). No placeholder GLBs can satisfy this journey.

`journey-plan.mjs` builds a connected itinerary from existing critical-path and
workshop spur/link routes. It includes the necessary preceding encounters, both
workshops, each return spur and a reverse walk back to the starting source point.
Half-metre samples check source support/body clearance without running a Match.
The generated plan binds exact campaign bytes, geometry identity, scenery recipe
hash and asset IDs. Aim heights come from the existing robot hit-volume oracle.

The native driver instantiates **`campaign/demo.tscn`**, launches normally, and
uses `Input.parse_input_event` keyboard/mouse events for walking, aiming, shooting
and E interactions. Ordinary easy difficulty is explicit; no cheats, checkpoint
setup/retry, pose injection, source-clock freezing, health/ammo writes or camera
staging occur. Death/stall/blocked shots are failures to preserve for native repair,
not conditions to bypass. Each workshop requires its public completed event;
player shots, applied fire/interact input and nonzero public ACKs must be observed
by the untouched authority's read-only observer. Actual route snapshots must stay
on supported clear source positions. Source tests are not proof these fights have
been completed natively.

Workshop event identity uses the public envelope's **`sourceId`**, not its numeric
wire `id`; a focused contract covers the actual `EventCursor` transformation.

At the supported return point the fixture verifies unchanged original collider
identities/geometry, repeatedly toggles detail, clears twice, verifies old node
weakrefs are gone, and rebuilds strictly. Captures use the ordinary source-driven
camera and actual source/capture timestamps. It then presses the existing Settings
**Leave match · Return Home** button. This production route exits the campaign
process; it is not an in-process scene swap. The test supervisor checks full exit
logs and world/pack tree-exit notifications, closes the owned authority, and starts
the actual Home menu in the next native process. Home's own cinematic resources
are permitted; they are not mistaken for leaked campaign resources.

Evidence is written to fresh timestamped directories under
`cocs-expansion-four-scenery-evidence-20261002/connected/`: plan, exact GLB hashes,
native/Home logs, public-input/event/ACK witness, actual pose samples, workshop and
return screenshots, Home screenshot and process-exit results. Errors, forced exits,
leak signatures, missing events or failed Home rendering make the final witness
fail, even if earlier gameplay stages completed. No result promotes package assets.

## Source checks versus pending native acceptance

```sh
node --test tools/godot-biomes/expansion/journey-contract.test.mjs
node --check tools/godot-biomes/expansion/connected-journey.mjs
```

Source tests check all four connected route plans/clearance, exact identity
rejection, workshop completion requirements and the adapter's single publication
boundary. They are not a GDScript parse/typecheck, engine lifecycle execution,
real-asset import proof or gameplay victory. Both native fixtures and all four
journeys remain **unrun**. Final architectural review, wet-material restoration,
continuous capture/GPU performance and human gameplay feel remain separate gates.

Actual source result: **3/3 contracts passed**, Node runner syntax and Python
wrapper AST passed. Earlier two-contract evidence is retained at
`/home/mojo/.tmp-on-disk/cocs-expansion-four-scenery-evidence-20261002/source-connected-20261002T232956Z/`;
the additional public-event identity check passed in the final session run.

The robot dependency handoff is `2c39d1ad`, including the Switchyard workshop hook
after `BiomeExpansionFour.build(self)`. This lane has no `terrain.gd` edit and
preserves all six Emberline props, role installation and robot source pins.
Parent should refresh any affected package supporting-input identities after
integrating this legitimate scenery adapter change; that refresh is not a native
acceptance receipt. The art recipes and builder bytes are unchanged.
