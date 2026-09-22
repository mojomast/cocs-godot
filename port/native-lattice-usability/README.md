# LATTICE world player-feedback delivery

**Runtime:** `dfe7432` on baseline `e1defc00e37c0b560ff9fa55f1e3c4ad9f853b21`.
Isolated worktree `/tmp/opencode/lattice-usability`, branch
`agent/lattice-usability`. [Pre-implementation audit/plan](PLAN.md).

## Delivered

- Backed, wrapping world HUD with explicit **ENGAGED / RELEASED**, focus,
  stale/missing state, death/respawn, waiting, results and stopped feedback.
  Refresh follows the existing per-frame control handling, so Escape/focus
  feedback does not wait for a source snapshot. Recovery asks for released
  controls and a fresh click; results identifies Enter; errors retain their reason.
- Readable PvP / Co-op Operations names and a first approach target, bearing and
  planar range. Prefer the nearest **public live non-owned** objective; fall back
  to the known nearest node. This is an exploration hint, not a route or a claim
  that capture is legal for this team at that position.
- Public node owner/activity/own-team progress, own resources, and available
  co-op wave/phase/window fields. Missing fields remain **unknown**. HOLD receipts
  remain explicitly separate from node capture. No local contribution is inferred.
- HUD yields its space while tactical commands are open. Existing command,
  co-op consent, purchase and receipt behavior is preserved. ACK stays available
  in native diagnostics and the existing panel's explanation.

Owned runtime files: `godot/lattice/world_demo.gd`, `world_hud.gd`, and new
`world_guidance.gd` (+ UID). No shared input/session/client, board, economy,
source, launcher, package or aggregate changes.

## Tests

Pinned Godot **4.5.2.stable.official.6ce3de25a**, headless targeted contracts:

| Suite | Result | Evidence |
|---|---:|---|
| New usability | **24 / 24** | [log](tests/usability_contract.log) |
| Existing world | **18 / 18** | [log](tests/world_contract.log) |
| Existing world commands | **27 / 27** | [log](tests/world_commands_contract.log) |
| Existing economy | **91 / 91** | [log](tests/economy.log) |

Usability tests decode actual recipient frames through the existing transport;
exercise startup, focus, stale, death/zero timer/healthy respawn, recipient loss,
results and disconnect; inspect the same-adapter neutral queue; verify 20 actual
camera-basis bearings; test public target selection/retargeting/fallback and
unknown fields. Confirmed HOLD and executor lease changes cannot alter the
displayed public ownership/progress. These are fixtures, not live authority wins.

The first new test run exposed startup being labelled stale before any actor
arrived. State-priority ordering was corrected; the [initial failure](tests/usability_contract-initial-failure.log)
is retained. Final contracts above pass. Semantic export/source verification,
[Godot import](tests/import.log), and `git diff --check` also passed.

Re-run targeted contracts from this worktree:

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
"$GODOT_BIN" --headless --path godot --script res://tests/lattice/usability_contract.gd
"$GODOT_BIN" --headless --path godot --script res://tests/lattice/world_contract.gd
"$GODOT_BIN" --headless --path godot --script res://tests/lattice/world_commands_contract.gd
"$GODOT_BIN" --headless --path godot --script res://tests/lattice/economy.gd
python3 -B port/native-lattice-usability/analyze.py
```

## Two bounded native graphical scenarios

**33 fresh raw PNGs were directly opened with an image-capable tool.** This is
agent inspection with ordinary XTest input, not human playtesting or an exported
package acceptance. Each scenario includes a fresh baseline launch and revised
launch, on separate ordinary public servers. No timing/rules/source-state writes.

| Scenario | Duration including both launches/cleanup | Coverage |
|---|---:|---|
| Asterion PvP, 960×640 | **22.26 s** | Initial HUD revision: released → click/W engaged → C while moving → HOLD → one Fighter purchase → close/released → held-W click blocked → fresh click engaged → focus lost/return → Escape |
| Monsoon co-op, 1280×800 then 960×640 | **28.60 s** | **Final runtime:** same primary control flow and HOLD, closed recruitment gate; then final-build small-window layout/panel/close/focus samples |

Both main flows pass [recorded checks](analysis.json). The read-only
[analyzer](analyze.py) checks actual X11 focus/pointer grabs and held W, native
labels, source movement, neutral input persistence and stationary public poses
after panel close and focus loss, explicit action/card matching, source/file
hashes, scenario bounds and cleanup. The observer runs before node processing,
so a transition record can precede the next frame's label/layout update; it is
not a claim that every intermediate observer record is a settled render.

### Visual links and observed outcomes

**Final runtime / Monsoon:**

- Fresh baseline [released](evidence/1280x800/before/01-released.png),
  [engaged](evidence/1280x800/before/02-engaged.png),
  [Escape](evidence/1280x800/before/03-escape.png): identical LIVE/resume copy.
- Revised [released](evidence/1280x800/after/01-released.png) and
  [engaged](evidence/1280x800/after/02-engaged.png): readable backed state and
  WEST / FILTER COURT approach cue, rather than own inactive headquarters.
- [C panel](evidence/1280x800/after/03-commands.png) and
  [HOLD receipt](evidence/1280x800/after/04-hold-receipt.png): `confirmed — replaced`
  for explicitly selected `hq-0`; co-op REINFORCE remains disabled with the
  between-wave-window explanation. **This receipt does not prove node capture.**
- [Close](evidence/1280x800/after/06-close-released.png),
  [held-key click blocked](evidence/1280x800/after/07-held-key-click-blocked.png),
  [fresh click](evidence/1280x800/after/08-fresh-click-engaged.png): public node
  progress reads 48%, 62%, 80% while the local actor stays roughly 51 m away.
  Public WEST / FILTER COURT ownership later changes to Team 0; guidance then
  targets NORTH / INTAKE. No local-capture attribution is made.
- [Unfocused](evidence/1280x800/after/09-focus-lost.png),
  [returned](evidence/1280x800/after/10-focus-return-released.png),
  [Escape](evidence/1280x800/after/11-escape-released.png): explicit RELEASED and
  fresh-click instructions; objective advice is hidden while unfocused.
- Final runtime at 960×640:
  [released](evidence/1280x800/after/12-small-released.png),
  [panel](evidence/1280x800/after/14-small-commands.png),
  [closed](evidence/1280x800/after/15-small-close-released.png),
  [unfocused](evidence/1280x800/after/16-small-focus-lost.png),
  [returned](evidence/1280x800/after/17-small-focus-return.png).
  World HUD occupies 590×252 px; panel is 700×590 px and fits the viewport.

**Initial HUD iteration / Asterion at 960×640:**
[before](evidence/960x640/before/01-released.png),
[released](evidence/960x640/after/01-released.png),
[fresh-click engaged](evidence/960x640/after/08-fresh-click-engaged.png),
[unfocused](evidence/960x640/after/09-focus-lost.png).
[Purchase](evidence/960x640/after/05-purchase-receipt.png) shows matching confirmed
Fighter receipt and source spent **12 FLUX**, with consumed consent and both
receipts readable. Main control flow passed. That iteration still suggested own
inactive HQ; only `world_hud.gd` approach selection changed before scenario two.
The first scenario is **not** labelled exact-final-runtime evidence.

### Preserved sample limitation

The extra resized-window click in scenario two retained Python default arguments
`(1220,730)` from the earlier 1280×800 size, outside the new 960×640 window.
Consequently [13-small-engaged.png](evidence/1280x800/after/13-small-engaged.png)
actually says **RELEASED**. `actions.json` confirms pointer child 0 and no capture.
The later small-window focus sample also starts released. No final-build
960×640 fresh-click engagement PASS is asserted from that supplement; the
initial 960×640 and final 1280×800 primary engagements did pass. The original
runner is retained exactly, including this bounded-helper limitation. No third
scenario was launched.

## Provenance and cleanup

- Locked source **51289b79c627a26a381ba556b92bab71f93f3732**; source verification
  runs before every launch. The same three inspected source-file hashes are
  rechecked after play. Exact commands, runtime and observer hashes, owned PIDs,
  ports and source hashes are in each `before/manifest.json` and
  `after/manifest.json`; [provenance](provenance.json) records final delivery inputs.
- Baseline is a private copy of this imported Godot project with `world_demo.gd`
  and `world_hud.gd` restored byte-for-byte from `e1defc0`. The copied new helper
  exists but is unused by the baseline scene. Same passive observer, native
  binary and ordinary `createGameServer({historyPath:null,progressionPath:null})`.
- `PORT=0`, loopback only, default simulation timing; private Xvfb
  `-nolisten tcp -nolisten unix`, screen 1600×1000, explicit native window sizes,
  isolated disposable XDG. Dummy audio was explicitly selected. No shared
  desktop, shared port, editor interaction, camera teleport or injected gameplay
  events. The observer reads scene state; all gameplay input uses ordinary XTest.
- All four launchers/native clients and both Xvfb processes are absent, all
  four ports are closed, XDG directories removed. Receipts are under each
  scenario's `before/cleanup.json`, `after/cleanup.json`, and `scenario.json`.
  Ports: **39181, 44483, 33177, 46507**.
- Per-scenario `sha256.json` covers all raw PNGs/logs/manifests/actions/cleanup.
  All recorded hashes verified. No native script errors in the sampled runs.

To reproduce in a fresh output directory, prepare/import the baseline copy as
above, then run `sample.py --baseline=<copy> --width=960` and `--width=1280` with
the pinned `GODOT_BIN`. The helper refuses an existing scenario directory and
has a 95-second alarm. It preserves the resize-click limitation described above.

## Remaining human questions / scope limits

1. Does the compact status/goal wording let a new player recover from Escape
   and focus loss without coaching? Is a planar Ahead/Left/Right cue sufficient
   around the authored buildings, or is a later waypoint needed?
2. Is 590×252 px acceptable HUD coverage at 960×640? Would control-reference
   details be better on demand? Keyboard-only and accessibility review is open.
3. Are public node progress and command receipts sufficiently distinct to a
   player, especially when bots/orders can progress a distant objective?

No full strategy round, co-op mission completion, natural REINFORCE window,
local node capture, multiplayer campaign, human usability, audio, hardware or
Wayland acceptance is claimed. Existing natural REINFORCE evidence was not rerun.
Lifecycle edge cases beyond the sampled focus/release paths have contract
coverage here, not new live death/results/disconnect footage.
