# Acceptance — READY FOR BLENDER

## Completed in Node / static Python syntax only

Source geometry hash: `916164f0417369f37506e3908e940c961ea142aa349dcda3226ca1f316a040eb`.

- Deterministic generator `--check` passes.
- 118 terrain surfaces, 1,688 individual source wall triangles (844 original quads), 38 source blocks, three fully modeled ceiling slabs.
- Real frozen derivative `Match` factory intercepts only arena assignment, matching the world adapter pattern.
- 689 source navigation nodes; all 689 in one connected component.
- All 21 spawn/pickup/flag/objective locations supported, unobstructed and connected via a real `walkEdge` to that component.
- Twelve real source movement journeys: six routes × both directions, no jump/teleport/lift, zero measured floor-height error.
- CTF: upper and lower routes physically carry flags back; third middle-route capture completes the source round. Enemy pickup, dropped-flag return, score and terminal state asserted.
- DM / team DM: source damage, respawn, five-kill scoring and terminal state fixtures pass.
- KOTH / uplink / holdout: real zone progression and full source-round terminal states pass. Zone fixtures position actors deliberately; these are not native input journeys.
- Real source health pickup is collected through `Match.step`.
- Up/down ceiling rays, support beneath nonwalkable roofs, open arch LOS, solid wall LOS, slope ceiling and water-void queries pass.
- Blender authoring script parses with Python AST; Blender/bpy has not run.

Reproduce:

```sh
node tools/godot-multiplayer/new-maps/parallax-observatory/generate.mjs --check
node port/new-maps/parallax-observatory/acceptance.mjs
node port/new-maps/parallax-observatory/wall-contacts.mjs
```

Evidence directory: `/home/mojo/.tmp-on-disk/cocs-new-map-observatory-evidence-20261002/`.
`node-acceptance-wallfix.json` contains the current measured results; `node-acceptance.json` retains the initial acceptance. `failures.md` retains corrected test failures.

### Source movement wall correction (Gravemill finding)

`terrainWallSegments` considers perimeter edges. Tall quad walls have no edge intersecting a standing actor's body span. All source walls now use individual triangles, whose diagonals provide that span; visual triangles are exactly identical. A comparison against commit `408ed002` verifies the arena is otherwise byte-structure equivalent. Blender emission accepts those triangles and emits each parapet cap only once.

`wall-contacts.mjs` tests 180 consecutive input frames (3 s) from each side. Contact aprons are explicitly synthetic supported floors around exact production wall footprints so the sea does not invalidate outside contacts; none is added to the map. Ground/upper tall-wall regressions extend those footprints to 4 m and reproduce the reported source bug.

| Contact | Quad signed stopping distance | Triangulated distance | Actor radius |
|---|---:|---:|---:|
| Ground 4 m regression, both sides | −22.335 m (crossed) | 0.4213 m | 0.42 m |
| Upper 4 m regression, both sides | −22.335 m (crossed) | 0.4213 m | 0.42 m |
| Exact ground/upper low parapets, both sides | 0.4213 m | 0.4213 m | 0.42 m |
| Exact ramped parapet, both sides | 0.4311 m | 0.4311 m | 0.42 m |

The existing low parapets were already movement-solid; this is not misreported as a production tall-wall failure. Vault walls use solid blocks and pass independent two-face source contact tests on supported aprons. Real map tests also push into vault side walls, move 33.935 m through each open arch/vault in both directions over 4 s, walk under the service gallery, and launch actors upward against all three real slab undersides. The recipe has no separate window passage to claim as tested.

Evidence: `wall-contacts-before.json`, `wall-contacts-after.json`, `node-acceptance-wallfix.json`. All six routes in both directions, pickups, flag returns/captures and all six source full-round fixtures pass after triangulation. Navigation remains 689/689 connected.

## Explicit slot boundary

No Blender, Godot, engine import, bake or render has run in this workstream. No GLB, `.blend`, screenshots or walkthrough clip exists yet. Native menu/room registration is parent-owned and remains pending. No native acceptance, visual quality, FPS, asset-size result or HUD-readability result is claimed.

After explicit parent grant, serial execution only, `LP_NUM_THREADS=1`:

```sh
/home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender -b -t 1 --python tools/godot-multiplayer/new-maps/parallax-observatory/blender_author.py -- --slot-granted --render
node port/new-maps/parallax-observatory/audit-art.mjs
```

Verify binary path first. Use pinned native engine `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64` only after parent integration and grant.

Still required:
1. Inspect actual three eye-level frames and overview, revise art where needed, retain failures.
2. Production GLB import, source geometryHash matching, material/collision parity and measured asset budgets.
3. Actual native input journeys over upper/lower routes and flag pickup/return/capture; record walkthrough clip.
4. Production CTF, zone and DM room acceptance, wide/compact HUD objective readability, readable sea hazards and cover sightlines.
5. Check decorative dish/dome/armillary clearance in the engine and source parity at every apparent opening.
6. Publish image/clip paths and explicitly release the engine/Blender slot after acceptance.

**Engine/Blender slot status: not acquired, not used. Waiting for explicit grant.**
