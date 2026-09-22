# Lobby UI fix and fresh follow-up acceptance

**PASS for the authorized layout fixes and bounded lobby lifecycle checks.**
Meridian TDM now has fresh two-client movement/fire, active-match Leave,
natural results, host-only restart and fresh guest-capture evidence.
**Native active-room spectator rejoin remains OPEN**, as does **package**
verification. The former is a reproduced pre-existing session/client limitation,
outside the two-file UI change. This is not blanket acceptance of that path.

## Commits and scope

- Follow-up base: `0cc3b8e30095afe98816ea3a8143b84261ee7fce`.
- Original primary baseline: `df66fc6b6e66b429ae5673e9a1b323e1b95d068d`.
- Existing private runtime delivery: `3b9620639b2903bcccac953c123f9b9e0350b1a9`,
  previously cherry-picked as `2e93cfd5325a64b3f9a42ad5a58d8a6d47f2de51`.
- **UI fix commit:** `f7626397a142e44409e5d2466eb506bb8ae419ac`.
- **New helper/check commit and live execution HEAD:**
  `c8c1513059972adf31b2e453903f16401fac2a1a`.
- Final evidence/report commit is separate; see the delivery response/branch log.
- Worktree: `/tmp/opencode/lobby-independent`, branch `review/lobby-independent`.
- Pinned Godot: `4.5.2.stable.official.6ce3de25a`; locked source:
  `51289b79c627a26a381ba556b92bab71f93f3732`.

Only `godot/ui/lobby_menu.gd` and `godot/ui/game_hud.gd` changed in runtime.
New tests use the `lobby_followup_` prefix; all new evidence is in this directory.
The previous failed/partial captures, original helper versions and old review
report remain byte-for-byte preserved, verified against their original hash
inventory. No source/session/client/match-setup/launcher/package/CI changes
were made. No merge, push, shared restart or subagents occurred.

## Implemented layout fixes

1. `godot/ui/lobby_menu.gd:102–103`: Leave at `y=70`, Restart at `y=112`, below
   the compact top HUD. Both remain within the viewport and beside the status
   panel; neither overlaps the other or the scoreboard.
2. `godot/ui/game_hud.gd:152–154`: hide the compact HUD while the opt-in lobby
   panel owns the screen. Gameplay, results and starting-round phases
   `[3,4,20]` retain the HUD. Existing non-lobby setup and debug overrides retain
   their behavior.

The new actual-scene regression instantiates `world/session.tscn` with the
shipped HUD, scoreboard and lobby. It uses explicitly synthetic phases/stored
frames for deterministic visibility checks and actual Control rectangles for
collision checks. It covers disconnected/error/handshake/waiting phases,
starting, playing, captured pointer, Tab scoreboard, host/guest results,
non-lobby connecting, setup and debug HUD. **No source-text matching.**

| Native viewport | Leave rect | Restart rect | Compact top rect | Checks |
|---|---|---|---|---:|
| 960×640 | `(810,70,107,31)` | `(810,112,116,31)` | `(20,16,920,44)` | 75/75 |
| 1280×800 | `(1130,70,107,31)` | `(1130,112,116,31)` | `(20,16,1240,44)` | 75/75 |

Both real results layouts were also captured during the live Meridian round,
including its team-score scoreboard. The host window was resized through
Godot's Window API after natural results to inspect the same actual results
state at both sizes. No match state was modified for these screenshots.

## Purposeful live run 1: Meridian TDM

**79.903s wall duration**, one attempt, room `MV8D`, ordinary 2 bots and 60-second
time limit. Host at 960×640; guest at 1280×800. No source-state writes, seed
selection/retries or timing changes. The following sequence is archived:

1. Host explicitly created/configured the room. Source roster/code/map/mode
   echoed correctly; no automatic Start.
2. Guest role selection read the actual popup's focused item before Enter,
   avoiding the previous driver's wrong-role assumption. Guest explicitly
   joined with the expected Meridian map. Both authoritative names appeared.
3. Host explicitly started. Both living actors freshly captured, moved and
   fired through ordinary Godot input events. The guest opened the real
   scoreboard with Tab.
4. Guest explicitly clicked **Leave match while the round was active**.
   Room/peer/actor, pose, local entities/pickups, ACK/input sequence and capture
   cleared. No auto-reconnection occurred during the bounded observation.
   Source removed the peer and converted the departed actor to a BOT, as its
   normal room lifecycle specifies.
5. Guest explicitly tried to rejoin while active. Source assigned a spectator,
   but its informational error notice triggered the native fatal-error path.
   The native client left/disconnected cleanly; no automatic retry or controls
   followed. This reproduced the OPEN limitation described below.
6. Host reached natural source results at **60.01666666666454s**, with source
   start-to-results wall time **59.266s**. Actual host results at 960×640 and
   1280×800 show separate readable Leave/Restart, HUD/status and scoreboard.
7. Guest explicitly joined **after results**, when the authority accepts a new
   player. Guest waited for the host and Enter emitted no Start.
8. Host clicked Restart. Both received authoritative revision 2 uncaptured.
   Guest freshly captured, moved and fired with source-applied effects.
9. Guest and then host explicitly left the restarted active round. Both cleared
   state and stayed disconnected without automatic reconnection.

The post-results guest is a **new explicit connection**, not a resumed token or
an automatically promoted spectator. No guest connection sent create/config
(`host`)/start requests. Host sent one create, one configuration and two starts.

### Source effects, distinguished from receipt/ACK evidence

| Observation | Host, round 1 | Guest, round 1 | Guest, restarted round |
|---|---:|---:|---:|
| Received input frames | 1,757 | 226 | 113 |
| Received simultaneous move/fire frames | 57 | 51 | 54 |
| Living displacement within input burst | 16.886m | 16.480m | 16.431m |
| Source shot-counter growth within burst | 15 | 15 | 15 |
| Max shots during native connection | 18 | 17 | 17 |
| Source snapshots in the connection/round | 1,800 | 244 | 117 |
| ACK high-water, receipt evidence only | 1,755 | 226 | 113 |

The offline audit matches source-recipient snapshots against native-applied
pose, health, dead state, shots, camera x/z and ACK. It restricts displacement
and shot growth to the active input burst while alive, rather than counting a
respawn or subsequent BOT action as human movement. No target-hit/kill claim
is inferred from these fire checks.

## OPEN: active-room spectator rejoin

Reproduction: guest joins a waiting room, host starts, guest uses Leave match,
then guest explicitly rejoins the still-running room.

- `server/room.mjs:940–958` sets `spectate:true` for an active-room player join
  and sends `type:error`, message “Match in progress — you joined as a spectator.”
- `godot/net/client.gd:185–186` routes that frame to `fail`; `:60–64` emits a
  connection error and closes the connection.
- `godot/world/session.gd:340–355` clears/leaves the lobby on that error.

Captured recipient 2 has `welcome.spectate:true`, an unassigned actor, the error
notice, then an explicit native Leave. It emits **zero input frames**. The native
UI displays both the spectator notice and “No active room,” rather than an
active spectator view. See [actual failure PNG](meridian-tdm/11-active-rejoin-error.png).

The two-file layout fix does not change this protocol behavior. Supporting
active spectator viewing requires a separately authorized protocol/session
change that distinguishes the validated spectator notice from fatal errors,
plus new acceptance. The lobby's existing waiting text currently advertises
more active-join support than this native path delivers.

## Purposeful live run 2: Ember startup/layout

**14.449s wall duration**, one attempt, room `YLJ4`. Fresh two-client menu,
authoritative roster, explicit Start, ordinary Rocket Arena loadouts and local
pose application passed. Patched HUD/menu/gameplay layouts were inspected at
960×640 and 1280×800. Both clients explicitly left the active match and cleared
state without automatic reconnection. No second full Ember round was run.

The source witness records host `create,host,start,input,leave` and guest
`join,input,leave`; the guest issued no authority requests.

## Fresh checks and evidence audit

All **18 regression executions passed**: **3,040 numbered checks** plus four
unnumbered real-scene HUD/scoreboard checks.

| Suite | Checks |
|---|---:|
| committed lobby flow | 33 |
| control safety | 2,497 |
| window focus / stall controls | 7 / 12 |
| session recovery / round boundaries | 52 / 34 |
| local lifecycle / guest session | 15 / 10 |
| input queue / envelopes | 46 / 95 |
| scoreboard | 25 |
| graphical weapon selection | 64 |
| new actual-scene geometry, both sizes | 75 + 75 |
| HUD normal/setup/debug and scoreboard-session | four PASS, no printed counts |

Exact commands/exit statuses and private-display cleanup are in `checks.json`.
The live helpers additionally passed **71 Meridian** and **22 Ember** assertions.
The independent offline audit passed **208 assertions** and verified **2,431
native/source snapshot applications**: Meridian host 1,966 / guest 359, Ember
host 79 / guest 27. These application comparisons are data checks, not thousands
of distinct test scenarios. `audit.json` retains the exact counters and roles.

The only graphical warning was the software-renderer VSync warning; no native
script errors occurred. Existing earlier failed headless/incomplete attempts
remain in their original report directory, with their original status.

## Fresh PNGs directly opened

- Meridian [960 menu](meridian-tdm/01-host-menu-960x640.png) and
  [1280 menu](meridian-tdm/02-guest-menu-1280x800.png): no HUD leaking around menu.
- [Authoritative guest roster](meridian-tdm/04-guest-roster.png).
- [Paused gameplay 960](meridian-tdm/07-host-play-paused.png) and
  [live Tab scoreboard 1280](meridian-tdm/09-guest-scoreboard.png): Leave clear of
  scores, status and scoreboard.
- [Active guest Leave](meridian-tdm/10-guest-active-leave.png) and
  [final active host Leave](meridian-tdm/18-host-final-active-leave.png): cleared
  lobby UI, compact HUD hidden.
- Actual natural [results 960](meridian-tdm/12-host-results-960x640.png) and
  [results 1280](meridian-tdm/13-host-results-1280x800.png): Leave/Restart and all
  results panels separately readable, no overlap.
- [Restart initially uncaptured](meridian-tdm/15-guest-restarted-uncaptured.png)
  and [guest freshly captured](meridian-tdm/16-guest-fresh-recapture-captured.png).
- Ember [960 menu](ember-startup/01-host-menu-960x640.png),
  [1280 menu](ember-startup/02-guest-menu-1280x800.png),
  [960 started](ember-startup/05-host-start.png) and
  [1280 started](ember-startup/06-guest-start.png).

These are actual engine-rendered PNGs opened with the image reader. Input was
`Input.parse_input_event`, not OS/XTest or physical keyboard/mouse input.
Window focus/resize used Godot Window APIs. All runtime widget/session handlers
were entered through normal event dispatch in the live runs. Synthetic geometry
fixtures are explicitly separate from live source effects.

## Reproduction, provenance and cleanup

From this isolated checkout with generated locked semantic content and the
existing read-only primary `node_modules` symlink:

```sh
python3 port/reports/lobby-followup/lobby_checks.py
python3 port/reports/lobby-followup/lobby_audit.py
```

For a new isolated checkout/output directory only (the live helper refuses
existing output directories):

```sh
node port/reports/lobby-followup/lobby_live.mjs
node port/reports/lobby-followup/lobby_live.mjs --ember-startup
```

Exactly two fresh live scenarios were used; both were under 180s. Each owned
`server.listen(0,'127.0.0.1')`, private Xvfb with `-nolisten tcp -nolisten unix`,
and isolated HOME/XDG data/config/cache/runtime directories. All owned live
processes were reaped and absent:

- Meridian: `3461392` Xvfb, `3461395` host, `3461854` guest.
- Ember: `3472160` Xvfb, `3472163` host, `3472805` guest.

Both authorities closed with zero sockets; former ports **35469** and **38415**
refused connections during the independent audit. Temporary runtime trees were
removed. Synthetic test subprocesses were reaped by their bounded runner and
its private Xvfb cleanup is recorded in `checks.json`.

**Protected port 4332 was preserved:** passive listener inspection before/after
the Ember follow-up showed the same Node PID **1094444** listening on
`127.0.0.1:4332`. No requests, kills or restarts targeted it.

`provenance.json` records runtime, helper, generated-content, engine and evidence
hashes. Runtime drift is checked against the separate UI fix commit. Old
evidence hashes are checked against the earlier inventory, without rewriting
it. The isolated worktree/ignored imports remain inspectable; unrelated
generated UID files are not included in commits.

Remaining OPEN items: native active spectator viewing; package/common-launch
integration (owned by lead); OS/physical-input acceptance. Campaign remains
deferred. Prior historical run claims remain outside this fresh acceptance.
