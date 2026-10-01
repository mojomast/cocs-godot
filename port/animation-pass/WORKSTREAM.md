# Animation and physics-informed movement pass

Owner request: use **Sol subagents** to improve all animations and research
best practices for a feasible form of physics-based movement. This extends the
targeting and campaign-variety pass before its combined release.

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

Physics lane code/research checkpoint `ed0bdbc8` is integrated as `791d0e18`.
It implements exact critically damped cosmetic dynamics, source-driven weapon
inertia/recoil/landing, eased workshop mechanisms and bounded wheel/casing
presentation. Parent added campaign focus/source-pause and direct-rig flight /
reduced-motion hooks and its native verification gate. Syntax and six authority
tests passed in the lane; semantic/native/capture acceptance is **pending**.
Actor Sol still owns the exclusive engine slot; physics Sol is READYFORENGINE
and has not launched any engine process. See `PHYSICS.md` for sources and scope.

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
