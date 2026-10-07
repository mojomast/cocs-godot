# Remaining baseline gate failures — triage

Read-only classification of the twelve gates that were still failing at the
start of the 2026-10-07 relay-campaign campaign. Candidate under test:
`godot/main` tip `4f851220d07fa7b60aa290bdf4d9f4f60e5fcb87` in worktree
`/home/mojo/.tmp-on-disk/cocs-triage`, pinned engine
`4.5.2.stable.official.6ce3de25a`.

Method: reproduce each gate's `tools/godot-dev/verify.py` command directly
(never through the aggregate) with `GODOT_BIN`, a scratch `COCS_CAREER_ROOT`,
and a private `COCS_ATTRACT_EVIDENCE`; capture stdout to
`/tmp/opencode/triage-repro/`. Display/rendering journeys were run once and
classified from that output plus committed `port/reports/` logs and git
history. Nothing was fixed; no tracked file was modified (verified with
`git status --porcelain --untracked-files=no`).

## Classification table

| Gate (verify.py line) | Class | Root cause (strongest evidence) | Unit size | Depends on | Priority |
|---|---|---|---|---|---|
| `native-graphics-ownership` (95) | **REAL** | Dev stub in `port/native-graphics-launchers/fixtures.mjs:84` copies `launch.mjs` but not `active_source.mjs`, which `tools/godot-dev/launch.mjs:6` now imports → `ERR_MODULE_NOT_FOUND`, 19/39 tests fail | small | node only | **P1** |
| `multiplayer-world-derivatives` (232) | **REAL** | `game/core.mjs` gained `damage(...,weaponIndex=null)` at F08 `8a6e7be2`; `port/multiplayer-worlds/derived/core.mjs:904` is stale → `--check` throws `Stale derivative core` | small | node only | **P1** |
| `vehicle-shared-shot-owner` (368) | **REAL** | `presentation.gd:40` now also connects `_on_melee_events` to the shared `client.events` signal; the test asserts total connections `== 1` (`test_shared_shots.gd:22`) but the real count is 2. `session_shots.bind` is idempotent (probe: 1→2→2) | small | headless Godot | **P1** |
| `operator-detail-textures` (340) | **REAL** | `surface_detail.gd:41` keys the detail-material cache on `base.get_instance_id()`; `operator_visual.gd:128` duplicates `team_material` per actor, so twins never share (`textures.gd:38`, all 9 operators) | small | headless Godot | **P1** |
| `main-menu-live-attract` (290) | **REAL** | `demo.json` now authors **8** clips (combat is index 5) but `live_attract.gd:51,78,93,106` still hard-code the old 4-clip set; 5 checks fail | small | headless Godot (logic) | **P1** |
| `animation-world-physics` (245) | **REAL** | `attachment.gd:91-98 apply_source_pose` overwrites the turret transform for authored Puma, contradicting `renderer.gd:49` / `world_physics.gd:174` (`turret.rotation.y == 0.2`) | small–medium | headless Godot | **P1** |
| `vehicle-fleet-visuals` (367) | **REAL** (same root cause) | Same `apply_source_pose` override vs `fleet.gd:42` / `test_fleet_visuals.gd:33`; only puma/titan/scout fail because `attachment.gd:4 PIVOTS` has no hornet/transport | small–medium | headless Godot | **P1** |
| `product-shell-guest-leave` (295) | **REAL** | Guest joins, Settings/Back/Leave succeeds and the socket closes, then `launch.mjs` returns to `MENU_READY` instead of exiting; `guest_leave_journey.mjs:118` requires exit 0 | medium | Godot + display | **P2** |
| `experience-combined-arms-journey` (383) | **REAL** | In compact 760×520 (visible rect 506.67×346.67) the Respawn caption is laid out for 1280×800 (`rect P:(748,750)`, `visible:false`); `player_info.gd:349-362` hides it when no region fits (`native_journey.gd:267`) | small–medium | Godot + display | **P2** |
| `vehicle-three-native-crew` (369) | **REAL** | `run.py:42` pins the stale `lattice-catalog-derivative.json` (`derivative_commit 0326b435`); F08 changed `game/core.mjs`, so `semantic.mjs:73` rejects the derivative inventory | medium | Godot + derivative/receipt | **P2** |
| `world-weather-campaign-journey` (376) | **ENVIRONMENT** (host-timing; REAL caveat) | First W sample is cancelled and the held key is dropped on a stale reset under slow software rendering; diagnostic shows **0** applied frames with `|x|>0.1`; `mapper.gd:39` + deliberate "do not resume held controls" design | medium | Godot + display + fast host | **P3** |
| `horde-upgrade-fixture` (438) | **ENVIRONMENT** | Real-time offer/select fixture under llvmpipe: frames up to **2952 ms** (p50 58 ms), 250 ms input TTL fires → 52 `control-reset` records, offer deadline 24 s expires, `authority.applied:[]`, child SIGKILLed. Passed historically (`"ok":true` at `091b1333`, `b68d73d8`, …) | n/a (re-run) | GPU host | **P3** |

### Attribution summary

All ten REAL failures are regressions introduced between the Oct-1 passing
aggregate `091b1333` and the Oct-6 audited baseline `d8cfdede` (ancestor of the
tip), and none were caused by the relay-campaign work:

- `active_source.mjs` adoption in `launch.mjs` (no fixture update) → native-graphics-ownership.
- Authored Puma/Titan/Scout GLBs + `attachment.gd apply_source_pose` (tests not updated) → animation-world-physics, vehicle-fleet-visuals.
- `surface_detail.material_for` instance-id cache key → operator-detail-textures.
- `presentation.gd` melee listener added to the shared `client.events` signal → vehicle-shared-shot-owner.
- `demo.json` 4→8 clips (test not updated) → main-menu-live-attract.
- F08 promotion `8a6e7be2` changed `game/core.mjs`, derivative not regenerated → multiplayer-world-derivatives.
- F08 active-source default vs `run.py`'s hard-coded historical derivative → vehicle-three-native-crew.
- `guest_leave` return-to-menu vs exit contract → product-shell-guest-leave.
- Compact caption region allocation → experience-combined-arms-journey.

## Per-gate evidence

### native-graphics-ownership — REAL
Reproduced: `node --test tools/godot-package/native_showcase_ownership.test.mjs tools/godot-dev/native_showcase_ownership.test.mjs`
→ `# pass 20 / # fail 19`; every failure is
`ERR_MODULE_NOT_FOUND: .../tools/godot-dev/active_source.mjs imported from .../tools/godot-dev/launch.mjs`.
`tools/godot-dev/launch.mjs:6` imports `resolveActiveDerivative` from `./active_source.mjs`
and calls it at line 14. `port/native-graphics-launchers/fixtures.mjs:84` builds the
dev stub by copying only `launch.mjs`, `launch_options.mjs`, `endpoint.mjs`,
`settings_path.mjs`, `career_path.mjs`. The committed
`port/reports/native-graphics-ownership-repair.log` (39/39) predates the
`active_source` import (`git log -S active_source.mjs -- tools/godot-dev/launch.mjs`
→ `d8cfdede`). Note the stub also needs a synthetic
`port/contracts/active-source.json` + derivative (or a valid
`COCS_SOURCE_DERIVATIVE`), because empty `COCS_SOURCE_DERIVATIVE` takes the
active-descriptor path.

### multiplayer-world-derivatives — REAL
Reproduced: `node port/multiplayer-worlds/generate-derivative.mjs --check`
→ `Error: Stale derivative core`. Reconstructing the generator transform:
expected 180237 bytes vs committed 179313; first divergence at the F08
signature `damage(target,amount,source,ability=false,weaponIndex=null)`
(`game/core.mjs:901`) vs the stale `damage(target,amount,source,ability=false)`
(`port/multiplayer-worlds/derived/core.mjs:904`). The committed baseline
`port/reports/verification.json` (candidate `dd9b7f73`) still recorded this gate
as passing; it regressed with F08 `8a6e7be2`, which changed `game/core.mjs` and
did not regenerate `port/multiplayer-worlds/derived/core.mjs`.
Fix: run the generator (commit `93ad708c` shows regeneration is a normal,
self-contained commit); confirm no receipt cascade.

### vehicle-shared-shot-owner — REAL
Reproduced: `SHARED_VEHICLE_SHOTS failures=1` at
`test_shared_shots.gd:22` (`get_connections().size() == 1`). A direct probe of
the stub showed `client.events` already has **1** connection before any bind
(`PortPresentation::_on_melee_events`, `presentation.gd:40`) and **2** after
binding; the second `bind_vehicle_shots()` leaves it at 2. So
`session_shots.bind` (`session_shots.gd:13-20`, guard `if bound_client == client: return`)
is idempotent; the assertion measures the whole shared signal, not this handler.
`presentation.gd` gained `melee_client.connect("events",_on_melee_events)`
between `091b1333` and `d8cfdede` without updating the test.

### operator-detail-textures — REAL
Reproduced: all nine operators fail `shares detail material`
(`textures.gd:38`, `plate.material_override == twin_plate.material_override`).
`ArmorDetail.build` (`armor_detail.gd:20`) passes `team_armor` as the base for
the breastplate; `operator_visual._collect` (`operator_visual.gd:127-130`)
duplicates the team material per actor, giving each actor a distinct
`instance_id`. `surface_detail.material_for` (`surface_detail.gd:41`) now keys
its cache on `[style, base.get_instance_id(), …]`; the previous key was
`[style, base.albedo_color, base.metallic, base.roughness]`. With distinct
instance ids the clones can never be shared. The committed log passed at
`091b1333` (`"failures":[]`) and fails from `d8cfdede`; the `instance_id`
component is the regression. Fix is a product-intent decision: either share the
per-operator team material or relax the test to a value-equality invariant.

### main-menu-live-attract — REAL
Reproduced with `COCS_ATTRACT_EVIDENCE` set: `LIVE_ATTRACT checks=56 failures=5`.
`godot/ui/attract/demo.json` authors 8 clips
(`root-reveal, mara, patch, silt-reveal, ivo, silt-fire(combat), ember-reveal, crown-reveal`),
but `live_attract.gd:51` requires `stage.clips.size() == 4`, line 78 reads the
combat clip from index 3, line 93 requires a recorded shot in index 3, and lines
106-108 advance one chapter and wait for index 0. `git diff 091b1333 d8cfdede --
godot/ui/attract/demo.json` changes the clip array; `live_attract.gd` is
unchanged. All five failures are clip-set assumptions, not rendering.

### animation-world-physics / vehicle-fleet-visuals — REAL (shared root cause)
Both reproduce exactly as committed. `renderer.gd:49` and `fleet.gd:42` set
`n.turret.rotation.y = turretYaw`, then both call
`VehicleArt.apply_source_pose(n, v)` (`renderer.gd:50`, `fleet.gd:43`).
`attachment.gd:91-98` computes the turret transform from the **absolute**
`yaw + turretYaw` basis and assigns `host.turret.transform =
host.transform.affine_inverse() * source_turret`; with any non-zero host
pitch/roll the resulting local Y rotation is not `turretYaw`, so
`world_physics.gd:174` (`== 0.2`) and `test_fleet_visuals.gd:33` (`== 0.25`) fail.
The authored GLBs (`puma/titan/scout`) and `attachment.gd` were added between
`091b1333` and `d8cfdede`; the tests were not updated. Fleet's hornet/transport
pass only because `PIVOTS` (`attachment.gd:4`) omits them, so
`install()` returns false and `apply_source_pose` is a no-op. One reconciliation
fix (preserve the relative turret yaw while positioning the muzzle orbit)
addresses both gates.

### product-shell-guest-leave — REAL
After generating the semantic export (`godot/content/generated/manifest.json`,
gitignored) the gate gets much further than the committed log: the guest joins
(`GUEST_LEAVE_WAITING/READY`, `source_snapshots:32`, Settings/Back/Settings/Leave
all scripted), the guest socket closes, and then the console ends with
`MENU_READY` — the external dev launcher returned to the menu. The journey then
fails at `guest_leave_journey.mjs:118` (`exitCode null !== 0`, 10 s deadline).
`guest_leave.gd:74` presses Leave; nothing quits the launcher. The committed
baseline log failed earlier (source drift) and never reached this stage.

### experience-combined-arms-journey — REAL
Reproduced: `EXPERIENCE_NATIVE_FAIL independent caption fits actual HUD`
(`native_journey.gd:267`). The capture record is
`{"text":"Respawn","visible":false,"rect":"P:(748,750) S:(474.67,32)"}` while
the recorded viewport is `(506.67, 346.67)` — i.e. the caption is laid out for
1280×800 and is outside the compact viewport, and `player_info.layout()`
(`player_info.gd:349-362`) hides a label whose chosen region cannot fit.
Captions are proven enabled earlier in the same run. This is a compact-layout
regression from the responsive-caption work (`78ef1673`).

### vehicle-three-native-crew — REAL
Reproduced: export step fails after 1.3 s; retained
`/tmp/opencode/native-vehicle-expansion/<id>/export.log` shows
`Error: Derivative source inventory differs from locked source`
(`semantic.mjs:73`). `port/native-vehicle-expansion/run.py:42` forces
`COCS_SOURCE_DERIVATIVE=port/contracts/lattice-catalog-derivative.json`
(`derivative_commit 0326b435`), a frozen derivative whose `runtime_files`
inventory no longer matches the F08-changed source. The active descriptor
(`port/contracts/active-source.json` → `contact-candidate-derivative.json`,
`derivative_commit 8a6e7be2`) is what the guest-leave journey and `launch.mjs`
already adopt and it passes `verifySource`. Fix: point `run.py` at the active
source (or advance the historical derivative). This is the last gate still on
the pre-F01 hard-coded derivative path.

### world-weather-campaign-journey — ENVIRONMENT (host-timing), REAL caveat
Reproduced: `WORLD_WEATHER_JOURNEY campaign snapshots=60 failures=1`
(`journey.gd:174`, movement > 0.15 m). The input diagnostic shows **zero**
applied frames with `|x| > 0.1` and the actor never leaves `(-152,18,-104)`.
The trace shows a first queued sample with `x≈0.998` followed by
`w_blocked:true, w_held:false`: the authority's stale/epoch reset cancelled the
sample and the client deliberately does not resume a held key
(`combat_actions.clear()` → `bindings.suppress()`, `mapper.gd:39`), so the
physically-held W never re-arms. The gate already carries warm-up workarounds
and never had a committed `failures=0`; on llvmpipe the first-view gap is long
enough to force the stale window. Classified ENVIRONMENT because the mechanism
is real-time-dependent; if it persists on a GPU host it becomes a REAL
input-admission fix.

### horde-upgrade-fixture — ENVIRONMENT
Reproduced identically to the committed log: 10 failures, `authority.applied:[]`,
`intent:null`, `controlResets:52` (all `stale-input`), child exit code 1 (killed
at the deadline). The native observer's own `frameTiming` shows `maxMs 2952`,
`p50Ms 58` on llvmpipe; the fixture is a documented real-time accelerated-offer
harness with its own "environment diagnostics" for the 250 ms input TTL and a
24 s `stage settle` deadline. The gate passed historically
(`"ok":true` at `091b1333`, `b68d73d8`, `b6eec0cf`, `683ead49`, `fd70d25e`,
`89dd5745`, `508f2e03`). Re-run on GPU hardware before any code change.

## Recommended fix order

1. **P1 quick wins (node/headless, low risk)** — native-graphics-ownership
   (copy `active_source.mjs` + synthetic descriptor into the stub),
   multiplayer-world-derivatives (regenerate), vehicle-shared-shot-owner
   (assert on this handler), operator-detail-textures (share/agree the detail
   material), main-menu-live-attract (retarget the test to the 8-clip set).
2. **P1 turret reconciliation** — animation-world-physics +
   vehicle-fleet-visuals together: make `apply_source_pose` preserve the
   relative `turret.rotation.y` (or update both invariants). Verify with the two
   headless gates plus a visual spot-check.
3. **P2 journeys** — product-shell-guest-leave (leave→launcher exit),
   experience-combined-arms-journey (compact caption region), then
   vehicle-three-native-crew (adopt the active-source descriptor in `run.py`;
   treat as derivative/receipt-touching).
4. **P3 environment** — horde-upgrade-fixture and world-weather-campaign-journey:
   re-run on GPU hardware first; only fix if they persist.

## Not reproduced / caveats

- No GPU host: the two rendered real-time journeys (horde-upgrade-fixture,
  world-weather-campaign-journey) were classified from committed logs plus a
  single llvmpipe run; their pass/fail on production hardware is unverified.
- The full `verify.py` aggregate was **not** re-run (386 gates); each gate was
  reproduced by its registry command, so cross-gate ordering effects (e.g. a
  generated manifest) were handled manually for guest-leave.
- `multiplayer-world-derivatives` appears in the owner's list although the
  committed `dd9b7f73` report records it passing; it fails at the current tip
  and is included as REAL.
- `git status --porcelain --untracked-files=no` is clean; the generated
  `godot/content/generated/` produced for the guest-leave retry was removed.
