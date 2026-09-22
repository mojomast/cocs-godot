# Independent multiplayer-lobby review

**Partial live acceptance with strong retained Ember/Rockets evidence.** The
delivered lobby works through two-player play, natural results and host-only
restart in the bounded Ember attempt. A compact-HUD overlap is confirmed at
both requested resolutions. Neither live helper exit is represented as PASS.

## Baseline and integration

- Primary HEAD used: `df66fc6b6e66b429ae5673e9a1b323e1b95d068d` (already includes
  delivered zone and combined-arms runtime).
- Delivered commit: `3b9620639b2903bcccac953c123f9b9e0350b1a9`.
- Runtime cherry-pick: `2e93cfd5325a64b3f9a42ad5a58d8a6d47f2de51`.
- New worktree/branch: `/tmp/opencode/lobby-independent`,
  `review/lobby-independent`.
- Initial independent helpers / Meridian execution HEAD:
  `0c9207698b251efbb6db89a8836899ac3aad3920`.
- Corrected popup driver / Ember execution HEAD:
  `37f0b9eee53d51511cfe9d8e904433aa6162e568`.
- Locked source: `51289b79c627a26a381ba556b92bab71f93f3732`.
- Pinned engine: `4.5.2.stable.official.6ce3de25a`, binary
  `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`.

Cherry-picking produced only a file-location conflict: Git suggested placing
the new launcher in `port/native-ci/launch.py` because of prior directory
history. Resolution preserved the delivered path
`port/native-multiplayer-lobby/launch.py` and its unchanged contents. The seven
runtime-delivery files otherwise applied cleanly. The independent commits add
only this report directory and new `lobby_independent_*` tests/observers.

The absent `/tmp/opencode/cocs-native-multiplayer-lobby` worktree and its
prunable record were not altered, recreated or pruned. Missing original
acceptance tools/HANDOFF were not reconstructed as historical evidence.
Reported historical 46/33/73/physical runs are **not** verified here; the 33
lobby checks below are a fresh execution of the committed synthetic test.

## Findings and exact unapplied fix

### 1. Medium UI integration defect: Leave obscures frags/deaths

`godot/ui/lobby_menu.gd:102–103` places Leave at `(width-150,12)` while
`godot/ui/game_hud.gd:283–285,318–324` reserves the same top-right HUD region.
Leave is shown while uncaptured in gameplay/results (`lobby_menu.gd:123–126`).
It overlaps the frags/deaths text at both **960×640** and **1280×800**.

Failed read-only geometry reproduction on the actual native scene:

| Viewport | Leave rect | Score-label rect | Exit |
|---|---|---|---|
| 960×640 | `(810,12,107,31)` | `(704,28,220,20)` | 1 |
| 1280×800 | `(1130,12,107,31)` | `(1024,28,220,20)` | 1 |

The disconnected geometry probe reads the future button rect without making
it visible or changing session state. The actual visible overlap is separately
confirmed in the live [host gameplay](ember-crucible/07-host-gameplay.png),
[guest gameplay](ember-crucible/08-guest-gameplay.png), and results PNGs.

### 2. Low UI integration defect: compact HUD remains behind lobby

`godot/ui/game_hud.gd:149–153` suppresses only setup phase `-2`, not new lobby
phases. The top HUD is visible around and partially underneath the opaque menu
in disconnected and waiting states. This makes map/mode text visibly clipped
at the panel edges. The real disconnected geometry probe reports
`disconnected_hud_visible:true`; both initial-size screenshots show it.

[`lobby-ui.UNAPPLIED.patch`](lobby-ui.UNAPPLIED.patch) supplies the exact minimal
two-file change: move Leave/Restart below the compact top bar and suppress the
compact HUD while the lobby panel owns the screen. `git apply --check` succeeds.
**It was not applied or visually verified after application.** The captured
runtime remains exactly the delivered cherry-pick plus the primary baseline.

## Two bounded live scenarios

No seed selection/retries, time acceleration, source edits, direct UI-handler
calls, session-authority writes or extra live scenarios were used. Runtime
widgets receive ordinary `Input.parse_input_event` mouse/key events. Window
focus uses Godot's `Window.grab_focus`. This is **engine-input graphical
acceptance, not OS/XTest or physical keyboard/mouse acceptance**.

### 1. Meridian / Team Deathmatch — 21.501 seconds, partial

Host created room `ETYC`, source echoed the requested map/mode and the host
waited for explicit Start. Both native menu sizes were captured.

The independent driver opened the role dropdown by mouse, then sent one Down
and Enter. The popup initially has focused index `-1`; the first Down selects
Host, not Guest. The second window therefore remained a host and created a
separate room. The helper timed out waiting for guest phase 11 and reaped both
clients/display/server. This is a **driver failure**, not a guest emitting host
requests. No Meridian gameplay, guest join or results is claimed.

A disconnected graphical-only probe diagnosed this and verified the corrected
two-Down sequence before the Ember scenario. An intermediate commentary
suspected the numeric key code; the retained probe showed that suspicion was
wrong (`KEY_DOWN=4194322`). The popup initial focus was the cause.

### 2. Ember / Rocket Arena — 81.254 seconds, partial

Room `8WXE`, host 960×640 and guest 1280×800, ordinary 2 bots and source-normal
60-second round. Map/mode were CLI-prefilled in the visible form; role, name,
room, Create/Join, Leave/Rejoin, Start and Restart used widget input.

Verified from retained source wire and native application records:

- Host created/configured exactly once, waited in phase 12 and issued Start
  only after the guest explicitly joined, left and rejoined the waiting lobby.
- Authority roster showed both names, host identity and matching Ember map.
- Guest first connection sent exactly `join, leave`; rejoin connection sent
  exactly `join` plus inputs. **Neither guest connection sent create/host/start.**
- Explicit lobby Leave cleared room/peer/actor, pose, actors and pickup markers;
  the disconnected observation interval had no automatic reconnect. Explicit
  Join made a new connection. Text-entry room settings intentionally remained.
- Both clients captured with a fresh click, moved and fired. The audit checks
  living movement within the actual received movement/fire burst, not respawn
  displacement or ACK high-water alone.
- Both reached results at source time **60.01666666666454s**; source start to
  results wall time **59.437s**. Both released capture and became ineligible.
- Guest Enter did not restart and its restart button was hidden. Host clicked
  Restart; both received the second authoritative start uncaptured. Host then
  freshly captured and produced new source-applied shots.

| Evidence | Host | Guest |
|---|---:|---:|
| Round-1 source snapshots | 1,800 | 1,800 |
| Round-1 received inputs | 1,651 | 1,891 |
| Movement+fire inputs within burst | 54 | 44 |
| Living movement during burst | 8.631m | 10.349m |
| Actual round-1 shots | 3 | 3 |
| Native applications matched to source, both rounds | 1,986 | 1,984 |
| Round-1 ACK high-water, receipt only | 1,649 | 1,889 |

After the restart exercise, the helper's generic scrolled-panel bounds rule
rejected the *overlay* Leave button's legitimate `y=12` location. It stopped
**before** clicking final in-match Leave. This is a second **helper failure**;
active-match Leave cleanup is not independently live-verified. The original
summary remains `PARTIAL/FAIL`. The final helper distinguishes overlay bounds,
but that correction has **not** been live-rerun under the two-scenario budget.

[`lobby_audit.py`](lobby_audit.py) independently replays both raw gzip archives,
checks their original hashes, matches source/native poses, health, shots,
camera x/z and recipient ACKs, and verifies role boundaries, actual shot
growth and living movement. Its **15,917 assertions** pass for these retained
facts; they do not upgrade either live exit or imply 15,917 distinct test cases.
See [`audit.json`](audit.json). The wire witness observes recipient sends and
received requests; it does not mutate authority state. ACKs are not treated as
proof that any individual coalesced input was applied.

## Screenshots directly opened

Actual PNGs were opened with the image reader, not inferred from logs:

- [Meridian menu 960×640](meridian-exchange/01-host-menu-960x640.png)
  and [1280×800](meridian-exchange/02-guest-menu-1280x800.png).
- [Meridian host waiting/code](meridian-exchange/03-host-created.png).
- [Ember host code/waiting](ember-crucible/03-host-created.png),
  [guest roster](ember-crucible/04-guest-roster.png),
  [guest explicitly left](ember-crucible/05-guest-left.png).
- [Ember host started](ember-crucible/06-host-start.png),
  [host gameplay 960×640](ember-crucible/07-host-gameplay.png),
  [guest gameplay 1280×800](ember-crucible/08-guest-gameplay.png).
- [Host results](ember-crucible/09-host-results.png),
  [guest results](ember-crucible/10-guest-results.png),
  [restart initially uncaptured](ember-crucible/11-host-restarted.png),
  [after restarted capture/movement exercise](ember-crucible/12-host-fresh-capture.png).

The gameplay helper releases with Escape before each gameplay screenshot, so
`12-host-fresh-capture.png` depicts the **subsequent paused state**, not a captured
pointer. Fresh capture is proven by native samples and source-applied inputs.
Scoreboards, names and waiting/restart messages are readable at both sizes.
At 960×640 the lobby becomes scrollable when roster/status expand; the real
host Start action successfully used that scrollable layout.

## Focused checks and inherited boundaries

Fresh passing checks (retained adjacent logs):

| Suite | Count |
|---|---:|
| committed `lobby_flow.gd` | 33 |
| `control_safety.gd` | 2,497 |
| `window_focus.gd` / `stall_controls.gd` | 7 / 12 |
| `session_recovery.gd` / `round_boundaries.gd` | 52 / 34 |
| `local_lifecycle.gd` / `guest_session.gd` | 15 / 10 |
| `native_trace.gd` / `input_queue.gd` | 28 / 46 |
| `envelopes.gd` / `match_selection.gd` | 95 / 95 |
| `weapon_selection.gd`, private graphical display | 64 |
| zone unit / world contract / world commands | 42 / 18 / 27 |
| combined-arms controls | 43 |
| real-scene compact HUD / scoreboard fixtures | both PASS; no printed count |
| source room/rooms/spectator/network/resilience suites | 87 tests |
| current zone routing | 3 tests |
| disconnected role-dropdown input probe | PASS |

The numbered Godot suites total **3,118 checks**, plus the two unnumbered
HUD/scoreboard fixtures. Node suites total **90 tests**. These are focused
checks, not the repository's complete test/build gate.

The initial general checker incorrectly invoked `match_selection_menu.gd`
without its `--setup`/live-authority prerequisites, and `weapon_selection.gd`
headlessly. Both failures are retained in `checks.json` and their original
logs. Weapon selection was rerun correctly and passed; match-selection's full
existing graphical/live scenario was not rerun because it would be an
additional live scenario. The final checker omits these inappropriate headless
invocations. Disconnected popup diagnosis failures are also retained. Initial
headless layout probes produced a 64×64 dummy viewport despite CLI resolution;
those non-evidence logs remain alongside the proper graphical reproductions.
Graphical runs emitted the software-renderer VSync warning; successful runtime
captures did not emit script errors.

Review points:

- `session.gd:17–23,83–89,185–190` gates host start/restart by current validated
  roster, connected/non-spectator status and non-guest intent. Guest join does
  not configure the source. `client.gd:140–151` validates expected map and binds
  actor identity from the full roster; `session.gd:378–382` adopts host mode.
- `session.gd:25–55` releases pointer, disconnects, clears round state and
  child `clear_round` hooks. `client.gd:41–49` replaces the WebSocketPeer and
  clears identity. No automatic reconnection path was added.
- `session.gd:209,240,279–297,324,362–371` confines waiting-room phase handling
  to opt-in `--lobby-menu`. Default and specialized sessions leave
  `lobby_enabled=false`.
- `zone_modes/demo.gd:15–74` and `lattice/world_demo.gd:18–82` override startup
  and keep standalone host behavior; they do not use the infantry lobby menu.
  Their inherited session gates remain active. World transport's
  `reset_round` (`lattice/transport.gd:37–42`) still clears recipient projection,
  revision and consent. Current zone/world/combined controls checks passed.
  This review does not claim live zone/world lobby support or expand the
  three-map/four-mode infantry menu allowlist.

## Reproduction, cleanup and residual gaps

From this worktree, with the same pinned binary and a read-only dependency
symlink to primary `node_modules` (no install occurred):

```sh
python3 port/reports/multiplayer-lobby-independent/lobby_checks.py
python3 port/reports/multiplayer-lobby-independent/lobby_graphical_check.py
python3 port/reports/multiplayer-lobby-independent/lobby_graphical_check.py --layout-only
python3 port/reports/multiplayer-lobby-independent/lobby_audit.py
```

The layout reproduction is expected to exit 1 on this unchanged runtime.
For a **new isolated checkout**, the live commands are
`node port/reports/multiplayer-lobby-independent/lobby_acceptance.mjs` and the
same with `--ember`. The runner refuses existing scenario output directories;
do not overwrite these original failures/archives. Its final overlay-bounds
fix is a future reproduction improvement, not additional evidence here.

Both live scenarios owned `server.listen(0,'127.0.0.1')`, private Xvfb launched
with `-nolisten tcp -nolisten unix`, and private HOME/data/config/cache/runtime
directories. Six live children were reaped and absent: Meridian
`3286192/3286196/3286828`; Ember `3315335/3315360/3315926`. Both authorities closed
with zero sockets. The audit independently confirmed refused loopback
connections on former ports **36563** and **40393**. All owned runtime temporary
directories were removed. Synthetic graphical displays were separately reaped;
their receipts are in the graphical-check JSON files. The worktree and ignored
semantic/import/dependency setup remain inspectable. Generated untracked UID
files outside this lane were not included in commits.

`provenance.json` records runtime/generated-content/binary hashes and the
evidence inventory. The runtime/source/shared launcher/package/aggregate/root
documentation were not edited by the independent commits. No original
worktree record was pruned; no merge, push, deploy or gallery update occurred.

Residual gaps: complete Meridian TDM play, final **active-match** Leave cleanup,
active-room spectator rejoin, guest fresh capture after restart, OS/physical
input, live zone/world/combined regression scenarios, packaged launcher flow,
and patched-layout visual acceptance. Campaign remains deferred. The missing
original external acceptance helpers remain a separate delivery question.
