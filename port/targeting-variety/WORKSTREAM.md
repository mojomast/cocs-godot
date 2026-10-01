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

## Prior unresolved limits

The published Windows build passed all 67 package cases after two Crown startup
disconnects. The cause remains unresolved; the corrected original-launcher
transport-observation workflow is available for diagnosis. Full Blackwater chain
and Warden acceptance and the cinematic trailer refresh are still open.
