# Switchyard acceptance / handoff

**PRODUCED AND NATIVE-VERIFIED under grant D; parent review/promotion pending.**

## Grant-D production results (2026-10-02)

Merged canonical `b66f4ab3` as `8054b90b`, resolving the one builder add/add conflict
in favor of the consolidated Moth finish and exact serialized recipe output.
Actual Blender **4.5.14** and Godot **4.5.2** ran only through the nonwaiting,
bounded `tools/asset-production/run.py --unit robots --stage ... --granted` wrapper,
with `LP_NUM_THREADS=1`. Source authority and other units remained untouched.

Delivered real inventory:
- 3 self-contained runtime skin GLBs, each containing three articulated LOD bands;
- 6 support-prop GLBs, each one surface;
- 9 editable `.blend` masters outside Godot, plus 3 skeletal reference GLBs with
  idle/walk/attack/react/death clips;
- exact `tools/godot-robots/generated/recipe.json` bytes matching builder hash;
- `tools/godot-package/production_receipts/robots.json`: exact 100 package inputs,
  all masters/exports/embedded images and six actual runtime hooks, `accepted:false`.
  **No package promotion flag was set.**

Final source fingerprint:
`3e6deae571e2aa3b7fe22725775b11ea37f04ef5f68acedf45df2fa8cea68190`.
Runtime GLBs total **6,382,544 bytes**; nine masters total **13,132,973 bytes**.
Actual aggregate runtime geometry **75,056 triangles**, below the 102,000 cap.

| Skin | LOD0 triangles/draws | LOD1 | LOD2 |
|---|---:|---:|---:|
| Needle Surveyor | 9,776 / 8 | 5,384 / 8 | 3,192 / 6 |
| Caisson Guard | 10,164 / 9 | 5,772 / 9 | 3,580 / 7 |
| Kiln Tender | 13,112 / 12 | 8,288 / 12 | 4,776 / 8 |

Six props: 1,636 / 2,184 / 2,176 / 1,636 / 1,636 / 1,744 triangles respectively
(console, dock, rack, frame, cargo, junction), one draw each. Six native mounts,
no new collider, deterministic rebuild/teardown. These are measured mesh costs,
not hardware frame-time claims.

### Final stage evidence

All paths below are under
`/home/mojo/.tmp-on-disk/cocs-expansion-three-robots-evidence-20261002/production-d/`:

| Stage | Directory | Actual result |
|---|---|---|
| Build | `20261002T230718.239830Z` | all 9 runtime / 9 master / 3 reference outputs |
| Original reopen | `20261002T230728.406763Z` | all three masters + imported skeletal references, weights/clips |
| Generic reopen | `20261002T230733.650977Z` | all nine masters and nine runtime imports, UV/finish/fingerprint |
| Original receipt | `20261002T230741.365446Z` | exact GLB hashes and all LOD/prop budgets |
| Godot import | `20261002T230746.329863Z` | clean import |
| Native/lifecycle | `20261002T230755.229319Z` | **60,593 checks**, zero failures; stock/skin/identity/death/reset/factories/mounts |
| High gallery | `20261002T230801.835440Z` | anatomy front/rear/underside, all LODs, 12/22/48m, props and animation |
| Compact/UI150 | `20261002T231344.625768Z` | real LocalSettings 150%, 760x520, shadow-disabled gallery |
| Physics contacts | `20261002T230855.613635Z` | 4,320 joint comparisons, 12,792 imported sample points |
| Source targeting | `20261002T231001.062837Z` | 51,168 Campaign + 86,016 Horde four-side damage probes |
| Production session | `20261002T231013.811011Z` | three 72-frame source-authority replays through actual Campaign composition |
| Contact sheets/VFR | `20261002T231436.880071Z` | six contact sheets + native captured-cadence MP4 |
| Generic receipt | `20261002T231512.033428Z` | real exact inventory/fingerprint; report path in stage log |
| Package receipt | `20261002T231534.273214Z` | fixed package receipt with actual hashed activation hooks |

The generic receipt resides at
`/home/mojo/.tmp-on-disk/cocs-expansion-four-scenery-evidence-20261002/consolidation/receipts/2026-10-02T23-15-12.277Z/robots.json`.

Inspected all three roles close/front/back/underside; open gun bores, tapered
plates, ceramic knees and distinct shield/bipod/quadruped silhouettes; all three
LOD transitions and combat distances; all six props and all six existing-cover
mounts. Native status optics retain source emission changes. Geometry normals
remain appropriate to coating; no blanket normal texture was introduced.

Production-session capture is **controlled offline production-authority replay**:
real CampaignMatch and validated FIFO inputs, source snapshots/events, actual
Campaign factory/materials/world/render lifecycle, composed camera and stopped
AI. Skirmisher sequence: 16 damage events / 3 deaths; bulwark: 1 damage event;
mortar: 1 telegraph / 1 damage event. Six workshop mounts exist in each session.
This is not a hosted ordinary-input journey or human-feel evidence.

Native animation clip: `20261002T231436.880071Z/native-animation-captured-cadence.mp4`.
120 actual captures span **21.637081s**, mean **5.4998 capture FPS**, intervals
.147583–.238447s; VFR encode uses capture-completion timestamps. Renderer is
**llvmpipe**, so these numbers include screenshot overhead and establish neither
hardware/GPU performance nor human feel. Reference authored clips remain editable;
runtime animation uses the original native contact/event pipeline.

### Failures retained and corrected

- Blender glTF import added an Icosphere bone-display object; reopen validation
  now excludes only actual bone custom-shape objects and accepts importer rigid
  bone-parent optimization while checking real skeleton/weights/clips.
- Initial native probe ran during SceneTree initialization and emitted transform
  errors despite exit 0. Deferred setup fixed it; runner now rejects error logs.
- Native factory probe cleanup touched a freed Node and initially called Horde's
  differently named factory. Both fixtures corrected; bounded timeouts preserved.
- Material override masked imported detail; adapter now carries the Moth texture
  into the live armor/optic/shield overrides. Primitive UVs were removed so the
  sole component-local UV stream cannot be misbound.
- Blender material-based export emitted a white placeholder COLOR_0. Named `Col`
  export corrected it. Actual native palette checks now reject white placeholders.
- Art review added tapered armour pressings, real hollow barrels, turntable
  bearings, toe cleats and prop service details. Corresponding assets/masters and
  all receipt fingerprints were rebuilt, not relabeled.
- Studio shadow acne corrected in the gallery floor/lighting. Actual Campaign
  lighting is independently visible in production-session captures.
- Production replay called `hide` on a Node-only first-person binding; corrected
  to its real rig API. Review helper lacked system Pillow; bounded `uv --with
  pillow` supplies the image-sheet dependency. Failed logs remain in evidence.

### Source regression and remaining parent gates

Final source unit/control suite **17/17 passed**, plus Campaign actual-sample
targeting **8/8**, Moth helper **5/5**, recipe-byte serialization **1/1**;
`git diff --check` passed. Shared hook diff is isolated for parent review.

Remaining: parent inspect/promote the committed package receipt, reconcile shared
runtime hooks with other lanes, run the final ordinary-input/native release
matrix and Windows package checks under a separate grant. No Windows export,
promotion, new AI ability or authority edit occurred in this unit. Full-depth
free-standing prop placement is not installed; production deliberately uses
shallow existing-cover service mounts with unchanged source collision.

## Historical source-only checkpoint (superseded by production above)

## Source gates

- `node --test godot/tests/robot_assets/contracts.test.mjs`: **6/6 passed**.
- Python AST parse of `tools/godot-robots/*.py`: **3 files passed**; syntax only,
  no bpy execution. `git diff --check` passed.
- Existing campaign hit-volume/targeting and Horde role tests: **15/15 passed**.
  Campaign targeting reused existing baseline triangle samples (11,952 checks);
  this does not constitute samples of these unbuilt skins.
- Horde authority suite initially could not resolve `ws` in this worktree.
  Reused parent `node_modules` via local ignored symlink per BRIEF, then reran
  only the blocked suite: **4/4 passed**. Total successful source tests: **25**.
- Earlier shield-volume failure identified the source recipe rear grip exceeding
  depth; corrected that geometry before the final 6/6 source gate.
- Node recipe checks cover deterministic seed, finite source geometry, full LOD
  assembly coverage, exact contact profiles/source hashes, negative bounds
  mutation, floor contact, source eye/forward/muzzle and snapshot preservation.

## Grant-stage commands (NOT RUN)

Use Blender path from BRIEF after checking existence, `LP_NUM_THREADS=1`, `-t 1`.

1. `blender -b -t 1 --python tools/godot-robots/build.py`
2. Separate reopen: `blender -b -t 1 --python tools/godot-robots/verify_blender.py`
3. `node godot/tests/robot_assets/verify_receipt.mjs` requires nine real GLBs,
   exported-byte hashes, mesh attributes, finite bounds and measured budgets.
4. Pinned Godot 4.5.2 import then
   `--headless --path godot --script res://tests/robot_assets/native_contract.gd`.
   GDScript parsing is not claimed before this engine gate.

## Remaining acceptance

- Blender API/export-option verification, separate master and GLB reopen,
  finite normalized rigid weights, actual clips, normals and material review.
- Native imported chassis/sensor animated bounds vs unchanged campaign contact
  shapes at scale/yaw/pitch, tolerant source-target ray comparisons, original vs
  each skin before/after control. Horde scales need separate native review.
- Native ground foot plants (flat/slope/step/strafe), idle/walk/attack/react/death,
  attack arcs, shield exposure/hits, corpse teardown, weapon source-origin parity.
- Contact sheet per skin: front/rear/underside/side and five animation phases.
  Record actual native clip cadence with frame timestamps, not just still images.
- Low/high-quality combat captures at 1280x800 and 760x520/UI150, three silhouettes
  at combat distance; revise geometry if massing, bevels or detail read poorly.
- Six prop open-clearance checks and optional existing-geometry installation;
  real instancing/material/draw/triangle measurements in representative scenes.
- Parent-reviewed minimal factory hook and local selection UI, if approved, as
  a separate shared commit coordinated with Horde owner. Currently helper only.
- Parent owns permanent registries, packaging and release closure. No human-feel,
  GPU-performance, exported-asset or player-visible-installation claim yet.

Evidence destination after grant:
`/home/mojo/.tmp-on-disk/cocs-expansion-three-robots-evidence-20261002/`.
No Blender, Godot, render, import, bake or export process has been started.
