# External follow-up: playable native Puma driving demo

## Context and goal

Continue the Puma component delivered at `3159acb124458d5564ac6317e9f722026a68ade4`
on `subagent/native-puma-presentation` in
`/home/mojo/.hermes-instances/fresh/workspace/cocs-native-puma-presentation`.

Primary checkout is `/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port`,
branch `port/godot-destinations`; the current integration reference is `edc222f`.
The primary now contains native environments, entities, setup, scoreboard and
audio. New agents own infantry weapon switching, compact HUD and extra modes.

**Deliver a playable standalone native Puma demo on Ion Speedway and Aurora
Stadium, using real source authority, native controls and a chase camera.**
This is the next practical step toward native race/soccer integration. It does
not require full race/soccer feature completion or source visual parity.

The lead directly inspected `puma-synthetic.png`: vehicle silhouette, wheels,
cage and front/rear details are visible. This is visual inspection of the
synthetic fixture, not live driving acceptance.

## Isolation and ownership

Create a new follow-up branch. Preserve the original `3159acb` delivery.
Base on current primary plus your Puma commit in your own worktree, or merge
current primary into your follow-up branch there. Do not edit primary. Keep the
new implementation commits separate so the lead can cherry-pick them without
bringing an unrelated merge history.

Own only:

- `godot/vehicles/` — your existing renderer/model and vehicle-specific helpers
- `godot/sports/` — new standalone scene, native driving/chase camera/sports HUD
- `godot/tests/vehicles/` and `godot/tests/sports/`
- `port/tools/native_vehicle_demo/`
- `port/native-vehicle-presentation/` and `port/native-puma-driving/`

Do not edit shared `godot/world/`, `godot/ui/`, `godot/net/`, full verifier, root
documentation, `game/`, `server/`, exporter, dependencies, locked scope or reserved
pulse-rifle assets. Existing modules may be used read-only. If a shared change is
essential, deliver the smallest exact integration requirement to the lead.

## Discovery before implementation

Read your original handoff and relevant current port code. Confirm the actual
server input and snapshot contracts in `game/vehicles.mjs`, `game/core.mjs`,
`game/race.mjs`, `game/soccer.mjs`, `game/race-camera.mjs`, protocol definitions and
their tests. Read both locked sports map entries.

If subagents are available, run two bounded read-only investigations in parallel:

1. Supported driving/braking/boost inputs, ownership, kickoff/countdown and reset.
2. Chase-camera conventions and actual race/soccer/ball snapshot fields.

Finish both before coding. Summarize the findings, files to change, and API.
Important existing finding: vehicle heading zero is **+Z**, unlike the infantry
camera's -Z convention. Source vehicle position is its ground anchor.

## Implement in this order

1. **Standalone authoritative client.** Add a scene under `godot/sports/` that
   uses the existing protocol client without modifying it. Accept explicit
   endpoint/map arguments and select the matching locked `puma-race` or
   `puma-soccer` mode. Allow host creation/start; guest support is optional.
   Reuse current native world presentation read-only if practical.
2. **Real native driving controls.** Map physical keys to source-supported
   throttle/steering/braking/boost commands after inspecting the protocol.
   Do not invent fields or change driving rules. Neutralize controls on focus
   loss, released interaction, missing authority/ownership and stale snapshots.
   Require a deliberate fresh action to resume. Avoid copying the entire infantry
   session state machine; use a small sports-specific client.
3. **Chase camera and vehicle rendering.** Wire your renderer to accepted full
   snapshots and round cleanup. Follow the locally owned vehicle with a stable
   chase camera that handles +Z heading, reverse travel and reset without flips.
   Camera smoothing is visual-only; do not locally simulate vehicle physics.
   Avoid rendering a standing infantry body through the local vehicle.
4. **Minimal useful sports display.** Show authoritative countdown/phase and
   speed; lap/checkpoint for race and team score for soccer where real fields
   exist. For soccer, render the authoritative ball with a simple native sphere
   so driving has meaningful visual context. Mark unavailable fields honestly.
5. **Document and demonstrate.** Provide one clear launch command for each map
   and controls. Keep the demo standalone; the lead owns main-menu integration.

If using implementation subagents, run those dependent steps sequentially with
narrow file ownership. Favor usable native behavior over a 1:1 web recreation.

## Verification and execution

- Pinned Godot:
  `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`
- Existing primary `node_modules` may be used read-only. No new packages.
- Add focused regressions for heading/camera behavior, input gating and reset.
- Execute actual native sessions for **both** Ion Speedway and Aurora Stadium
  against an owned normal-rate server on an OS-assigned loopback port.
- Use native physical input events or private OS input. Observe authoritative
  vehicle displacement/turning and correspondence with the rendered vehicle.
  Retain a small sample proving actual input, source receipt and resulting state.
- Do not teleport, modify health/positions, skip countdown via state writes,
  accelerate timers, alter rules, or pass fabricated snapshots off as live.
- Bound each live attempt to at most 90 seconds. Keep unsuccessful attempts and
  report a concrete blocker rather than retry indefinitely.
- Render screenshots on a newly owned private Xvfb display. Do not use the owner's
  desktop. Inspect images directly if your tools support it; otherwise provide PNGs
  for the lead and explicitly leave visual review pending.
- Exclude welcome credentials before retaining evidence. Keep captures compact;
  distinguish input receipt, ACK high-water and observed state changes. No native
  trace terminal marker exists: do not claim full recording completion.
- Clean up and verify only your owned server/children/display/temp resources.
- Run focused tests, `git diff --check`, and `git status --short`. Fix failures
  and rerun the affected check. No shared-service restart or deployment is needed.

## Delivery

Commit only owned files; no push or primary merge. Return:

- Ordered new commit hashes and base revision.
- Exact demo/API integration points for accepted snapshots and round cleanup.
- Commands actually executed and their results for each map.
- Screenshot paths and live-versus-synthetic classification.
- Manual test: start, wait through countdown, accelerate, steer, brake/reverse,
  release/focus loss, resume deliberately, and restart/reset if supported.
- Remaining gaps: do not claim lap completion, goal scoring, full sports gameplay,
  or human camera usability unless actually exercised.

Preserve unrelated work and all other agents' worktrees.
