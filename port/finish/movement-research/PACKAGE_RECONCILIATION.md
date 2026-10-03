# Movement candidate — exact seven-unit package reconciliation

Reviewed foundation: **`f61f6156d9575d8dcf44ca4daf7a09bef727b034`**.
Adopted in the isolated `expansion-four/scenery` worktree as merge `b6b43d2f`.
The only merge conflict was the O report's parent-verification paragraph, retained
in full. Previous package advance: parent **`14d8a72d`**, worker `76591715`.

This transaction covers implementation `91f58a1c`, generated-source closure
`9d95623d`, and source gate registration `54fc78ef`. It is source-only package
dependency reconciliation, **not native movement acceptance**.

## Exact reviewed runtime and supporting sources

`tools/godot-package/movement_f61_inventory.json` contains every before/after
SHA-256 for these eleven changed sources, plus the newly added candidate contract.
Its immutable SHA-256 is
`532faf2b9fa92b674f06a4485615e5405a73666fd43893f31baedccee9f6712d`.
Both endpoints are checked against committed Git objects (`14d8a72d` and the
exact reviewed foundation), and current bytes must match the latter.

| Source | Reviewed role |
|---|---|
| `game/core.mjs` | Acceleration budget, air tuning, landing slide buffer/reset |
| `game/operator-verbs.mjs` | Exact operator dependency; multiplier comments updated |
| `game/feedback.mjs` | Web slide cue and suppression/reset |
| `game/weapon-ads.mjs` | Slide pose fades to zero at ADS cheek weld |
| `godot/first_person/rig.gd` | Native weapon-only slide cue and reset |
| `godot/native_arenas/client.gd` | Applied/cancelled sequence backpressure |
| `godot/campaign/client.gd` | Inherits shared window rather than duplicating it |
| `godot/horde/client.gd` | Bounded input window, epoch checks, inactive cancellation |
| `godot/horde/demo.gd` | Retains pulses on busy; one cancellation per inactive epoch |
| `port/native-campaign/generate-core.mjs` | Exact new core and operator pins |
| `port/native-campaign/core.generated.mjs` | Reviewed generated campaign consumer |

Key source pins:

| File | Current SHA-256 |
|---|---|
| `game/core.mjs` | `655f112934b7b4a4f1d9f043a8c545511e7284f557e4c9586dfd72d3e5a8e7a3` |
| `game/operator-verbs.mjs` | `357b7b2174f6f280c3cf386612d886a725c772ca2c14bb66ecce3b6e32024a6e` |
| `port/native-campaign/generate-core.mjs` | `cc7eb3e0e49faccfdbe66511a04ac9541fdd21692541d9da29a1aaa747482655` |
| `port/native-campaign/core.generated.mjs` | `949e8a599d0bea5773e35043fefdc1d58d38a3f0ea678ad76f76ba5e47e78abb` |
| `port/contracts/movement-candidate-derivative.json` | `b775686e10f21d54150f37a231690d9d24a2da15f8ed775001acc2328b63f830` |

`package-audit.json` records **every** per-unit changed/added path and full hash,
including verifier changes and unchanged transitive source additions. The larger
Parallax/vehicle/Stormglass additions are the actual source import graph newly
reached by the core/generator/web/Horde roots, not additional production assets.
The generator's single literal output-template placeholder is explicitly excluded
from static import traversal; its concrete generated module is a required root.
All other literal import path validation remains strict.

## Receipt history and reuse decision

Each receipt appends `movementAdvance`: exact previous receipt path/hash,
foundation, changed and added inputs, reviewed source snapshot, old/new package
fingerprints, explicit consumer hook mapping and native-pending status.
Reversing that delta must reproduce the **entire original O receipt byte hash**.
This preserves even unknown producer fields, all historical pending/acceptance
fields, native identities, fingerprints, masters, exports, and F/H/I/J/K/L/O
review records. The historical polish-to-L assertions are retained; only the
exact subsequent movement predecessor is accepted for current-source checking.

Robots are the one hook exception: original `runtimeHooks[godot/horde/demo.gd]`
is retained as `c010585a309910a781f5dd0d87013e5fbd4bac927774c6b60ba03c444b3b7951`.
The new consumer mapping explicitly requires
`5c03c0aca831d1af8d9c4f00cca3a462308125f6dbd42dd7ea1687e70bd29a1a`.
The historical robot contract's core/operator identities likewise stay original;
current supporting reads follow the exact movement mapping. This records reuse,
not a claim that the original native run used the new movement code.

**Reuse is eligible for the existing production assets:** builder/recipe/finish
fingerprints, masters, embedded textures, nine robot GLBs, vehicle GLBs, scenery
and map exports, and their import policies remain unchanged and are checked by
strict inventory. No fresh asset production or re-stamping is justified by these
consumer-only changes. Fresh affected-route native validation remains required.
No new Moth pack is adopted; its pending multi-engine resource comparison remains
separate. Historical assets using the existing finish helper retain that identity.

## Seven-unit audit

| Unit | Previous → current inputs | Changed | Added | Receipt SHA-256 |
|---|---:|---:|---:|---|
| Parallax | 558 → 649 | 5 | 91 | `878e2d50b925c8c244123b0daecb2633e108408a7ef680763757bdc03c79cffd` |
| Robots | 636 → 657 | 8 | 21 | `916447aae9bdad991eca23d2a49af5efa8fa41f362c1b78105a7f47c7085014e` |
| Vehicles | 706 → 798 | 5 | 92 | `61186601f9122bd8d4574f3c6eb208d60f5a28fa6d5ace7b5c9a9a170171d3c6` |
| Scenery | 887 → 909 | 7 | 22 | `7e562ee52f8e113ebfd1e76313ba851b473bdf709722739703a7ec39b9313277` |
| Vesper | 651 → 673 | 7 | 22 | `f9397479fba266a0ae072501c2ec4e18942dd4a89a9c493146c62f7c2c6e9f6b` |
| Abyssal | 635 → 657 | 7 | 22 | `79b84e312ffbc7fd8bf697d0f1bed42c83d077b66265a1919c66cc502297ac72` |
| Stormglass | 576 → 667 | 5 | 91 | `639bdee2adab5ffda5a3c33ab3b69675433f19bc8aade42681224e9793ecce85` |

## Package source preflight

The explicit `--source-derivative` path and Windows source preflight now select
the exact movement overlay, whose implementation ancestor remains **`91f58a1c`**.
The resolver validates the pinned contract bytes, historical parent bytes,
baseline/candidate ancestry and all before/after runtime hashes. The resolved
13-file source inventory drives build source verification and copying. Both
contracts and the resolver are package inputs. Campaign generation checks the
new core/operator hashes and the actual generated output.

Recorded-artifact validation selects the contract using the artifact's explicit
derivative identity, never ambient HEAD. Old lattice-contract artifacts retain
their historical selection. Current recorded source bytes must also match the
resolved derivative hashes, preventing old-source substitution at a newer port
commit. Tests cover old-artifact isolation as well as the movement source path.
No Windows host run or package build is claimed here.

## Executed lightweight verification

The source suites below cover **112 distinct tests**. The initial combined run
passed 111/112: an older synthetic test expected an unreviewed raw-reader policy
change to be accepted. It now asserts rejection under full predecessor binding;
the affected four-test file rerun passed 4/4. All 112 distinct tests are passing.

```sh
node --test tools/godot-package/movement_dependencies.test.mjs tools/godot-package/source_state_windows.test.mjs tools/godot-package/manifest_validation.test.mjs tools/godot-package/polish_dependencies.test.mjs tools/godot-package/stormglass_imports.test.mjs tools/godot-package/feature_dependencies.test.mjs tools/godot-package/abyssal_imports.test.mjs tools/godot-package/vesper_imports.test.mjs tools/godot-package/scenery_imports.test.mjs tools/godot-package/production_resources.test.mjs tools/godot-package/build_channel.test.mjs tools/asset-production/candidate-contract.test.mjs tests/new_maps/abyssal_pressureworks/admission.test.mjs port/native-campaign/core-provenance.test.mjs port/native-campaign/movement-parity.test.mjs port/native-campaign/hit-volume.test.mjs
node --test tools/godot-package/production_resources.test.mjs
node --test tools/godot-package/promoted_assets_git.test.mjs
node tools/port/lattice/source-oracle.mjs
```

The independent committed-Git test is run after committing and checks all seven
strict inventories, predecessor hashes and exact deltas using committed bytes.
The generator's `--check` ran within the movement suite. The lattice oracle
passed 47 captions, 4 progress cases, 13 recovery cases and 13 runtime hashes.
Python AST parsing validated `build.py` syntax without executing it.

Negative coverage includes every unit's missing advance, forged predecessor,
unknown producer field, stale core pin and fabricated native pass; all eleven
changed sources reject future bytes. Forged overlay hashes/ancestry/parent
contracts, re-stamped robot hooks and changed earlier source history also reject.

## Remaining acceptance

Q (`MOVEMENT-NATIVE-20261003-Q`, owner `ses_f0292f089ffeq9MnxeAHN0yrKb`) retains
exclusive heavy-work ownership and its frozen `f61f6156` candidate. No Q result
has been adopted here. Any native correction needs a later exact reviewed advance.
All P 89/22/31 results and failed gates remain historical. Manual feel, audio,
GPU/performance, live-kick and final 142-case/release obligations keep their own
pending/failure evidence; inventory completeness does not discharge them.

No engine, Blender, import, server, export, capture, benchmark or child agent ran.
No parent/shared-worktree commit, asset cloning or native evidence copying occurred.
