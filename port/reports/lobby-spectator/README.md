# Native active-room spectator follow-up

Scoped follow-up to `12e770ddbcc0befb74e95b7154cfc0ab55b6812b`, on isolated
`review/lobby-independent`. Lead owns launch/package integration. This report
supersedes the earlier active-spectator OPEN finding only for the validated
ordinary active-room join path described below.

## Runtime and review boundary

- `f92b0ef09217f900e37724a3e35c757d2d9f107a`: essential network notice handling,
  read-only session state/control gates, and opt-in lobby spectator status.
- `de6f9f9`: spectator-only status-panel height correction found by PNG review.
- `2752139249295fb789a04f288660ee57e38f11d5`: initial context/scene tests and live driver.
- `47cd78d`: text-containment regression, observer and offline correlation audit.

Runtime changes are confined to `godot/net/client.gd`, `godot/world/session.gd`,
and `godot/ui/lobby_menu.gd`. The two runtime commits are separate from tests and
evidence. Source/Node, other standalone runtimes, shared launcher, package hooks,
root documentation and gallery are untouched. No merge/push/deploy or shared
service restart was performed. The absent original worktree/prunable record was
not recreated or pruned.

### Exact informational-notice boundary

Source research: `server/room.mjs:940–965` computes active play from
`started && !roundOver && match`, converts an ordinary fresh join into a spectator,
and sends, in order:

1. `welcome`, with protocol 3, room/peer identity, `host:false`, `spectate:true`;
2. complete `lobby` roster (schema at `room.mjs:836–839`), with connected self,
   `spectate:true`, and `actorId:null`;
3. exactly `{type:"error", message:"Match in progress — you joined as a spectator."}`;
4. `start`, then full authoritative `snapshot` (initial unassigned ACK key `-1`).

The client accepts that exact two-field error once only when:

- an explicit ordinary `join_room` was successfully queued;
- the immediately following matching-room welcome has a valid nonnegative integer
  peer ID, protocol 3, boolean spectator/host flags and no reconnect designation;
- the immediately following complete, duplicate-free roster contains the same peer,
  connected and spectating, with an explicitly present null actor;
- room/map match the request; map/mode are allowlisted; `started:true`, positive
  integer round revision, lifecycle `live`, and a valid different host ID establish
  the active-join context.

The allowance is consumed by the notice or invalidated by intervening frames,
failure, round reset or disconnect. Text substrings, added error fields/codes,
duplicate/late notices, absent/wrong identity, malformed flags/assignments,
non-active rosters, full-room and spectator-limit errors, version errors and map
substitutions stay fatal. Existing partial ordinary-player/replay envelopes remain
supported; the extra full context is required specifically for this exception.

`server/room.mjs:993–1025` excludes spectators from player assignment on restart.
The native connection therefore retains its spectator identity across results
and starts; a roster attempting promotion on that same connection fails closed.
Only explicit Leave plus a fresh join can request a player seat. Token resumption,
automatic promotion and guaranteed playing rejoin are not claimed.

### Read-only session behavior

Authoritative snapshots still pass through watchdog observation, pickup/combat
state application, visual actor creation and remote interpolation. Spectators
retain actor ID `-1`, no local actor/pose, zero input sequence and zero local ACK;
the inherited ACK-owner guard never adopts `-1`. The session returns before local
camera reseeding and before the input send loop, including neutral inputs.
Network guards reject input/create/join/config/start while spectating, and pointer
capture and restart eligibility remain false. Tab scoreboard and explicit Leave
remain usable. Results are rendered normally, labelled as spectator results.

The minimal view keeps the camera at its existing position/orientation on entry
(the former player viewpoint for this Leave/rejoin case; initial viewer position
for a newly opened viewer). It stays fixed through restart. All actors are remote;
there is no follow/free-fly camera. Visibility from this fixed view is limited by
ordinary world occlusion. Stale-receive diagnostics remain visible rather than
becoming a missing-player error.

## Regression evidence

- `context-old.log`: real old decoder at `12e770d` accepts the synthetic welcome/
  roster and fails the specific informational-notice assertion (2 checks, 1 failure).
  This is fresh offline old-fail proof; the old live failure was not repeated.
- `final-checks/context-new.log`: 66 context/protocol checks pass, including exact
  sequencing, negative/error cases, ACK sentinel, restart persistence and fresh-join
  assignment after explicit disconnect.
- `final-checks/spectator-ui.log`: 31 checks pass using the actual instantiated
  session/widgets and engine input, stored snapshot/results frames and synthetic
  transport. Covers no capture/input, spectator UI, watchdog, scoreboard/results,
  restart, Leave cleanup and detail-text containment at both resolutions.
- `final-checks/checks.json`: all 24 executions pass: context, lobby, envelopes,
  replay, input queue, control safety, focus/stall/recovery, round/local lifecycle,
  guest session, HUD, scoreboard, geometry at both sizes, weapon selection, zone,
  Lattice world/commands, combined-arms and sports gates. 3,294 numbered checks,
  plus two unnumbered HUD/scoreboard scene fixtures and a 3,616-frame replay.
- `checks-supplement.json`: objective controls (11) and renderer (19) also pass;
  observer parse checks pass. Thus 3,324 numbered checks across the final suite and
  objective supplements; earlier repeated suites are not added to that total.

Earlier local parse failures are preserved in `client-parse-initial.log`,
`context-parse-initial.log`, and `flow-parse-initial.log`. The first broad invocation
also timed out while loading the dependent envelopes script; `subprocess.run`
killed/reaped that process and the private temporary environment was removed.
The missing explicit `bool` annotation was fixed before runtime commit/live use.
The first successful suite remains in the report root; final results are separate.

## Fresh bounded native scenarios

Exactly two purposeful runs, no seed retries or source-state/timing edits. Both use
ordinary two-client Meridian TDM create/join/start with two source-normal bots and
60-second rounds. Gameplay/UI actions use `Input.parse_input_event`; focus/resize
use Window APIs. These are engine-input results, not physical/OS-input acceptance.

1. `active-spectator/`: first protocol/lifecycle run at `2752139`, 80.149 seconds.
   Active guest Leave/rejoin became a connected spectator, rendered state, received
   natural results and host restart, and finally left explicitly. Live helper
   assertions passed, but manual PNG inspection found the second status line
   outside its panel. Preserve this as **protocol/lifecycle PASS, visual PARTIAL**;
   the original helper summary is intentionally unchanged.
2. `active-spectator-layout/`: final run at `47cd78d`, **79.616 seconds**, same scenario with the status
   containment fix and additional passive layout receipts. This is the final UI
   acceptance evidence; see `audit.json` for timing, counts and source/native matches.

`lobby_audit.py` correlates each observed native actor-ingest pose with that exact
recipient/round/sequence source snapshot, checks real interpolated visual movement,
and measures living source displacement and shot growth during held-input bursts.
Receipts and ACKs alone are not gameplay proof. It also checks exact source handshake,
spectator-only `join`/`leave` traffic, restart identity, fixed camera, status/controls,
layout, cleanup and byte-identical prior evidence.

The audit passed **313 assertions**, matching **7,853 native actor-application
frames** across both runs. The final run matched 2,014 host and 1,906 guest frames;
1,776 guest applications were on the spectator connection. That connection sent
exactly one `join` and one `leave`, with zero inputs/config/start requests.
Natural results arrived at source time `60.01666666666454` (58.833 seconds of wall
time from authoritative start). Host living displacement/shot growth during the
input bursts was 16.558m/15 in round one and 15.340m/15 in round two; spectator
visual displacement of that host was 16.385m and 16.226m respectively. These use
slightly different sampling windows for source application and delayed renderer
poses; no displacement is inferred from ACKs.

### Final screenshots

- [960×640 active spectator](active-spectator-layout/12-spectator-960.png)
- [1280×800 moving-state spectator](active-spectator-layout/11-spectator-moving-1280.png)
- [960×640 Tab scoreboard](active-spectator-layout/13-spectator-scoreboard-960.png)
- [960×640 spectator results](active-spectator-layout/14-spectator-results-960.png)
- [1280×800 spectator results](active-spectator-layout/15-spectator-results-1280.png)
- [Same spectator after host restart](active-spectator-layout/16-spectator-restarted.png)

All six linked final PNGs were opened and visually reviewed. Both status lines
are contained; the spectator heading replaces missing-player messaging; Leave,
status and scoreboard panels are separate. The fixed view shows the map and
remote actors, with no local equipment/control prompts. The earlier four reviewed
active/results PNGs remain archived with their status-panel overflow.

## Isolation, cleanup and reproduction

Pinned Godot: `4.5.2.stable.official.6ce3de25a`, binary
`/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`.
Locked source: `51289b79c627a26a381ba556b92bab71f93f3732`. Primary `node_modules`
is a read-only dependency input. Each run owns its loopback port selected via
`listen(0)`, private HOME/XDG and Xvfb (`-nolisten tcp -nolisten unix`).
Both authorities close with zero sockets, owned children are reaped, temporary
directories removed and former ports closed. Port 4332 remains under Node PID
1094444; no requests/kills/restarts targeted it. Hashes are in `provenance.json`.

From the worktree root, offline checks (new output directories protect prior runs):

```sh
python3 port/reports/lobby-spectator/lobby_checks.py --out /tmp/opencode/lobby-spectator-checks-review
python3 port/reports/lobby-spectator/lobby_audit.py
```

The bounded live helper accepts an explicit **new** output directory:

```sh
node port/reports/lobby-spectator/lobby_live.mjs /tmp/opencode/lobby-spectator-live-review
```

No further live runs were performed in this lane after the two archived scenarios.
Package/common-launch acceptance remains OPEN with lead. Campaign remains deferred.
