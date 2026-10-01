# Targeting and level variety — second owner playtest pass

## Goal

The owner reports that enemies are difficult to hit, move too fast, and appear
to have incorrect hitboxes. Player projectiles feel too slow. They also request
more interesting downtime and greater variety across the single-player levels,
explicitly asking for Astra subagents to investigate and implement improvements.

Baseline release: `091b1333`, published as
`quiet-relay-feel-expansion-2026-10-01`. Integration starts at `f426e755`.
Existing archives and evidence remain unchanged.

## Parallel ownership

Targeting commit `b7574c83` is integrated as `0afd4d7e`. Parent flow-control
commit `75e9b3a0` passed its native 614 checks in the targeting lane. Targeting
released Godot; **level-variety Astra now holds the exclusive Godot slot**, plus
permission for one serialized Blender process if needed. Parent remains engine-idle.

Targeting intake: actual imported chassis/sensor bounds replace smaller fallback
hit regions, with body yaw/asymmetric offsets and 6 cm edge padding. Solo NPCs
use latest snapshot poses rather than the added 100 ms multiplayer delay.
Campaign movement uses slower role speeds, committed directions and planted
windows. Player plasma/rocket/grenade speeds are 138/60/36 m/s. An explicit
generator projectile-weapon lookup hook retains source swept collision and
leaves frozen source and global weapon tables unchanged. Parent reviewed the
generator/callsite and added the helper to package closure and two canonical gates.

Lane evidence: 42 campaign Node tests, 11,952 fire-to-damage checks using 2,988
native mesh samples, 459 robot checks and 614 input-flow checks passed. Headless
geometry/presentation acceptance is complete; new combined gameplay and Windows
package acceptance remain pending. Full measurements and provenance are in
`port/native-campaign/TARGETING.md`.

Parent integrated Node acceptance passed **57/57**, including campaign lifecycle,
hit geometry/projectile tests, source provenance, cheat effects, prior feel policy
and package closure. Log: `cocs-targeting-evidence-20261001/parent-integrated-node.log`.
The final combined pass must still exercise an actual native input journey after
the level-variety lane lands, then verify fresh extracted Windows/Linux archives.

### Targeting — Astra

- Session: `ses_f0708252dffevsEhnC1yJEnfnD`.
- Worktree: `/home/mojo/.tmp-on-disk/cocs-targeting-pass-20261001`.
- Branch: `improvement/targeting-pass`.
- Owns robot silhouette/authoritative hit-region audit, readable enemy movement,
  player projectile responsiveness and source-vs-presentation alignment.
- Owns campaign feel/enemies and surgical combat-method hooks in match.mjs;
  changes to Horde hit geometry require demonstrated mismatches and isolation.
- Evidence: `/home/mojo/.tmp-on-disk/cocs-targeting-evidence-20261001/`.
- **Exclusive local Godot grant now**, serialized, `LP_NUM_THREADS=1`.

### Level variety — Astra

- Session: `ses_f07076d37ffehkcFfEtcHp7Pbe`.
- Worktree: `/home/mojo/.tmp-on-disk/cocs-level-variety-20261001`.
- Branch: `improvement/level-variety`.
- Owns authored between-fight activities, environmental storytelling, optional
  exploration/rewards and distinct chapter-specific visual/playable beats.
- Owns modular interlude authority/state, missions/story/recipes/presentation and
  surgical progression/checkpoint hooks in match.mjs.
- Evidence: `/home/mojo/.tmp-on-disk/cocs-level-variety-evidence-20261001/`.
- **Research/code/Node only** until targeting explicitly releases Godot and the
  parent grants the slot. No Blender grant yet.

### Parent

Integrates the two lanes, resolves small shared match hooks, maintains explicit
runtime package closure and verification gates, reviews evidence, and exports
and verifies the next testing build. Parent performs no local engine work while
a lane holds the slot. No frozen-source or silent generated-core modifications.

## Acceptance focus

- Confirmed source hits at visible chassis points, with cover/edge/miss checks,
  representative poses, moving targets and projectile collision coverage.
- Measured enemy displacement/reversal and player projectile flight times before
  and after; changes preserve weapon and robot roles.
- Authored activities are reachable through real controls, give visible feedback,
  preserve main-objective/puppy interaction priority, and cannot duplicate rewards
  or block campaign completion when skipped.
- Native visual inspection and bounded scripted input journeys supplement Node
  checks. Human enjoyment, first-time pacing and hardware performance remain
  playtest observations, not automated-test conclusions.
- Preserve original failures and publish only actual platform acceptance.

## Confirmed Windows input-queue defect and parent repair

Original-launcher workflow `36915750362` captured a Crown failure after roughly
20 seconds of play: `Input queue limit` from campaign authority receive(), with
zero outgoing buffered bytes. The prior outbound-backpressure hypothesis does
not explain this captured failure. Logs are preserved under the earlier feel
evidence root's `integrated-release/windows-original-trace-36915750362/`.

Parent owns a campaign-only, source-ACK-bound four-sample input window in
`godot/campaign/client.gd`, plus handling `ERR_BUSY` in the shared session send
block. The existing action sampler retains fresh pulses and pending weapons until
a send succeeds. Cancellation bypasses the window and clears it in transport
order; authority epoch changes invalidate old credit. Source queue limit 16 and
250 ms TTL remain unchanged. A native regression script exercises a sender four
times faster than its consumer, fresh-action retention, cancellation, new epochs
and actual connection errors. Native execution is pending the targeting lane's
engine slot; parent does not run a competing engine. This repair must be included
in the next targeting/variety build and verified on Windows before claiming the
captured disconnect is fixed.

## Other open work

The published Windows build passed all 67 package cases after two Crown
disconnects; it predates this repair. Full Blackwater chain/Warden acceptance and
the cinematic trailer refresh are still open.
