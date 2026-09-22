# Acceptance and focused handoff

## Final verified state

Base: `6116f12` (isolated `/tmp/opencode/world-commands-6116f12`, branch `agent/world-commands`).

Pinned gameplay source: **`51289b79c627a26a381ba556b92bab71f93f3732`**.
Godot: **`4.5.2.stable.official.6ce3de25a`**.
Unchanged LATTICE transport SHA-256, equal to `642c615`:
`d914d981c792362896f9bc6ae7480d40e754f74e337c721cab606b6c041eb783`.

Final suite: [`evidence/1790048434326221550/results.json`](evidence/1790048434326221550/results.json), **8/8 cases passed**:

| Case | Result |
|---|---|
| Semantic generation/source validation | PASS |
| Pinned Godot import | PASS |
| Existing world contract | 18 checks, 0 failures |
| New command boundary/consent contract | 27 checks, 0 failures |
| Asterion PvP, 960×640 command panel | 25 native checks, 11 wire/audit checks; PASS |
| Monsoon co-op, 1280×800 command panel | 20 native checks, 11 conditional wire/audit checks; PASS |
| Existing Asterion traversal observer | 17 native + 8 wire checks; 57.298 m displacement, 0.198 m final approach |
| Existing Monsoon traversal observer | 17 native + 8 wire checks; 59.101 m displacement, 2.101 m final approach |

The co-op economy audit means **no economy request was emitted while unavailable**; its source-unit-delta check is inapplicable and passes conditionally. No new live co-op recruitment is claimed. Both old observers still issue zero commands. No capture or strategy win is claimed.

## Exact command witnesses

### Asterion / PvP

Evidence: [`commands-small`](evidence/1790048434326221550/commands-small/).
Single connection: peer **1**, actor **0**, round **1**, ordinary two-bot host.

- Overlay open: input sequence **14**, observed ACK high-water **12**, snapshot **40**.
- Explicit HOLD request: `native-r1-p1-s1`, action sequence **1**, `front-0`.
- Source recipient event: `cocs-order`, event **23**, source time **2.267**, tick **135**, verb **HOLD**, same card ID, WEST / ARCHIVE GATE.
- The native receipt at snapshot **68** is **pending (server accepted)**. This is an executed order submission, not a completed objective.
- Before explicit purchase: snapshot **92**, `spent=0`, `spawned=0`.
- Fighter request: `native-r1-p1-s2`, action sequence **2**. Exactly one economy frame despite two purchase clicks.
- Source recipient event: `cocs-role-spawn`, event **25**, source time **3.25**, actor **3**, role **fighter**, cost **12**.
- After purchase: snapshot **98**, **confirmed** card, `spent=12`, `spawned=1`. The passive wire audit matches those exact snapshot sequences, verifies the new source actor was absent before and present after, and checks the source spawn event.
- Resume-click boundary: input sequence **100**, ACK high-water **98**. Every recorded input from the open boundary through this pre-click boundary is neutral, including fire and all action flags, with no weapon field.

The later source `ATTACK` event is the ordinary AI chief's separate order (`chief-0`, card `0-225`), not a second native command. Source order events use their own internal `peerId` representation (`"0"` here); socket actor ownership and matching native card IDs establish provenance without equating those two ID fields.

### Monsoon / co-op

Evidence: [`commands-large`](evidence/1790048434326221550/commands-large/).
Single connection: peer **1**, actor **0**, round **1**, ordinary two-bot host.

- Overlay open: input sequence **13**, ACK high-water **11**, snapshot **41**.
- Explicit HOLD request: `native-r1-p1-s1`, action sequence **1**, `front-0`.
- Source recipient event: `cocs-order`, event **27**, source time **2.383**, tick **142**, WEST / FILTER COURT, matching HOLD card.
- Native receipt at snapshot **72**: **pending (server accepted)**.
- Snapshot **96** reports wave **1**, phase **build_up**, recruitment `open=false`, sink cost **50**, available/affordable true, enabled false. UI displays the transport's exact reason: **Wait for the between-wave recruitment window**. Consent and purchase are disabled. Zero economy frames.
- Resume-click boundary: input sequence **78**, ACK high-water **77**; open-panel input interval is neutral.

The separate fixture supplies a labelled authorized intermission projection to test consent loss on lease change and one-shot routing through the unchanged `activate("reinforce")` adapter. It is not an ordinary-match recruit witness.

## Controls and boundary coverage

Live tests use native `Input.parse_input_event` mouse/key events to open C while W/fire are held, select a list item, issue HOLD twice, authorize/purchase twice, close while W is held, attempt recapture with a held mouse button, release all controls, and make a fresh click. The same actor subsequently moves through the original movement path. Opening and selecting emit no command; UI clicks do not recapture/fire into the world. Disconnect clears actions/projection/selection/consent/control eligibility.

The new detached fixture separately exercises focus loss/return, immediate neutral input, stale pose, authoritative death, actor reassignment, absent recipient projection, results, disconnect, hidden-panel activation, no optimistic budget/unit updates, and co-op lease invalidation. It substitutes only the outbound queue, and never counts as live evidence.

Movement ACK is consistently reported as a **high-water receipt**, separate from source order execution, confirmed purchase receipts, and source unit/spending deltas. No claim is made that every input below an ACK was individually applied. Logs contain recipient-visible actors, public objectives/events, own-team budget keys, and own-actor wallet data; no enemy wallet is read or recorded.

## Direct screenshot review

Opened and read both final PNGs directly:

- [960×640 Asterion commands](evidence/1790048434326221550/commands-small/commands.png): complete backed panel fits within the viewport; objective list scrolls; own resources, 12-FLUX consent, action receipts, and high-water wording are legible. The post-purchase screenshot correctly shows cooldown-disabled controls and consumed consent.
- [1280×800 Monsoon commands](evidence/1790048434326221550/commands-large/commands.png): centered panel, public WEST / FILTER COURT selection, accepted HOLD receipt, and readable 50-FLUX closed-window explanation.

Both runs also save `reopened.png`, showing fresh empty selection/consent with retained transport receipts. Traversal evidence includes the existing startup/walk/released PNGs and exact recipient camera/actor checks.

## Retained failures and cleanup

- `attempt-01-small`: first live attempt failed because this new worktree lacked ignored generated semantic assets. The catalog error, failed readiness check, manifest, result, and cleanup are retained. Running the existing semantic exporter resolved the environment issue.
- `attempt-02-small`, `attempt-03-large`: successful initial overlay witnesses. The final suite adds explicit held-mouse release coverage, exact purchase-to-wire snapshot correlation, and source actor-delta auditing.
- `contract-01.log`: first command boundary fixture, 27/27 passed.
- `regression-asterion`: successful initial old-observer regression, before the final expanded release-key list. The final suite reruns both old observers against final runtime hashes.

Final ordinary ephemeral ports were **46535**, **46423**, **32873**, and **36185**. Each case records `httpClosed=true`, `nativeExited=true`, `runtimeRemoved=true`. All graphical wrappers completed normally with private Xvfb `-screen 0 1400x1000x24 -nolisten tcp -nolisten unix`. An afterward process inspection found no remaining Xvfb with this owned invocation profile; unrelated Xpra/other agents' displays were left alone.

## Integration handoff

One focused commit, no push or merge. Runtime changes are the new `world_commands.gd` and the narrow existing `world_demo.gd` integration; the three label/observer names and world HUD helper remain compatible. New tests, verifier, runner, documentation, and all attempts live in the assigned paths. Generated objective-test UIDs from import are untracked and excluded from the commit.

The lead's `--experience=lattice-world` routing can continue targeting the same scene. The new owned `--play` runner also has no interactive deadline. The shared 62-gate/launcher integration remains the lead's work; this task runs the owned eight-case suite rather than altering that shared gate. This add-on README supersedes the base world's earlier “no command widget” description for the new overlay.
