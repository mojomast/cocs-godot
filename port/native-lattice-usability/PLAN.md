# World usability discovery and implementation plan

Baseline: `e1defc00e37c0b560ff9fa55f1e3c4ad9f853b21`; isolated branch
`agent/lattice-usability`. Read the lead's current ACTIVE_LANES and audit
`29b0a59` before editing. Scope: world-only LATTICE presentation, new
`usability_*` tests, and this report directory.

## Code/source audit (before implementation)

- `world_demo.gd:190–202` displays lifecycle LIVE and the same resume hint
  from snapshot callbacks. Escape/focus changes can therefore have no visible
  state transition until another snapshot, and LIVE does not mean engaged.
- `world/session.gd:12–16,351–398` already gates pointer capture and sends neutral
  controls on lifecycle/stale/released states. `world_demo.gd:84–142` adds
  recipient identity, panel visibility, release-before-recapture and immediate
  neutral input for panel/focus boundaries. Presentation should read these gates.
- `world_commands.gd` owns selection, consumed spending consent and separate
  queued/accepted/completed receipts. At 960×640 its 700×590 panel needs its space.
- `lattice/transport.gd:72–114` projects only recipient nodes/resources and
  director phase/wave/window. Unknown values must stay unknown. Lease permission
  belongs to recruitment and is not evidence of capture.
- `game/cocs.mjs:1638–1773,1918–1936`: living actor presence, adjacency,
  contest and server order presence drive capture; owner transition is authority.
  Public progress cannot attribute local contribution. PvP omits radius/height;
  do not infer arrival/capture eligibility or a traversable route from distance.
- `world_hud.gd` already finds nearest received node and planar distance.
  Its missing `live` value currently becomes "inactive"; use "unknown" instead.

## Minimal change

1. Add a world-only guidance helper returning explicit control state and matching
   recovery instruction: engaged/released, unfocused, commands, stale, absent
   identity/pose, dead, results, waiting and stopped. Refresh each frame after
   inherited control neutralization. No input or authority changes.
2. Back/wrap the compact HUD and hide it while tactical commands are open.
   Show readable PvP/co-op mode names, HP/lifecycle, nearest objective/bearing,
   public own-team progress and a beginner approach/C instruction. Avoid claims
   of local capture; show co-op context only when publicly supplied.
3. Exercise actual decoded lifecycle transitions and queue neutralization in new
   contracts, plus geometric bearings and missing-state fallback. Run existing
   world18, commands27 and economy contracts.
4. Two bounded native graphical scenarios (each <=100s, including a fresh
   baseline and updated launch): 960×640 PvP and 1280×800 co-op. Use ordinary
   public PORT=0 servers, private Xvfb (-nolisten tcp/unix), isolated XDG and
   ordinary XTest input. Capture/open fresh before/after PNGs and record hashes,
   commands, public-wire/trace evidence and cleanup. No natural REINFORCE rerun.

Runtime and report/test commits will be separate. No agents, merges, publication,
source changes, shared hooks or aggregate edits; no full strategy-round claim.
