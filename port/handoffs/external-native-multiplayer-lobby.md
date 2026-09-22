# External single-agent task: native multiplayer lobby and return flow

## Project and execution model

Repository: **https://github.com/mojomast/cocs-godot** (public).
Published baseline: **`8094d410fd576911f39712f91c7dc2bfc2d5d80a`**, branch `main`.
Shared-machine lead checkout:
`/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port`,
branch `port/godot-destinations`.

Create your own branch and isolated worktree from that baseline. On this machine
use a NEW directory under `/tmp/opencode/`; on another machine clone the public
repository with history. Do not work in the lead's checkout.

**Work alone and sequentially. Your harness does not need subagents.** Perform
the discovery lanes yourself, synthesize findings before coding, then implement
and verify each stage. Do not delegate or wait for discovery agents.

## Goal

Deliver an opt-in **native multiplayer lobby** that makes the current infantry
client usable by two people without editing command-line room IDs:

1. Host connects to an explicit endpoint, chooses a supported map/mode, creates
   a room and sees a shareable room code and authoritative player roster.
2. Guest enters endpoint, room code and expected map; joins and sees the same
   roster/configuration while waiting for the host.
3. Host explicitly presses Start. Both clients enter the existing native match.
4. Either player can deliberately leave for the lobby UI. Errors have actionable
   retry/back controls, without restarting Godot or silently reconnecting.
5. Results and host restart retain correct host/guest permissions and require
   fresh pointer capture. Repeated connect/leave cycles do not accumulate nodes,
   signal connections, input state or old actor identities.

Current CLI host/guest transport works, but host setup connects/configures/starts
immediately and does not provide a usable waiting-room workflow. Preserve that
existing default behavior and add a separate **`--lobby-menu`** flow. Do not
replace the proven `--setup` path or broaden enabled maps/modes in this task.

## Ownership — reserved for you

Own:

- NEW `godot/ui/lobby_menu.gd`, optional scene/helper files with `lobby_` prefix.
- Narrow integration in `godot/world/session.gd` and, if necessary,
  `godot/world/session.tscn`.
- Narrow `godot/net/client.gd` change ONLY if essential for a backward-compatible
  player-name parameter or lobby integration hook. Do not rewrite the decoder,
  weaken validation, add reconnect tokens or change wire semantics.
- NEW `godot/tests/protocol/lobby_*.gd`.
- NEW `port/native-multiplayer-lobby/` for launcher, acceptance helpers, docs,
  retained evidence and handoff.

Do not edit `godot/ui/match_setup.gd`, `godot/ui/game_hud.gd`, scoreboard,
combat/weapon modules, source `game/` or `server/`, exporters, contracts,
dependencies, root docs or shared launcher/verifier. Import/reuse the setup
capability validator rather than copying its enabled-map/mode lists.

Other agents own sports progression (`godot/sports/`), LATTICE UI/physical input
(`godot/lattice/board.gd`), objective gameplay (`godot/objectives/`) and projectile
acceptance tools. Pulse-preview assets remain reserved. Stay out of those paths.
If a shared launcher flag is useful, include an exact **unapplied** patch in your
handoff for the lead. Your own launcher may supply `--lobby-menu` to the scene.

## Phase 1 — inspect, then synthesize

Read applicable local instructions and relevant files fully:

- `README.md`, `port/README.md`, `port/RELEASE_MATRIX.md`.
- `godot/net/client.gd`, `godot/world/session.gd`, `session.tscn`.
- `godot/ui/match_setup.gd`, `game_hud.gd`, `scoreboard.gd`.
- `godot/tests/protocol/guest_session.gd`, `session_recovery.gd`,
  `round_boundaries.gd`, `control_safety.gd`, `match_selection_menu.gd`.
- `port/guest-session/` if present; locate the current guest integration tools
  and evidence rather than assuming the directory name.
- `server/game-server.mjs`, `server/room.mjs`, `game/protocol.mjs` and relevant
  server room/join/start tests.

Investigate three lanes in sequence:

1. Exact create/join/lobby/start/results/error schemas, authority and host
   identity, when actor assignment becomes valid, joining active rooms, and
   actual room/host behavior when a peer disconnects.
2. Current session phase machine, cleanup and view ownership, pointer/weapon
   release, HUD/scoreboard bindings, CLI contracts and test fixture assumptions.
3. Usable 960×640/1280×800 layout and physical input routing for endpoint/name/
   room fields, roster, host Start, guest waiting and error recovery.

Before editing, write a brief discovery/implementation plan with source file
references, exact allowed paths and state transitions. Do not invent host
privileges or server lifecycle semantics. Keep the existing authoritative map
allowlist; a guest's expected map must not silently change to a substituted map.

## Phase 2 — implement the lobby

- Endpoint, player display name and room ID fields; Host/Join choices; legal
  host map/mode controls; explicit Connect/Create/Join and Start buttons.
- Clear disconnected, connecting, configuring, lobby, waiting, starting, active,
  results and error presentation. Authoritative roster identifies local player,
  host and assigned/spectator status only where the source proves them.
- Show room code and endpoint for sharing. A Copy room code button is optional;
  avoid OS clipboard dependency in automated acceptance.
- Host may start only when ordinary source permissions permit. Guests never
  send host/config/start messages. Reject unsupported selected configurations
  before starting; preserve all nine locked choices as pending where displayed.
- Keyboard traversal/activation and mouse input must both work. Text entry must
  not move/fire the infantry actor. Status/errors must fit or scroll at both
  resolutions. Keep normal compact HUD/scoreboard behavior after entering play.
- While waiting, no interactive gameplay input. No automatic reconnect, replay
  of old commands or reuse of a departed actor's identity.
- Use ordinary WebSocket frames. Display server failures faithfully but do not
  log welcome tokens, credentials or raw private transport frames as evidence.

## Phase 3 — leave, retry and repeated rounds

Use a clear UI affordance for Leave after pointer release; Escape's existing
release behavior must remain usable. Returning to the lobby closes the current
connection and clears presentation, projectiles, pickups, controls, pending
weapon requests, actor assignment and obsolete session callbacks. Keep world
loading/node ownership bounded. Do not free and recreate shared modules without
checking HUD/scoreboard signal rebinding and cleanup.

Retry is explicit, starts a fresh connection and respects the same validation.
Late frames from an abandoned attempt must not populate the new lobby/session.
Results preserve host-only restart; guest remains waiting. Server restart or
disconnect cannot result in a locally fabricated round or successful join.
Do not add token reattachment or automatic host migration in this slice; report
actual server behavior and provide manual recovery if required.

## Phase 4 — verification

Environment on the shared machine:

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules
export TMPDIR=/tmp/opencode
export PORT=0
node tools/godot-export/semantic.mjs
"$GODOT_BIN" --headless --path godot --editor --import
python3 tools/godot-dev/verify.py
git diff --check
git status --short
```

Use the pinned Godot on other machines and set dependency paths to that checkout.
Do not install or modify the lead's dependencies. Full baseline is 46 gates.

Add meaningful focused regressions for new transitions: guests cannot start,
invalid room/endpoint, expected-map mismatch, stale callback isolation, leave
while waiting/playing, results/restart, repeated cycles, no active inputs while
typing, proper cleanup and fresh capture. Synthetic fixtures must be labeled.

Required normal-rate live acceptance on an owned loopback source server:

1. Two real native clients use physical mouse/keyboard events through the actual
   new UI: host Create → guest Join → both see roster → host Start → both observe
   their own authoritative actor and native movement/fire.
2. Prove the guest submitted no create/config/start commands. Correlate queued
   input, received packets, ACK high-water and observed movement/fire separately.
3. Guest leaves, explicitly joins again and regains a valid fresh assignment;
   at least three connect/leave cycles stay bounded. Follow actual server rules
   for active-round join; if unsupported, demonstrate rejoin in a fresh lobby.
4. Invalid room fails visibly; correcting it and explicitly retrying succeeds.
5. A normal legal short time-limit round reaches real results; host starts the
   next round and both clients require fresh capture. No forced results or
   accelerated ticks. Keep the full live run bounded and report uncovered cases.

Test at least TDM and Rocket Arena across two combat maps, without running an
unnecessary full map cross-product. Cover 960×640 and 1280×800. Preserve failed
attempts and fix diagnosed issues before targeted reruns.

Use newly owned private Xvfb displays, never the shared desktop. Linux command:
`Xvfb -displayfd <fd> -screen 0 1280x800x24 -nolisten tcp -nolisten unix`.
Validate readiness and use independent windows/clients. Rebuild/import after
changes; restart only your owned demo processes. Stop/reap children and verify
owned servers/sockets/display cleanup. No source state injection, teleporting,
timing-rule edits, fabricated screenshots or recording-completion inference.

## Phase 5 — documentation, manual review and delivery

Directly inspect screenshots of host lobby, guest waiting, active match, results
and error/retry. If image tools are unavailable, state review pending and give
paths. Screenshots are not a substitute for physical-input acceptance.

Write `port/native-multiplayer-lobby/HANDOFF.md` with exact launch commands,
two-person manual flow, source findings, integration API/phase changes, old CLI
compatibility, test results, source/runtime hashes, evidence paths, failed
attempts and remaining limitations. State when own processes were rebuilt,
restarted and cleaned up. Reference gallery: `http://100.125.104.79:43595/`;
leave that service untouched. Native gameplay is not a browser-playable URL.

Commit only owned files in attributable units. **Do not push, merge primary,
rewrite history, restart shared services or remove worktrees.** Return ordered
commit hashes, branch/worktree/base, concise behavior/results and any minimal
unapplied shared-launcher patch. The lead performs integration and publication.
