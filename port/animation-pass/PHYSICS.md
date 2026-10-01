# SOL physics / player / world animation pass

## Decision and primary-source research (read 2026-10-01)

**Implement procedural physics-informed animation on cosmetic rigs.** Preserve
the JS source simulation, collision, hit registration, projectile direction,
immediate camera aim and existing local smoothing. None of the 515 frozen game
files or derivative authority files is changed by this lane.

Three different techniques must not be confused:

* Physical locomotion changes the simulated body's velocity/collision response.
  Godot's [4.5 CharacterBody3D reference](https://docs.godotengine.org/en/4.5/classes/class_characterbody3d.html)
  says characters are moved by script, are not affected by physics themselves,
  and `move_and_slide()` belongs in `_physics_process()`. Replacing the source
  controller with a native physical body would create a second authority.
* Procedural physics-inspired animation follows authoritative state and applies
  damped visual offsets. This is feasible here and is implemented below.
* Full active ragdoll requires physical joint bodies, pose-target forces,
  collision exceptions and a controller capable of balancing/supporting them.
  [PhysicalBoneSimulator3D 4.5](https://docs.godotengine.org/en/4.5/classes/class_physicalbonesimulator3d.html)
  only supplies physical-bone simulation and applying results to a Skeleton3D;
  it does not supply an active-ragdoll balance controller. Current rigid weapon
  and machinery hierarchies do not require or justify that architecture.

[Godot 4.5 physics ticks/interpolation introduction](https://docs.godotengine.org/en/4.5/tutorials/physics/interpolation/physics_interpolation_introduction.html)
explains fixed physics ticks versus render frames, the previous/current-tick
interpolation delay, and explicitly identifies multiplayer as a case where
custom interpolation can fit better. Therefore no global interpolation toggle,
extra NPC buffer or camera spring is introduced.

[Glenn Fiedler, Fix Your Timestep! (2004)](https://gafferongames.com/post/fix_your_timestep/)
explains why variable-delta numerical springs can explode and why unrestricted
catch-up can spiral. The cosmetic helper uses a closed-form solution instead of
Euler integration or a catch-up loop.

[Daniel Holden, Spring-It-On (2021), critical spring and inertialization sections](https://theorangeduck.com/page/spring-roll-call)
derives exact critical damping with position and velocity continuity. We use the
same mathematical critical solution, with `exp`, directly parameterized by
angular decay rate, finite guards, impulse caps and zero settlement. The solver
is exact for a constant goal within each frame; changing goals/events at
different sample times are not claimed to produce bit-identical trajectories.
Critical damping prevents spontaneous ringing, but a velocity impulse can still
produce a single bounded excursion; it is not a promise of no motion.

[David Rosen, GDC 2014, An Indie Approach to Procedural Animation, primary slides](https://media.gdcvault.com/GDC2014/Presentations/Rosen_David_Animation_Bootcamp_An.pdf)
were downloaded and their full text extracted/read. This is a **slide deck, not
a peer-reviewed paper or a fully watched talk**. Slides explicitly distinguish
acceleration tilt, impact compression, stand/crouch spring, jump landing,
secondary physics, active ragdolls (AI joint forces), first-person spring
interpolation and recoil springs. The deck's “do no harm”, “consistent controls”
and “tool to assist animation, not replace it” support overlapping bounded
presentation systems. Local research evidence: `research/rosen-gdc2014.pdf` and
the extracted `research/rosen-gdc2014.txt` in the evidence directory.

## Implemented coverage

| Family | Implementation / audit outcome |
|---|---|
| All ten weapon fire identities / automatic / semi | Source accepted volley gate retained, pellet/shrapnel dedup retained; source-derived kick and recover profiles retained. Transient recoil now has exact critical spring return, initial shove remains immediate. No source cooldown/reload/ammo edits. |
| Idle / locomotion | Remove clock-driven bob, breathing and ornamental idle sway. Inertial weapon offsets arise from actual source velocity changes, decay to exact zero; repeated snapshots cannot create forces. No perpetual idle motion. |
| Aim / ADS | Existing authored sight alignment and exponential ADS/FOV transitions retained; secondary offsets multiply `(1 - aim_weight)` and settled sights remain still. Source camera orientation and projectile ray untouched. |
| Look / acceleration / deceleration | Bounded exact spring weapon sway and momentum impulses; look input itself is never delayed. Position history detects >4m discontinuities. |
| Sprint / jump / landing / damage | Cosmetic sprint lowering follows source sprint flag; ground transitions with real vertical velocity generate restrained compression; health decrease gives restrained weapon flinch; flight gate suppresses ground impulses. |
| Reload / hands | Source progress remains the sole reload clock. Receiver lift/hold/seat replaces symmetric sine; left hand still follows real feed anchors, right hand stays on grip. Existing extraction, insertion, racking, heat and break-action windows already appropriate. |
| Switch | Cubic smoothstep holster-to-ready instead of linear drop; same existing selection window. |
| Melee | Accepted source event only; fast extension/contact hold/eased followthrough. No delayed/fake impact: world contact/audio stays at source event time. Confirmed-hit ring expands with decelerating release. |
| Muzzle / casing / impacts | Existing finite flash/tracer/light pools and source-confirmed impacts retained. Cosmetic casing gravity now closed-form (position receives half-acceleration term), reducing frame-rate arc discrepancy. Projectile position/collision and hit evidence unchanged. |
| Eight workshops | Lids critically damp toward source-confirmed choice; rotor spins up/down with exactly integrated critical motor-speed spring. Lamp/cable/panel restoration color and emission ease from existing material state, not snap. Legitimate stage/reward/E logic and solid geometry unchanged. |
| Waterwheel / receiver / choir / nursery | Supported visible rotors receive motor inertia; condenser/foundry stacks and garden static shapes remain purposefully static, restoration illumination carries their activation. No decorative motion added to every object. |
| Gameplay Puma vehicle | Wheel rotation renders continuously between snapshots with a capped 100ms visual lead. Source root, pitch/roll, turret orientation remain immediate. There is no steer-angle channel; no steering/suspension controls fabricated. |
| Environment art / windmill | Campaign environment-art batch module has no supported articulated windmill or foliage motion channels; imported geometry/materials/collidables are preserved. Existing ambience/weather is outside this lane and already purposeful. |
| HUD / characters | Existing HUD hit/hurt windows retained. Operator/robot/Patch/story/menu character rigs belong to ActorSol and are not edited here. |

## Sharing contract / parent integration

`res://animation/critical_spring.gd` is independently preloadable: `reset(at=0)`,
`impulse(amount, velocity_limit=2)`, `advance(delta, goal=0, omega=18,
position_limit=.1) -> float`; public `value`, `velocity`. Scalar cosmetic units
only. No dependencies on the other lane. The helper accepts full elapsed time;
it is not a source motion smoother.

The passive first-person session adapter reads existing `reduced_motion` and
`session.solo_cheats.state.flight/paused`. Hosts that directly own the rig should
set `rig.flight_mode` from **top-level `state.soloCheats.flight`** before
`rig.apply_actor(...)`; actor snapshots do not themselves carry that flag.
Set `interlude_director.animation_suspended` from top-level
`state.soloCheats.paused` and existing gameplay/focus lifecycle eligibility.
The director already freezes while the settings overlay is open, and normal
SceneTree pause stops its processing. No shared session/presentation file edited.

## Verification / engine-slot handoff (initial independent phase)

Engine is reserved by ActorSol. **No Godot, Blender or import process was
launched during independent coding. Native acceptance and capture remain pending
the explicit engine-slot grant.**

Prepared meaningful native test: `godot/tests/animation/physics.gd` compares the
actual helper to the independent analytical impulse equation at 30/60/144 Hz and
irregular/hitch timings, boundedness, exact idle, repeated snapshot neutrality,
real jump/landing, teleport, flight, reduced motion and reset. Existing
`tests/first_person/{recoil,ads_contract,lifecycle,handling}.gd`, vehicle and
melee tests should run alongside it after import.

Independent checks completed: `gdparse` accepted all 13 changed/new GDScript
files (syntax only; **not** Godot semantic compilation); `git diff --check`
passed; campaign authority Node tests **6/6 passed** after reusing the parent
workspace's existing node_modules through an ignored symlink. Initial Node run
was blocked by absent `ws`, resolved by that dependency reuse. A base comparison
against `4d41cdef` reports no changes under `game`, `port/contracts`,
`port/native-campaign`, or `port/native-debug`. Logs are in the evidence root.
The old detail test asserting perpetual weapon-specific idle sway was updated
to assert neutral idle does not drift; authored detail/hand/sight clearance
checks are retained. Secondary offset amplitude now follows source kick heft.

Prepared paired native capture: `tests/animation/capture.gd -- --out=<dir>`
outputs 226 frames per rig (ten weapons idle/fire/ADS/reload plus acceleration,
landing and accepted melee). `--rig=res://tests/animation/baseline_rig.gd`
selects the base rig copied temporarily from `git show 4d41cdef:godot/first_person/rig.gd`.
Remove that temporary baseline after capture. Scripted source-shaped snapshots
are isolated visual evidence, **not** an actual in-game input sample.

### Supplemental native preparation after parent integration

Parent integrated the implementation as `791d0e18`; parent hook commit
`b52e0215` is included locally as `78dca04e` for upcoming native tests. Its
WORKSTREAM document did not exist in this lane, so cherry-pick retained the
parent version rather than dropping it. Do not re-integrate `78dca04e` upstream.

`tests/animation/world_physics.gd` now exercises real workshop director rotor
distance, lid pose, motor velocity and illumination at 30/60/144 Hz and irregular
frames. It checks changing stages/choices during unfinished transitions, retired
light targets, stable node/material identities through frame loops, settled
colors, reduced-motion motor stop/resume and clear-round recreation.

The test's detached campaign host subclasses **the actual campaign demo** and
calls its unchanged `_process()` and `can_capture_pointer()` chain. Only startup
and handshake are excluded. It freezes unfinished motor/lid/light state under
source pause, application focus loss, action pending, dead actor and stale
snapshots, then verifies resume consumes only newly supplied elapsed time.
This is a deterministic native host-hook regression, not OS focus/input evidence.
The helper test's reset assertion is now explicitly described as restart only.

The same test exercises actual Puma renderer signed wheel lead/radius,
30/60/144 equivalence, 100ms cap, reduced motion, teleport/respawn/gap resets,
source root/turret invariance and clear-round. Static review identified the
existing Puma test's immediate snapshot-angle contract; `observe_roll()` now
publishes that angle immediately as well as supporting render-tick lead.
Actual casing pool/advance tests compare its ballistic arc to the independent
constant-gravity equation at three rates and irregular/hitch timings, verify
velocity, lifetime expiry, node reuse and reset freeing.

At the supplemental-preparation checkpoint these native tests remained
**unexecuted until engine grant**. Before
capturing workshop restored colors, advance at least 2 seconds after source
stage 2 so screenshots represent the intended settled illumination.

## Final native acceptance after exclusive engine grant

ActorSol's exact `d4d23766` is included locally as `900454ad`. The integrated
actor/player/world code was imported and tested with Godot
`4.5.2.stable.official.6ce3de25a`, `LP_NUM_THREADS=1`, and serialized engine
processes. Native rendering uses Xvfb / Mesa llvmpipe compatibility mode.
This is functional/visual evidence, **not hardware performance acceptance**.

**Import/semantic compilation passed. All 23 native regression suites passed.**

| Native suite | Checks / result |
|---|---|
| `animation/physics.gd` | 18 passed; analytic reference, frame rates, hitch, flight, reduced motion and reset |
| `animation/world_physics.gd` | 52 passed; real host pause/focus/stale/death/pending gates, workshop transitions, wheel lead/reset, casing arcs/pool |
| First-person lifecycle / ADS / recoil | 63 / 93 / 190 passed |
| First-person handling / detail / muzzle geometry | 5,295 / 310 / 274 passed; all ten weapons |
| First-person art override | passed |
| First-person binding under Xvfb | 19 passed; real pointer capture |
| Weapon effects lifecycle / rig integration | passed |
| Weapon effects muzzle-path geometry / projectile flight / alt fire | 279 / 22 / 105 passed |
| Puma presentation | 19 passed |
| Source-confirmed melee feedback | 50 passed; miss/duplicate/rejection cannot invent contact |
| Campaign feel motion / targeting geometry | passed |
| Campaign input flow | 614 passed |
| Campaign interludes | all eight source-produced before/linked/after fixtures passed, including geometry hashes/colliders/routes |
| Actor animation / geometry | 3,258,456 checks / 18,468 geometry samples passed with combined physics lane |

The first `world_physics` attempt failed due to **fixture issues**: teardown
reflected detached Node3D global properties and an exact float comparison
rejected an unchanged turret value. The corrected fixture uses explicit owned
node fields and approximate transform/scalar comparison. Attempt 2 passes
cleanly; both logs are retained. No production controller/FX regression fix was
needed during engine acceptance. The immediate Puma snapshot-angle compatibility
fix was already in supplemental `35368568`.

### Real connected gameplay input journey

Command: `GODOT_BIN=<pinned 4.5.2> LP_NUM_THREADS=1 python3
tools/godot-dev/xvfb_run.py node port/singleplayer-feel/live.mjs --run-native
--output=<evidence>/connected`.

`connected/live-CU6C03/acceptance.json` reports **passed=true, wireOK=true,
exit=0, no failures**. The journal comes from the real Node campaign authority;
there is no actor-state injection, fabricated shot event, matchFactory or
control server. Inputs are scripted, so this is not a natural human playtest.

Before any cheats, normal combat recorded **3 confirmed hits / 1 kill**, reaching
route vertex 20. The later real-wire diagnostic segment exercises pause/resume,
invulnerability, unlimited ammo, weapon grant, heal, flight and cheat clearing.
Flight rises 6.8m and the camera settles within 0.0317m of source translation
after landing; existing local smoothing remains intact.

All ten weapon diagnostic trigger checks match rig recoil events to accepted
trigger volleys: weapons 0 and 9 each record `2 shots / 2 recoil events`, and
weapons 1–8 each record `1 / 1`. Whole-journey source shot/launch event counts are
`{0:37,1:2,2:1,3:8,4:2,5:1,6:1,7:12,8:1,9:4}`. These are **event counts, not
trigger counts**: pellet/fragment events must not be mistaken for extra recoil.
The real journey exports four native screenshots and raw journal/report/logs.
Its audio-before comparison belongs to the existing audio harness, not this
animation pass; no audio improvement claim is made here.

### Coherent paired native rendering and inspection

`baseline-manifest.json` records SHA-256 values for all eight modified production
dependencies. Before captures restore **all eight** from `4d41cdef` together:
rig, handling, session binding, weapon-FX controller, melee feedback, interlude
director, Puma and vehicle renderer. Therefore the before rig does not use the
new handling code. Actor files are held at the integrated ActorSol revision in
both fixtures; these isolated captures do not invoke actor animation. Every
current dependency was restored and verified against its saved after hash.

Native raw image counts (composite review images excluded):

* Weapons: **226 before + 226 after**; ten identities, fire/recovery, settled ADS,
  source reload progress, acceleration, landing and accepted melee.
* Eight workshop gallery: **16 before + 16 after**, with fixed 2s settlement
  before reading restored colors. The capture no longer assumes 12 render frames
  are enough elapsed time on every renderer.
* Native waterwheel restoration / Puma wheel sequences: **121 before + 121
  after**. Waterwheel completion uses source-generated workshop fixture states;
  Puma uses labelled synthetic 20Hz velocity samples for cosmetic comparison.
* Connected gameplay: **4** screenshots.
* Total: **730 native PNGs**, plus derived contact sheets/comparison frames.

Three derived, labelled side-by-side native-frame clips:

* `review/weapons-before-after.mp4`: **27.833s / 835 review frames**. Short fire
  phases are held longer for readable comparison; this is an editorial review
  timeline, not a real-time gameplay recording. Transparent weapon captures are
  composited over a neutral background for the comparison.
* `review/workshop-before-after.mp4`: **2s / 60 frames**.
* `review/vehicle-before-after.mp4`: **1s / 60 frames**.

Inspected native representative fire/melee frames, both all-ten-weapon contact
sheets (idle/fire/ADS/reload), all eight settled workshop views, an early paired
waterwheel transition frame, Puma wheel frames and the actual connected combat
screenshot. Fire/reload identities remain legible, settled ADS remains aligned,
the kick follows through without fabricating contact, restored machinery stays
above its existing solid housing, and wheel rotation is confined to the wheels.
The deterministic tests supply boundedness/cadence/clearance checks that still
images cannot establish. Inspection here is of frame sequences/keyframes,
not a claim that a human watched all clips or performed auditory acceptance.

Evidence root remains
`/home/mojo/.tmp-on-disk/cocs-animation-physics-evidence-20261001/`.
All test/capture attempts and the initial isolated-review packaging interpreter
failure are retained/documented; the latter was resolved by using the existing
Python venv with Pillow rather than system Python. Source/authority files and
shared parent hooks were not changed during final acceptance. The generated
targeting geometry output is copied into evidence rather than committed over
the tracked fixture; parent `7f150681` provides the opt-in path fix separately.

**Final engine slot release:** all native import/test/render processes are
complete. No Blender process was used. Slot released for parent/Astra work.

Native before/after rendering must be captured and inspected after the slot
grant. At this stage **0 clips / 0 native screenshots / no hardware-performance
claim**. Evidence root:
`/home/mojo/.tmp-on-disk/cocs-animation-physics-evidence-20261001/`.
