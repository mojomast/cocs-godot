# SHIELD-CAP-ORDER — fixed

Independent review `f80c93c` reproduced a P2 in delivery `c8cae07`: Low allocated
all 16 shell materials to unprotected actors before seeing the sole shield at
actor 16. Reversing the source array changed visibility. The same issue existed
at High's 32-slot boundary.

## Changes

`godot/combat_shields/controller.gd` now separates **up to 256 CPU observations**
from **16/32 shell slots**. Unprotected actors still retain health, armor,
grounded/alive state, hit direction, and event-coalescing history, but do not
reserve shell materials. History does not depend on having a render slot.

Before assigning capacity, candidates are validated and deterministically ranked:

1. Only alive remote actors with a genuine nonempty protection/armor kind,
   outside the camera-clearance radius, not seated, not behind the camera, and
   not hidden by their optional bound actor visual can claim shells.
2. Actual protection/absorb/directional-shield states rank ahead of ordinary
   armor-energy states.
3. Within a protection tier: in-frustum center first, then shorter squared camera
   distance, then smaller numeric wire actor ID. No camera means equal distance
   and the stable numeric-ID tie-break.

Losers release ownership **before** winners claim slots, so previous-frame
owners cannot starve newly eligible actors. The nodes/materials are reused.
Resizing quality frees excess render nodes and registrations but leaves the
observations intact. Reset frees all nodes/materials and history. Camera-only
changes recompute eligibility without requiring a new snapshot.

The source actor array and its dictionaries remain read-only. A private list
is sorted. Observation overflow above 256 uses the same deterministic priority;
the sole genuine shield remains eligible even behind an oversized unprotected
prefix. First observation is a baseline, never a fabricated respawn/recovery.

`tracks[id].slot` may now be `{}`. `debug_state().actors` reports observations;
`slots` and `materials` retain their render-allocation meanings. Public runtime
hooks remain the same. No combat-feedback/FOV/HUD integration files were edited.

## Regression results

| Check | Result |
|---|---|
| Original delivered native fixture | **83 assertions passed** |
| New capacity/history fixture | **170 assertions passed** |
| Fresh source/Godot loopback oracle | 6 SHA-256-correlated snapshots; source shield damage, depletion, dedup, recovery, spawn, teardown passed |
| Delivered graphics fixture | 960×640 and 1280×720 passed |
| Unmodified independent review fixture | **287 assertions passed at 960×640 and 1280×800** |
| Independent defect observation, normal order | **17 observations, 1 visible shell, 1 material** |
| Independent defect observation, reversed order | **17 observations, 1 visible shell, 1 material** |

New tests exercise Low **and** High above capacity, both source orders, excluded
local/dead/seated/camera-adjacent/behind-camera actors, priority of a farther
genuine shield over nearer armor, equal-distance numeric-ID ties, bounded
observation overflow, slot-starved damage/depletion/recovery/respawn, duplicate
events, repeated slot acquisition, camera movement, and source nonmutation.
They verify stable node IDs during slot reassignment, no manufactured transitions
after recycling, and actual instance-ID/material death on reset and quality
downsizing. Shrinking 32 shell nodes to Low frees exactly 16 nodes/registrations
while retaining all 48 test observations.

The original 83-check fixture's material independence check now requires 15
distinct remote materials plus an empty local slot, rather than allocating a
sixteenth hidden local material. All existing behavioral assertions remain.

### Independent evidence is preserved

The historical review script, oracle, README, images and expectations were used
read-only. Its characterization records both orders as observations rather than
failing on the original defect. The owned runner adds explicit positive checks
that **both** observations now show one material, one shell, and 17 histories.
It writes new output only under `port/native-combat-shields/evidence/`.

- [Fixed 1280×800 comparison — both sides now have the shell](evidence/capacity-fix/1790080248532/independent-1280x800/shield-order-defect-left-starved-right-reversed.png)
- [Fixed 960×640 comparison](evidence/capacity-fix/1790080248532/independent-960x640/shield-order-defect-left-starved-right-reversed.png)
- [1280 positive allocation assertions](evidence/capacity-fix/1790080248532/independent-1280x800/allocation-fixed.json)
- [960 positive allocation assertions](evidence/capacity-fix/1790080248532/independent-960x640/allocation-fixed.json)
- [1280 independent report: 287 checks, no failures](evidence/capacity-fix/1790080248532/independent-1280x800/report.json)
- [960 independent report](evidence/capacity-fix/1790080248532/independent-960x640/report.json)
- [83-check log](evidence/capacity-fix/1790080237808/delivered-headless.log)
- [170-check log](evidence/capacity-fix/1790080237808/capacity-final.log) / [measurements](evidence/capacity-fix/1790080237808/capacity-final.json)
- [Source oracle log](evidence/capacity-fix/1790080237808/live-source.log)

The comparison filename comes unchanged from the independent fixture; its
historical “left-starved” wording does not describe the fixed pixels. Both
halves were visually inspected and now show the same shield.

## Rendering measurements after the fix

Mesa llvmpipe LLVM 20.1.8, Compatibility OpenGL 4.5, pinned Godot 4.5.2.
The unchanged independent shader fixture measures:

| Size | Max framebuffer alpha | Opaque-cover changed pixels | Body mean RGB delta |
|---|---:|---:|---:|
| 960×640 | 0.40392 | **0** | 0.02226 |
| 1280×800 | 0.39608 | **0** | 0.02297 |

Delivered render checks still measure **zero local-center changed pixels** and
zero opaque-cover changes. The 16-shell software frame proxies are:

| Size | High median / p95 | Low median / p95 |
|---|---:|---:|
| 960×640 | 13.38 / 16.44 ms | 9.85 / 12.31 ms |
| 1280×720 | 14.22 / 16.97 ms | 9.68 / 12.07 ms |

These are 45-frame llvmpipe wall-clock samples with fixture actors/scene, not
hardware GPU acceptance or a reliable cross-run performance comparison.

## Re-run

```sh
node port/native-combat-shields/capacity-fix-checks.mjs
```

Optional `--headless-only` / `--graphics-only` run the two phases separately.
Each invocation creates a timestamped owned output directory. Independent
graphics reuse the retained read-only oracle. The normal delivered
`run-checks.mjs` also includes the new capacity regression.

Retained failure: the first new capacity test attempt could not infer a local
GDScript variable's type; the variable was explicitly typed and the fixture
passed. That initial parse failure remains at
`evidence/capacity-fix/1790080225786/capacity-headless.log`. The subsequent 166-check
pass is retained alongside the final 170-check pass that adds numeric-ID tie
cases. No shader, controller, or resource-leak failure occurred in the successful
full rendered re-checks.
