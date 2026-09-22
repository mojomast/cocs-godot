# External agent task: native Puma vehicle presentation

Implement a reusable Godot-native Puma vehicle presentation component for the COCS Godot port.

## Project

- Repository: `github.com/mojomast/cocs`
- Local port checkout: `/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port`
- Primary branch: `port/godot-destinations`
- Known integration commit: `079c4b9043450cb67add939904b6c93e46621e1a`

Create your own branch and isolated worktree from the available current port HEAD.
Do not edit the primary checkout. If this port branch is unavailable in your
environment, request a branch/bundle rather than implementing against unrelated
upstream code.

## Goal

Deliver a lightweight, readable native Puma vehicle model and snapshot-driven
renderer, ready for the lead agent to integrate into race/soccer sessions on
Ion Speedway and Aurora Stadium.

The owner explicitly does **not** require a 1:1 port. Prefer simpler, better
Godot-native implementations. Preserve recognizable vehicle identity and gameplay
meaning; do not spend time reproducing every source material or animation.

## Ownership — only edit these reserved paths

- `godot/vehicles/` — new components and standalone demo scene
- `godot/tests/vehicles/` — focused tests, if needed
- `port/tools/native_vehicle_demo/` — small runner, if needed
- `port/native-vehicle-presentation/` — documentation and compact evidence

Other agents are actively editing session, networking, world environment,
actors/pickups, scoreboard and audio. Do **not** edit:

- `godot/world/session.gd` or `session.tscn`
- `godot/world/viewer.gd`, `presentation.gd`, `pickups.gd` or `combat_feedback.gd`
- `godot/net/client.gd`
- `tools/godot-export/`
- Pulse-rifle preview assets or existing `content/probes`
- `game/`, `server/`, dependency locks or source/map contracts
- The root README, release matrix or full verifier

## Discovery first

Read:

- `port/README.md`
- `port/contracts/CONTRACT.md`
- `port/contracts/map-selection.json`
- `game/vehicles.mjs`
- `game/race.mjs` and `game/soccer.mjs`
- `game/destination-sports.test.mjs`
- Relevant vehicle rendering code in `game/view.mjs`
- `godot/net/client.gd` and `godot/world/remote_motion.gd`

If you have subagents, use two short parallel read-only investigations:

1. Vehicle snapshot fields, identity, transforms, driver/team and lifecycle.
2. Puma visual proportions and practical native representation.

Finish discovery before implementation. Summarize the actual wire fields and
your proposed component API. Do not guess coordinate conventions or input fields.

## Implementation

1. Create a recognizable stylized Puma using inexpensive native meshes/materials:
   body, wheels, front/rear cues, team accents. New procedural geometry is fine.
2. Provide a vehicle renderer accepting authoritative snapshot state:
   - Stable nodes keyed by vehicle ID.
   - Correct position, orientation, scale and ground relationship.
   - Correct add/remove/reset behavior.
   - Bounded visual smoothing if useful; never modify or predict game authority.
   - Visual wheel/steering motion only where supported by real fields.
3. Expose a clean API such as `apply_state(state, local_actor_id)`, `clear_round()`,
   and a vehicle-node lookup. Document the exact API.
4. Supply a standalone demonstration scene so the work can be reviewed without
   editing the shared native session.
5. Prioritize this working component over building a broad framework. Race HUD,
   soccer rules, driving physics and complete sports-mode integration are out of
   this task's scope.

## Verify

- Use pinned Godot 4.5.2:
  `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`
- Existing primary `node_modules` may be used read-only. No package installation
  or dependency changes.
- Run focused checks for actual transform conversion, stable node reuse,
  vehicle disappearance and round reset.
- Render and inspect screenshots on an isolated private Xvfb display.
  Never connect to or manipulate the owner's desktop.
- Prefer a short live snapshot demonstration using an owned normal-rate source
  server on an OS-assigned loopback port. Use supported protocol controls only.
  Do not teleport actors, edit vehicle state, alter rules or inject authoritative
  snapshots into a purported live run.
- A clearly labeled synthetic render fixture is acceptable for visual review,
  but must not be described as live driving or sports-mode acceptance.
- Bound execution time, output and resource use; clean up only your own
  processes/server/display.
- Keep welcome credentials out of retained logs.
- Run `git diff --check` and inspect `git status --short`.
- No deployment or shared-service restart is needed.

## Deliver

Commit only your owned files. Do not push or merge into primary.

Return:

- Commit hash(es) in integration order.
- Component API and minimal lead integration instructions.
- Commands actually run and their results.
- Screenshot paths and what you directly observed.
- Which evidence is live versus synthetic.
- Remaining limitations and a short manual test procedure.

Preserve all unrelated work and existing worktrees.
