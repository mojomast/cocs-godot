# Native combat pickup assets

## Integration

`godot/world/pickups.gd` now instantiates
`res://combat_pickup_assets/pickup_visual.gd`. This one preload change is the
entire integration patch. Existing native sessions already use `PortPickups`.
Authority IDs, `y + 1.0` support position, `wait <= 0` availability, reordering,
stale removal, and round clearing retain their existing semantics.

The new native miniatures cover all 20 source kinds:

- Health: capped medical core with front/back cross; megahealth adds side cells.
- Armor: pointed shield battery; overshield adds raised white side rails.
- Ammo: three energy cells in a compact carrier.
- Nine weapon pickup kinds: rocket, rail, scatter, plasma, grenade, shock, flak,
  marksman, SMG. Distinct compact receiver/barrel/drum/coil silhouettes correspond
  to `game/maps.mjs`'s `pickupWeapon` mapping (inventory slots 1–9).
- Haste chevrons, overcharge diamond, recon dish, cloak cone, weapon-upgrade arrow,
  and folded deployable miniature.
- Unknown kinds: neutral diamond-marked supply case; source metadata is retained.

The starter weapon is inventory slot 0 and has no source pickup kind. Generic
ammo stays generic because it does not reliably identify an equipped weapon.
Models are original native geometry authored for this lane, independent of the
changing first-person weapon export/anchor files. Shape and white iconography
provide identity in addition to color. There are no world captions, labels,
billboards, collision bodies, collection effects, or health-award code.

## Materials and budget

The energy shader uses the existing read-only Moth `brushed_metal`, `flow-field`,
and `entanglement-arcane` R/T LUT resources through `moth/library.gd`, plus the
existing shared Moth shader helpers. Horizontal energy bands and a thin,
interrupted holographic ring animate with a decorative clock only. Opaque depth
testing/writing applies to both model and ring; source texture alpha is not
used as coverage. Hidden pickup roots hide the entire presentation and reset
the decorative clock. Animation never decrements a respawn wait.

| Resource | Bound |
| --- | --- |
| Nodes per authoritative pickup ID | 1 root + 4 mesh leaves |
| Draws per visible pickup | 4 single-surface draws, no shadow draws |
| Triangles per pickup, including ring | **708 maximum**, measured over all source kinds |
| Ring footprint | 0.73 m diameter, 0.02 m tube diameter |
| Model bounds | Each mesh axis <= 0.8 m; 0.025 m decorative vertical motion |
| Mutable shader materials | 2 per live pickup ID, independent across IDs |
| Shared solid materials | 2 |
| Geometry cache | At most 21 kinds, including one unknown fallback; shared ring |
| Moth image resources | 4 shared images (albedo, flow, R, T) |
| Particles / world labels / lights | **0 / 0 / 0** |
| Distance cutoff | 45 m on the render leaves |

Node count is bounded by the current public snapshot's pickup ID count. This
preserves the existing API's one-marker-per-ID contract rather than silently
dropping authority records. Repeated snapshots, reordering, and respawns reuse
the same roots, render nodes, geometry, and materials. Changed kinds reuse the
four leaves; arbitrary unknown kinds cannot grow the cache. Stale IDs are freed,
not retained in a second inactive pool. Clear has zero roots and render nodes.

## Verification and evidence

Run:

```sh
node port/native-combat-pickup-assets/run-checks.mjs
```

Uses the pinned Godot **4.5.2**, Compatibility renderer, separate Xvfb displays,
and private `/tmp/opencode/cocs-pickup-assets-home`. No worktree or content-copy
allocation is required. `--logic-only` skips the native graphical passes.

Results:

- **744 native checks**: immutable snapshots including actor/event data; exact
  source collection availability; no local respawn; actual source respawn;
  retained instances/resources through repeated/reordered snapshots; same-kind
  mesh and texture sharing; unique shader materials; fixed leaf counts; bounded
  triangles/size/cache; unknown fallback; freed materials; repeated round clears.
- Existing read-only `godot/tests/protocol/pickups.gd`: **374 checks**, six
  captured source states, including authoritative support positions and clocks.
- Existing read-only `game/powerups.test.mjs`: **10/10 passed**.
- Actual graphical renders at **960×640** and **1280×720**, perspective camera at
  **1.6 m** eye height, all 20 kinds visible. Budget: **80 render leaves / 80
  model draws**, zero particles. Before/after, availability, actual source
  respawn, all-kind close rows, opaque occlusion, and after-clear PNGs retained.
- Pixel comparisons against the empty baseline: **0 changed pixels** after
  all-source-unavailable and clear, at both sizes. A source pickup behind opaque
  cover also contributes **0 pixels** over the covered empty baseline.
- Real source health collection removes **2,277 / 2,900 pixels** at the two
  sizes. Animated bands/motion change **10,373 / 13,073 pixels**. Frozen rendering
  and reset respawn rendering match exactly.

The source generator arranges pickup positions in a **private test Match**, then
executes unmodified `Match.collect`, `Match.step`, and `Match.snapshot`. All 20
collections, emitted pickup events, +35 health award, wait clocks, and 901-tick
respawn originate in those source methods. These are source-backed arranged
fixtures, **not natural multiplayer collection footage**. Runtime presentation
only consumes public state. The test-only stage's grid and explanatory screen
caption are not shipped as pickup geometry/UI.

Directly inspected images:

- [960 native overview](evidence/960x640/after-native.png)
- [1280 health, armor, ammo, rocket, megahealth](evidence/1280x720/detail-row-0.png)
- [960 weapon silhouettes](evidence/960x640/detail-row-1.png)
- [1280 power/economy shapes](evidence/1280x720/detail-row-3.png)
- [1280 opaque occlusion](evidence/1280x720/occlusion-native.png)
- [960 after clear](evidence/960x640/after-clear.png)

Both evidence directories include `measurements.json`, legacy-before images,
source-collected/unavailable/respawn frames, and every close row. All attempt logs
are retained. Initial validation failures were test-harness issues: incompatible
static `is` checks / untyped `weakref`, then an ArrayMesh-only count method used
on TorusMesh. Those were corrected to generic mesh array inspection and explicit
types. Final runs have no script, shader, resource-leak, or assertion errors.
Xvfb/llvmpipe prints its normal unsupported V-Sync-mode warning.

## Lead follow-up: legacy caption taming

The retained legacy comparison asset (`godot/world/pickup_visual.gd`) still carried the
32 px / 0.005 pixel-size caption that the release matrix recorded as oversized. Production
does not use that file at all — `godot/world/pickups.gd` preloads the caption-free
`combat_pickup_assets/pickup_visual.gd` — so the defect was already obsolete in the shipped
game, but the legacy asset could still render a giant caption if it were ever reused.

Lead applied the taming suggested by the UI lane: `font_size 12`, `pixel_size 0.003`,
`visibility_range_end 6.0`. The comparison fixture was re-run at **960x640 and 1280x720**
and both `before-legacy.png` images were refreshed, so the "before" baseline now shows the
legacy shapes with a small, close-range-only caption. The archived originals are described
in the UI lane's report (`port/native-ui-polish/README.md`).
