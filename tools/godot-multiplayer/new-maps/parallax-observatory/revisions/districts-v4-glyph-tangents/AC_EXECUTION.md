# AC executed tooling delta

Base `672f3377`; explicit exclusive grant `MOTH-BLENDER-20261004-AC`.
Historical source queue remains unchanged. No compiler, policy, native tolerance,
material gate or geometry matching change was needed.

- `stage.attempt_path` additionally accepts the explicitly granted `AC01` name.
  This was in place before build and is hashed in the packed master recipe.
- `grant_AC.py` wraps the frozen AA nonwaiting lifetime supervisor with the AC
  grant, state path and log namespace. Its inherited console release label says
  “AA”; the actual grant identity and release receipts correctly say AC.
- Generated test-only `staged.gd` adds actual PackedScene resource-path/hash
  assertions and selected-art telemetry for both variants. The approved loader
  already removes fallback art and checks 39 mesh nodes.
- Generated `capture.gd` adds explicit 39-instance/14-role assertions and records
  the existing Binder Off/Low/Full and Weather-clear restoration assertions,
  selected-art identity and Binder diagnostics. No presentation parameters,
  material fields, camera positions, tolerances or restoration checks weakened.
- `targeted_rays.gd` adds six 4 m aperture clearance and three aperture-grade
  checks on actual WorldMap authority colliders, using historical fixture points.
  This is not a repeat of the historical 13,587-capsule suite.
- Both real generated GLB sidecars retain their engine UID and are set to full
  precision / LOD off before reimport. `ensure_tangents` is not a waiver.

All engine commands ran serially under the lifetime lock with owned PID/PGID and
kernel start ticks, LP/OMP threads one; Blender `-t 1 --python-exit-code 70` and
Godot single-threaded scene. The twelve Xvfb/Godot captures each had a 180-second
supervisor bound. All executed commands returned zero with empty owned groups.

The new master retains both original AA embedded texts and stores the expanded
recipe/compiler/policy under the new names. Build and fresh reopen both check
those full texts and all recipe source hashes. The recipe remains reproducible
from the delivered source files; helper/report additions are outside its Python
module glob. The historical source queue is not restamped as actual evidence.

Runtime scripts are delivered under `godot/tests/new_maps/parallax_glyph/AC01/`.
Exact script hashes are bound by the capture manifest and command/evidence
inventory. Actual reports, images, intermediates and release receipts are a
separate evidence commit; consult `AC_REVIEW.md` for outcomes and limits.
