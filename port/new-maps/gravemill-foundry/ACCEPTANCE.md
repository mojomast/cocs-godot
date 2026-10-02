# Gravemill Foundry — revision 3 production acceptance

Map ID: **`gravemill-foundry`**. Native pairs: **deathmatch, teamdeathmatch, payload, assault, combined-arms, domination**. Parent retains final architectural review and combined package/catalog closure. The source/authority rules and the original seven maps are unchanged.

## Identity and deliverables

```text
geometry  8ebb148f209aca14c54246517f7332a18e5fbb5c68f7b607d980f5664fcde25f
recipe    3c7f9242bb7c98000871b27d58d14c719a4867e1a9fc625b106c97f7c1c608eb
seed      0x47524156
```

* Editable master: `tools/godot-multiplayer/new-maps/gravemill-foundry/gravemill-foundry.blend`.
* Runtime GLB: `godot/multiplayer_worlds/art/worlds/gravemill-foundry.glb`.
* Runtime wrapper: `godot/multiplayer_worlds/generated/gravemill-foundry.json`.
* Current recipe: `tools/godot-multiplayer/new-maps/gravemill-foundry/recipe.mjs`, delegating to `revision3/recipe.mjs`.
* Author: `tools/godot-multiplayer/new-maps/gravemill-foundry/revision3/author.py`.
* Test drivers and 1,026 probes: `godot/tests/new_maps/gravemill_foundry/`.
* Compact proof records: `source-validation.json`, `native-validation.json`, `visual-validation.json`, `bot-validation.json`, `provenance.json`, `capabilities.json` in this directory.

Prototype commits `afbe57dc` / `ec041aee` are preserved. Their assets have an additional read-only, SHA-256-verified external archive, including original proof/author files. The archive manifest and exact final asset hashes are recorded in `provenance.json`. No prototype evidence directory is overwritten.

## Architectural revision

The crusher drums now inhabit a folded-roof process house with hopper/chutes, clear-span trusses, a covered freight threshold and maintenance aisle. A separate angled transfer passage gives the middle payload segment cover. The furnace district combines kiln arches, buttresses, service enclosure and a loading canopy around the towers. Cooling retains its barrel vault but gains enclosure and machinery recesses; assay becomes an asymmetric pitched control building with partitioned rooms and public inspection apertures. Unequal faceted geological benches replace the repeated outer teeth.

Actual native overview, crusher passage/maintenance, cooling, assay and furnace views were inspected; additional cross-aisle/room views supplement long corridor perspectives. Native eye views use source standing head height, 1.45 m above support. Blender Cycles interior views are darker than the production native ambient environment; native images are the gameplay appearance reference. Full design/iteration history: [REVISION3-PRODUCTION.md](REVISION3-PRODUCTION.md).

## Source and native geometry

* 384×288 m envelope, 35 m terrain relief; **334 surfaces and 2,320 wall triangles**.
* **Ten authored routes**, each tested in both directions; **3,698 connected navigation nodes**, all 22 markers reachable.
* Source mounted Puma completes **767.64 m / 13 segments**, zero collisions, seat released.
* Payload path remains **363.60 m**, with all anchors supported and all three checkpoints delivered.
* All six controlled source rounds pass. New building walls are tested through continuous actor input from both sides, blocking rays, four district ceilings and clear inspection apertures versus solid lintels.
* Production binder: **1,026 floor rays + 1,026 standing capsules**, 160 original wall-contact steps, **600 new-building contact steps**, eight gallery/window rays, four district ceilings, two assay inspection rays and conveyor underside.
* Imported art comparison: **2,312 architecture wall triangles and 824 overhead triangles** match source coordinates at 1 mm precision. Eight outer containment triangles are deliberately excluded from visual art comparison. Art remains non-colliding in production.
* A further **1,026 rays against imported GLB triangles** verify visual floor/support agreement; maximum discrepancy is **0.035 m** from shallow cosmetic trim/sleepers.
* **3,158 authoritative collision triangles**. Overheads remain non-walkable, preserving source support selection and tunnel/deck behavior.

Foundry's GLB import disables mesh compression and generated LODs after an actual comparison exposed millimetre-scale import quantization. No global import or renderer rule changes.

## Hosted native gameplay

The fixture launches two production native clients against the ordinary source-authority server. Native clients serialize the directional/action inputs; Node only reads source telemetry to steer and assert outcomes. Configuration limits and passive/retreating opposition are controlled and documented. No actor position, health, score, objective or clock state is injected.

`native-validation.json` records the final six mode outcomes, native result acknowledgements, movement distances and source shots. Payload requires full three-checkpoint delivery. Combined arms requires real mount, >60 m drive with a bend, authority vehicle-shot events received by both native peers, dismount, zone capture and victory. DM/TDM require five source kills and completed rounds; assault and domination require objective victories.

Autonomous bots are reported separately: domination ends at 64.8 s with a captured zone and 50-point victory; payload advances **156.17 m and checkpoint one**, with five kills in 120 s, but does **not** finish that bounded round. These observations are not competitive-balance or universal bot-completion claims.

## Measured asset budget and visual scope

**69,870 triangles, eight mesh/material batches, 7,086 editable source/detail objects**. GLB: **3,744,260 bytes**; master: **40,527,432 bytes**. Master reopen reports 7,103 total objects, including export/review objects, and eight retained cameras. Nine material datablocks include an unused default; eight are exported.

Final Blender generation/export: **0.888 s** inside the process. Five 1440×900 CPU Cycles reviews: **333.31 s total**, 30.95–81.34 s individually, one thread / 16 samples. Native scene counts and software capture metrics are recorded in `visual-validation.json`. No GPU-performance or fabricated PBR claim is made.

Full UI gates use **1280×800 at 100%** and **760×520 at 150%**. A map-scoped production hook wraps the existing labels at available width; the test fixture uses those actual labels. The continuous walkthrough retains per-frame monotonic timestamps, reports real cadence and maximum/percentile gaps, and is encoded at 15 fps by timestamp resampling. Encoded fps is not capture performance. Parent owns the separately requested trailer.

Final clip: **53.229 seconds, 518 captured frames, 9.713 captures/s**; median/p95/max gaps **99/128/243 ms**, no gap over 250 ms. Both district walkthrough sizes and a further compact rendered payload full round pass. Actual screenshots and decoded clip contact sheet were inspected. The existing ability card remains scrollable at compact size.

## Evidence and reproducibility

Root: `/home/mojo/.tmp-on-disk/cocs-new-map-foundry-evidence-20261002/revision3-production/`.

* `checkpoint-afbe57dc/`: read-only original assets and proof archive.
* `blender-01/`, `blender-02/`: preserved initial/final architectural render attempts.
* `source/`: final source/round/bot receipts.
* `native/`: hosted native round logs/results.
* `native-final-views/`: default-lighting overview and architectural perspectives.
* `wide/`, `compact/`: actual native-input walkthrough/HUD evidence; `wide/walkthrough.mp4` is the continuous three-district clip.
* `physics-final.log`, `reopen-final.log`, `inspection-final.log`: production evidence. Failed physics and fixture attempts are retained and explained in the production record.

```sh
node tools/godot-multiplayer/new-maps/gravemill-foundry/build.mjs --check
node port/new-maps/gravemill-foundry/source-check.mjs
node port/new-maps/gravemill-foundry/round-check.mjs
node tools/godot-multiplayer/new-maps/gravemill-foundry/revision3/architecture-check.mjs
```

Heavy repro requires a new exclusive grant; use unique evidence directories:

```sh
LP_NUM_THREADS=1 OMP_NUM_THREADS=1 "$BLENDER" -b -t 1 --python tools/godot-multiplayer/new-maps/gravemill-foundry/revision3/author.py -- --render --evidence="$NEW_EVIDENCE/blender"
node tools/godot-multiplayer/new-maps/gravemill-foundry/revision3/promote.mjs
node tools/godot-multiplayer/new-maps/gravemill-foundry/build.mjs
LP_NUM_THREADS=1 "$GODOT" --headless --path godot --editor --import
LP_NUM_THREADS=1 "$GODOT" --headless --path godot --script res://tests/new_maps/gravemill_foundry/physics_probe.gd
LP_NUM_THREADS=1 FOUNDRY_EVIDENCE="$NEW_EVIDENCE/native" node port/new-maps/gravemill-foundry/native-suite.mjs
LP_NUM_THREADS=1 LIBGL_ALWAYS_SOFTWARE=1 FOUNDRY_EVIDENCE="$NEW_EVIDENCE/wide" xvfb-run -a node port/new-maps/gravemill-foundry/native-journey.mjs walkthrough
LP_NUM_THREADS=1 LIBGL_ALWAYS_SOFTWARE=1 FOUNDRY_COMPACT=1 FOUNDRY_EVIDENCE="$NEW_EVIDENCE/compact" xvfb-run -a node port/new-maps/gravemill-foundry/native-journey.mjs walkthrough
node port/new-maps/gravemill-foundry/encode-clip.mjs "$NEW_EVIDENCE/wide" walkthrough
```

`BLENDER`: pinned 4.5.14 toolchain; `GODOT`: pinned 4.5.2. Frozen game/server files, original-map assets, shared package allowlists and manifest verifiers are unmodified. Parent integrates the isolated Foundry asset/proof and map-only HUD commits, then performs combined native/package closure.

**EXPLICIT ENGINE/BLENDER SLOT RELEASED — all owned jobs stopped.** Parent combined-native work has priority next; no additional Foundry heavy process will start without another explicit grant.
