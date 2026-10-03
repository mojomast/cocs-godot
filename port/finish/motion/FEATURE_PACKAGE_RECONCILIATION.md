# Feature package dependencies — source-only reconciliation

**Foundation: `a5c26f25`**, extending the initial `d5a02632` request after the
parent integrated operator naturalization (`2258c048`). All six promoted asset
receipts are reconciled atomically against this exact foundation. Later worker
changes require a separate transaction.

`featureAdvance.review.scope` is exactly:

> supporting package dependency reconciliation only; native feature checks pending

This is **not native feature acceptance**. F/H/I and earlier production evidence
remain immutable, with their original source/asset identities and limitations.
No engine, import, server, capture, benchmark, export or build ran here.

## Audit findings and inspected source changes

The original strict failure was correct: robot activation's campaign pointer
guard changed. A second declared runtime hook also changed (combined-arms demo),
as did the vehicle settings-access dependency. Operator integration subsequently
advanced two contract-pinned robot helper APIs. None changes a producer input,
recipe, master or exported asset.

Inspected supporting changes:

| Area | Change and dependency reason | Native status |
|---|---|---|
| Campaign journal | `demo.gd` adds a journal-visible pointer-capture guard. HUD preloads journal/model, which display public snapshot facts and manage focus. | Pending |
| Home and binding search | Home preloads route search; settings panel filters existing binding rows and repairs hidden-row focus. Selection remains distinct from launch. | Pending |
| Fighting feedback | Main preloads training feedback; its UI observes match snapshots/events. | Pending |
| First person | Rig preloads kick motion/rig helpers; session binding adds sprint-FOV composition/reset. New leg geometry is code-generated cosmetics, not a replaced GLB. | Pending |
| Movement presentation | Session/local-motion callers use source time/velocity; smoothing and reset paths changed. No source authority body changes are admitted. | Pending |
| Vehicle views/control signs | Chase adds bounded springs and view modes; demos/settings expose selection. Sports steer-axis signs and combined-arms diagonal handling were corrected in the parent source delivery. These input changes need native verification. | Pending |
| Operator motion | Character rig records anatomy, locomotion uses operator stride/contact logic, visual updates/reset paths change. Legacy shared robot function bodies are separately verified unchanged below. | Pending |

The inspected diffs are `f0e76bf7..d5a02632` for UI/motion/vehicles and
`d5a02632..a5c26f25` for the five operator files. This transaction edits none of
those feature implementations.

## Why package inventories grow

Previously some activation hooks were checked as individual hashes but their
script inheritance/preloads were not completely included in the package-input
inventory. A hash-only replacement would leave newly referenced feature helpers
outside the receipt.

`feature_dependencies.mjs` declares eight explicit shared-client entry roots:
Home, local settings, campaign, fighting, combined arms, sports, multiplayer
sports and the world session. Every promoted asset unit now binds that shared
client layer. The dependency walk follows literal GDScript preload/load and
quoted `extends`, scene/resource `ext_resource` paths, shader includes and the
existing static JS imports. Dynamic/runtime-selected assets remain governed by
their existing package inventories; this is not arbitrary filesystem discovery.

Across the six units, **243 distinct newly inventoried paths** are covered:
203 GDScripts, 29 shaders, one shader include, two scenes, four SVGs, two existing
landmark GLBs, one existing WAV and the new verifier module. The existing landmark
and audio/image bytes are read from the pinned foundation, not new assets.
All new feature helpers and all five operator motion files are covered. Existing
source-operator dependencies are also pinned, so future operator edits fail
closure instead of being silently admitted.

Exact per-unit added hashes and changed before/after hashes are recorded in
[feature-package-audit.json](feature-package-audit.json) and each receipt's
`featureAdvance`. No old package input is dropped.

| Unit | Inputs before → after | Added |
|---|---:|---:|
| Parallax | 64 → 293 | 229 |
| Robots | 134 → 371 | 237 |
| Vehicles | 204 → 441 | 237 |
| Scenery | 392 → 622 | 230 |
| Vesper | 144 → 386 | 242 |
| Abyssal | 129 → 370 | 241 |

All six existing inventories change the shared verifier hash. Robots additionally
change the two shared operator helper hashes; vehicles additionally change
`ui/settings_access.gd`. Other reviewed feature sources are newly inventoried
dependencies rather than previously bound package-input hashes.

## Exact declared runtime-hook advances

Only these declared activation hooks change:

| Unit / hook | Before | After |
|---|---|---|
| Robots: `godot/campaign/demo.gd` | `7fab4d8128cb0b0343bcd64f9c9f776c01cf14cd38cd511da8db5c4192ecc34e` | `cd90b6be02614af02f01b145ffbb9ee419b60a9612e3520029963a60b6414a43` |
| Vehicles: `godot/combined_arms/demo.gd` | `5d71ec6912052cdfb4d35a69b333efb6dfba981615ef76948186da0f4feec9b0` | `80a773cc40f0497e0ed41f5d0da89e2476b2b0fdfc022a165e71941bf873e78f` |

The verifier pins the exact per-unit allowed before/after maps. Arbitrary hook
history, stale current hooks or a forged native-passed review cannot pass.
Parallax's native→Vesper→Abyssal runtime history remains unchanged and validated.

## Robot helper API advance without producer restamping

The robot producer `sourceHashes` contain recipe, builder, shared finisher and the
contract JSON. **None changes.** The original contract's `source` hashes continue
to name the old D-era runtime helpers. The contract itself is byte-identical.
A separate, narrowly pinned `sharedRuntimeChanged` record authorizes current
supporting helper bytes, never a new D production/native fingerprint:

| Helper | Original contract hash | Reviewed current hash |
|---|---|---|
| `motion_math.gd` | `ef5133895e42a7b5e60e80bfc5e09da021566ab1e40ae12eee523d4c46d8b633` | `967f5f5167f4eac4b7b24212be058c149bb751c45450c1c2628cb42b24a8d069` |
| `ground_contact.gd` | `566f0b43f3430593eff3e6a35a9841a4ed3a67e00b202c3153f5fab75fb5b4fd` | `f3aa53909b7fabbcca396d19b7a1704cdf9e0279f368afdd8722fc8a38817bd9` |

All old executable function bodies are compared: Motion `spring`, `smooth`,
`contact`, `two_link`, and Ground `offset`. Normalization removes blank/comment-only
lines and trailing whitespace, preserving signatures, executable tokens and
indentation. Their hashes match old committed code; the offset change is only a
comment. New `stride_contact`, `gait` and `sample` are operator additions. This is
textual code-equivalence evidence, not an engine/semantic runtime test.

All nine operator GLBs are byte-identical to `f0e76bf7`. The transaction also
checks every promoted master/export and producer-source hash, and refuses changes.
`game/`, `server/`, derived authority and Helix broadphase files are unchanged
between `f0e76bf7` and this foundation. The prior Helix optimization remains a
separate historical runtime change; no old H/F native proof is relabeled as its
acceptance.

## New receipt identities

| Unit | SHA-256 |
|---|---|
| Parallax | `29eacddde07db3d080a928226743fad0d6687c9705f7773b3075cb61622e74d9` |
| Robots | `1066c4d887e6458bd294fec1f993413b47fe4efa5049ae35a045aef29f7e9ecb` |
| Vehicles | `b04bf14397de79dc319f6d47d3d0f2249386df6e817c0d41d5131e1896597e7c` |
| Scenery | `bfa8bad7c63c052f32e0daa2316cd75d0082c2f786ec625b2e97d05d64685a1d` |
| Vesper | `a67b1e62a97e1b463b48891422bf28dad7e48f86b9c020974f6772e79574ad9d` |
| Abyssal | `52d735bb4a5cd01e7f9c7ae6c307aa52c161a7baae69d59fc493546b97321075` |

All old receipt fields except current package inputs and the two declared runtime
hooks are preserved, including F/H/I advances, original native records and
`accepted:false`. Each feature advance binds the exact previous receipt from
`a5c26f25`, previous/new package fingerprints and pending native scope.

## Verification and release boundary

26 targeted source tests passed: actual closure, missing new helpers, stale/forged
hook history, altered import policies, malformed receipts, original asset identity
preservation and shared legacy function checks. The independent committed-Git test
validates all six promotions after commit. Reproduce with:

```sh
node --test tools/godot-package/feature_dependencies.test.mjs tools/godot-package/abyssal_imports.test.mjs tools/godot-package/vesper_imports.test.mjs tools/godot-package/scenery_imports.test.mjs tools/godot-package/production_resources.test.mjs tools/godot-package/build_channel.test.mjs
node --test tools/godot-package/promoted_assets_git.test.mjs
```

Future preview package state stays **six promoted / Stormglass pending**; default
final still requires all seven. Asset promotion does not discharge the new feature
native gates. Future release notes must identify these features as **native pending**
until the parent completes post-J checks. No published `cb6e4c9f` archive/metadata,
CI/final-matrix file or native evidence was edited. Stormglass J is untouched.
