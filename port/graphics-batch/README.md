# Native graphics development batch

Owner requested parallel implementation, then expanded scope to multiple new
maps, Moth scenery, shaders and massive-particle experiments, with autonomous
overnight continuation. All development lanes are integrated; release verification
is in progress.

## Integrated first wave

Runtime composition at `a0db160`:

- All 101 exact baked Moth texture planes, bounded registry and native surface
  materials; original support triangles grouped by their material identity.
- Nine-map Compatibility atmosphere and texture-aware world materials.
- Ten source-derived first-person weapon GLBs, isolated rendering viewport,
  procedural hands, source-event recoil and authoritative reload presentation.
- Public-event Moth effects attached to existing combat feedback. The public
  actor array is read-only; boundary cleanup replaces its reference.
- Native-only exploration controller for the additional showcase maps. Existing
  combat scenes retain Node movement and gameplay authority.

`port/reports/verification.json`: **96 gates passed** after repairing detached
session initialization. `evidence/aggregate-first-failure/` retains the failure;
`evidence/integration-preflight/` retains an earlier indentation/import error.
The walker fixture's original exact floating-point comparison also failed; the
bounded-angle assertion now uses approximate equality, without runtime changes.

## Graphical and live evidence

`capture.py` records exact static overview/spawn camera pairs for all nine maps
at 960×640 and 1280×800. These are renderer fixtures, not gameplay runs.

- `evidence/baseline/`: original world appearance, 36 images and hashes.
- `evidence/textures-only/`: intermediate Moth material integration.
- `evidence/integrated-world/`: Moth materials plus atmosphere and corrected
  Compatibility vertex-color handling. Ember floors/roof undersides are readable;
  Tidal snow remains bright, with visible pattern detail.

The lead directly inspected integrated Ember 1280×800, Tidal/Sunscar/Asterion
960×640 and both centered live Meridian captures. Lane-level image reviews and
their exact scope remain in the individual handoffs. All captures here use Linux
OpenGL Compatibility/llvmpipe, not Windows graphics or hardware performance.

`live.py` stages a private project and launches an unchanged normal-rate Node
authority on its own loopback port. Test automation sends ordinary protocol input;
it never inserts simulation state. Each run reaches natural results and restarts:

| Run | Snapshots | Movement transitions | Public events | Starts |
|---|---:|---:|---:|---:|
| `live-meridian` | 1862 | 1512 | 5352 | 2 |
| `live-meridian-centered` | 1862 | 1810 | 5893 | 2 |
| `live-verdant-reliquary` | 1861 | 48 | 6038 | 2 |
| `live-ember-crucible` | 1863 | 1785 | 5836 | 2 |
| `live-final-scenery` | 1862 | 1820 | 4598 | 2 |

The first automated path wandered outside useful map framing. The second uses
ordinary steering toward the arena centre; both image pairs and full compressed
snapshot/event evidence are retained. These runs observed weapon0 only. Other
weapon switching/reload acceptance comes from `port/native-first-person/`, not
an invented claim about the shared live run. Full FX correlation, all mode-specific
graphics lifecycles and new maps/labs remain under integration review.

The lead also directly inspected both sizes of the fresh Verdant/Ember captures.
Verdant's simple centre-seeking test steering reached a solid wall and stayed
there, so its 48 movement transitions are startup/movement coverage, not a map
traversal claim. Wall contact did not clip the isolated first-person rig. Ember
retained readable dark-map surfaces and HUD. All four shared runs observed only
the Pulse Rifle; do not infer all-weapon live coverage from their event counts.
The fifth run adds final production scenery composition; both screenshots were
directly inspected, with readable HUD/weapon framing and clean results/restart.

## Integrated expanded delivery

See `port/handoffs/ACTIVE_LANES.md` for exclusive ownership and branches:
Prism Foundry showcase, Aurora Basin, Cinder Array, massive particle laboratory,
Moth shader laboratory, existing-map Moth scenery, standalone launcher routes,
and independent shared-runtime review.

The new maps are additive native exploration scenes. The five native-only
routes do not create Node authorities or broaden the locked nine-map catalog.
Massive particle counts are explicit experiment settings with measured backend,
instance counts and frame-time results; normal combat defaults stay bounded.

## Release verification

The expanded aggregate passes **105 gates**, including production-controller
Aurora/Cinder traversals and combined-arms graphics. The final Windows rebuild
is 70,569,679 bytes, SHA256
`75fed1879787f39861486e9f28e427a982c60fe87718a1cf8254a3df2ec54563`.
Its exact PCK passed all-resource inspection and startup of all five native scenes
under the Linux release runtime. All 603 recorded build inputs match committed
source. Build-port provenance remains `f812c23`; the later evidence commit includes
the documentation/verification inputs that were pending at build time.

Actual Windows run [35714103892](https://github.com/mojomast/cocs-godot/actions/runs/35714103892)
passed against this exact ZIP extracted into a path containing spaces: 120
manifest files, bundled runtime versions, three combat maps, five authority-free
graphics routes, preview, graphics resources and process/listener cleanup. This
is native Windows **headless** execution, not graphical/audio/human acceptance.
Evidence is in `evidence/windows-native-verification/`.

The first hosted Linux run failed because the exporter test hard-coded the local
`/tmp/opencode` directory. It now uses Node's configured `tmpdir()`; a fresh-directory
test passes, and the hosted aggregate is being rerun. No packaged runtime bytes
changed. The original hosted failure is retained in `evidence/hosted-first-failure/`.

First intermediate Windows export succeeded; exact PCK was inspected with the
pinned **Linux release template** from an unrelated working directory. It resolved
all 101 Moth planes, ten weapon GLBs, nine maps and nine source scenes, with no
test/probe resources shipped. This is resource/export acceptance, not native
Windows graphics acceptance. Build provenance is retained in
`evidence/windows-first-export/`; the archive is not the final expanded-map demo.

Independent shared-runtime review found no P0/P1 issue. It identified missing
combined-arms infantry composition and a possible inherited terrain depth-priority
sign issue; both are delegated for bounded implementation/verification. Its stale
VFX documentation example now releases the public-actor reference without mutation.

Combined-arms graphics follow-up integrated as `87ea91f`: dismounted infantry now
uses the rig directly, mounted views hide it, and public combat feedback follows
the composition's lease/focus/connection policy. Its 65-check composition fixture,
43 existing controls checks and 68-check graphical fixture passed. Those tests
use synthetic decoded state and focus/capture values; live combined-arms graphics
and exported-package checks are still separate acceptance steps.

Depth follow-up `fecc5f0` proved the inherited priority sign was reversed on the
pinned Compatibility renderer. The one-character correction passes 24/24 real
raster cases and 1944/1944 measured high-priority pixels at both sizes, two draw
orders, two slopes and three distances. Before failures and draw-order controls
remain in `port/native-graphics-depth/`. This does not claim an observed overlap
failure in the nine maps or verification on other hardware/backends.

Campaign remains deferred. The external pulse-rifle preview reservation and the
user's untracked procedural-model research remain preserved.

## New-map and laboratory acceptance

- **Prism Foundry:** reactor atrium, turbine hall, coolant garden and deck, with
  a raised circulation loop. The delivered 49-check physics/input fixture was
  rerun successfully with its documented graphical Xvfb harness in
  `port/native-showcase/evidence/run-eknqse33/`.
- **Aurora Basin:** landing, fractured frozen lake and Crown observatory, linked
  by a lake circuit and raised skywalk. The complete map traversal now runs with
  the production shared walker's `step()` and passes, replacing the lane's private
  baseline-compatible controller. Production fallback-to-test code was removed.
- **Cinder Array:** volcanic six-area loop. Full production traversal exposed an
  upper-junction snag; `f812c23` merges overlapping ramp/landing collision solids.
  Both directions now reach all 16 waypoints with zero off-floor frames and zero
  controller resets. All 1,246 assertions pass with production physics, including
  342 floor probes and rail/tunnel/boundary checks. Collision shapes decrease
  103 → 99. Failed JSON/log and collision-contact evidence remain preserved in
  `evidence/expanded-preflight/` and `port/native-cinder-integration/`.
- **Moth Shader Gallery:** three materials, 68 contracts and native visual probes.
  The integrated native launcher and three-material headless smoke pass.
- **Particle Observatory:** 183 contracts, actual stateful GPU simulation on
  Compatibility and a distinct analytic MultiMesh backend. All 13 lane render
  sweeps passed; selectable counts reach 1,048,576, with stable return-to-32K cycles.
- **Existing maps:** bounded Moth scenery is now composed by the production
  viewer. F8 cycles Full/Off/Low without popups; source geometry stays unchanged.
  All 36 final static captures are in `evidence/scenery-integrated-world/`.

Independent review `e5d6fd3` passed **58/58 actual-X11 checks** and directly
inspected 18 images. OS-level synthetic keyboard/mouse input exercised the real
production scenes/controllers, focus loss with movement held, recapture, 128K
particle controls, shader controls and three unload cycles. No orphan accumulation
or increasing final-pair resource counts was observed. See
`port/native-graphics-independent/REPORT.md` for exact bounds; this is short
native Linux desktop acceptance, not hardware timing or full-map traversal.

The particle lane's 1280×800 galaxy measurements on llvmpipe were:

| Actual GPU amount | Median | p95 |
|---:|---:|---:|
| 8,192 | 6.86 ms | 9.12 ms |
| 32,768 | 18.36 ms | 25.24 ms |
| 131,072 | 57.28 ms | 62.13 ms |
| 524,288 | 211.34 ms | 219.69 ms |
| 1,048,576 | 462.04 ms | 476.69 ms |

The million-particle case submitted 2,097,152 particle triangles. It is an explicit
stress setting, not a playable software-renderer default or hardware-GPU promise.

### Integration failures preserved

- Scenery ownership fixture assumed the production viewer did not already own a
  scenery root. It now verifies production composition, clears that layer, then
  establishes its original-geometry baseline for create/clear assertions.
- The Windows entry was expanded from a default-launch shortcut into a five-choice
  menu. An implementation-mirroring source regex failed; batch forwarding is now
  verified by executing the actual `.cmd` on Windows, rather than matching layout.
- A lead headless invocation of Prism's graphical physics fixture timed out. The
  documented Xvfb invocation passed; aggregate startup and graphical traversal are
  recorded with their correct distinct scopes.
- Relocating a completed build-state tree to disk made its old symlink fail the
  builder's dedicated `/tmp/opencode` check. The next build uses a new owned state
  directory; the build-path validation remains intact.
