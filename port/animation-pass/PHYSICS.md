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

## Verification / engine-slot handoff

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

Native before/after rendering must be captured and inspected after the slot
grant. At this stage **0 clips / 0 native screenshots / no hardware-performance
claim**. Evidence root:
`/home/mojo/.tmp-on-disk/cocs-animation-physics-evidence-20261001/`.
