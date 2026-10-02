# Switchyard acceptance / handoff

**READY FOR BLENDER — awaiting explicit heavy-slot grant.**

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
