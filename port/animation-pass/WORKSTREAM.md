# Animation and physics-informed movement pass

Owner request: use **Sol subagents** to improve all animations and research
best practices for a feasible form of physics-based movement. This extends the
targeting and campaign-variety pass before its combined release.

## Current status

**Both Sol lanes are integrated and have released Godot.** Final physics
acceptance commit `cd15d7b3` is integrated as `c391b3d9`. The combined actor /
physics build passed 23 native suites, including 18 physics and 52 world-animation
checks, all ten weapons, eight workshop fixtures and the actor containment suite.
A real connected scripted-input journey passed (`live-CU6C03`): three confirmed
hits and one kill before cheats, ten-weapon trigger/recoil agreement, and real-wire
pause/resume, flight, weapon grant and clearing. This is not human-paced play.

Parent reviewed both ten-weapon contact sheets and the eight-workshop gallery.
The paired weapon, workshop and vehicle clips are published in the existing
`quiet-relay-gallery-2026-09-30` release as `weapons-before-after.mp4`,
`workshop-before-after.mp4`, and `vehicle-before-after.mp4`; the existing actor
and cast comparison clips are preserved. Evidence includes 730 native images;
llvmpipe captures do not establish hardware performance.

**Edge/effects Astra now holds the exclusive engine slot.** New combined exports
and platform verification follow that lane's integration. The ownership/grant
notes below preserve earlier checkpoints; this current status supersedes them.

## Integration baseline

`4d41cdef` contains accurate campaign robot hit regions, readable enemy movement,
faster player projectiles, current-snapshot solo NPC poses, acknowledged campaign
input flow, and eight optional chapter workshops. Published runtime `091b1333`
predates these improvements. Preserve previous archives and evidence.

## Parallel Sol ownership

Both agents use `openai/gpt-6.1-sol`, explicitly selected for the owner's request.

- **Actor animation:** `ses_f06e122bdffeBchH37HQB5vO8M`, branch
  `improvement/animation-actors`, worktree
  `/home/mojo/.tmp-on-disk/cocs-animation-actors-20261001`.
  Owns operator/fallback rigs, robot rigs, Patch, story and menu character
  gestures. Audits idle, locomotion, transitions, action poses and reactions.
  Has the **exclusive Godot slot**, with serialized optional Blender use.
- **Physics, player and world animation:** `ses_f06e09241ffeiLH0tLPWYuuXI7`,
  branch `improvement/animation-physics`, worktree
  `/home/mojo/.tmp-on-disk/cocs-animation-physics-20261001`.
  Owns first-person/weapon motion, secondary dynamics, scenery/workshop machinery
  and supported vehicle presentation. Researches physical locomotion,
  physics-informed animation and active-ragdoll feasibility for this architecture.
  **Research/code/Node only** until explicitly granted the engine slot.
- **Parent:** shared presentation/session wiring, integration, package closure,
  canonical gates, final gameplay acceptance, exports and platform verification.
  No competing engine work during a lane's grant.

## Acceptance

Subsequent owner feedback adds an Astra edge-hit/impact-mark/weapon-shader lane;
see `port/edge-effects/WORKSTREAM.md`. Physics Sol retains its current engine
grant and completes native animation acceptance first. Astra begins with code
and source tests, preserving animation changes, then receives the next engine
slot. Combined release includes verified results from both workstreams.

Actor commit `d4d23766` is integrated as `c37224e2`. Parent reviewed the overview
and close cast contact sheets. Operator/robot/gesture/Patch locomotion now uses
contact-aware procedural motion and bounded springs; source-fire acceptance
covered 18,468 native samples and 73,872 shots without enlarging hit regions.
Actor Sol explicitly released Godot. **Physics Sol now owns the exclusive engine
slot** for combined semantic/native checks, paired captures and a connected
gameplay journey. Parent remains engine-idle.

The package builder already includes all tracked non-test Godot scripts via its
reviewed native-file inventory (`build.py: native_files`), so both new actor
helpers and both physics helpers enter exported resources automatically. Added
actor native and geometry-to-source-fire canonical gates. Extracted geometry uses
fresh verification-owned paths; canonical tests no longer overwrite the tracked
targeting point fixture.

Physics lane code/research checkpoint `ed0bdbc8` is integrated as `791d0e18`.
It implements exact critically damped cosmetic dynamics, source-driven weapon
inertia/recoil/landing, eased workshop mechanisms and bounded wheel/casing
presentation. Parent added campaign focus/source-pause and direct-rig flight /
reduced-motion hooks and its native verification gate. Syntax and six authority
tests passed in the lane; semantic/native/capture acceptance is **pending**.
Actor Sol still owns the exclusive engine slot; physics Sol is READYFORENGINE
and has not launched any engine process. See `PHYSICS.md` for sources and scope.

Supplemental physics checkpoint `35368568` is integrated as `ca825b91`, with a
canonical world-animation gate. It prepares native workshop frame-rate/stage
tests, actual campaign host pause/focus/death/stale lifecycle checks, vehicle
wheel bounds/reset coverage and casing-pool trajectory checks. It also preserves
immediate source-sample wheel angle publication. These tests are prepared and
syntax-checked, **not yet executed by Godot**; the engine grant is unchanged.

Use primary developer/documentation sources with precise citations. Implement a
practical form of physics-informed animation where supported by the research and
current architecture. Distinguish cosmetic response from authoritative movement.
Keep accurate aiming, collision, source ownership and readable enemy tells.

Require a coverage inventory across animation families, purposeful visible
improvements, bounded frame-rate-independent dynamics, reset/pause correctness,
and native animation sequences or clips. Test robot chassis/sensor containment
against the corrected hit regions at new pose extremes. Preserve failures and
report automated animation checks separately from human feel and GPU performance.

Evidence roots:
- `/home/mojo/.tmp-on-disk/cocs-animation-actors-evidence-20261001/`
- `/home/mojo/.tmp-on-disk/cocs-animation-physics-evidence-20261001/`
