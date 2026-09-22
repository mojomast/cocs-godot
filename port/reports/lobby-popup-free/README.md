# Popup-free native lobby selectors

**PASS: scoped popup-free release lobby and bounded full two-client flow, including
clean engine logs.** Final integrated package/common-launch acceptance remains
lead-owned; other menus' popup issues remain OPEN.

Runtime delivery: **`9a816ff`**. New test/export-observer/flow helpers:
**`f212a8c`**. This lane replaces only the three lobby selectors; the previous
release-popup failure evidence remains immutable.

## Runtime contract and scope

`godot/ui/lobby_choice.gd` (+ UID) is a small Godot `HBoxContainer` containing
native **Previous / current value (index/count) / Next** controls. It never creates
an OptionButton, PopupMenu or popup Window. The label area is keyboard-focusable
with a theme focus outline; native Previous/Next buttons retain their own focus
outlines and ordinary Enter/Space activation. Left/Right cycle while the row or
either button has focus. Tab/Shift-Tab use normal Godot focus traversal.

The compatible lobby API is `add_item`, `clear`, `select`, `selected`, `item_count`,
`text`, item metadata setters/getters and `get_selected_metadata`, plus
`item_selected(index)`. Programmatic selection stays silent. Actual button/key
selection emits once. Empty/single-item choices are inert and disabled controls
cannot cycle. Selection wraps, and the index/count makes the cycling affordance
explicit.

`godot/ui/lobby_menu.gd` changes only the three constructors/type constraint and
enables the existing scroll container's `follow_focus`. Existing map-change mode
rebuilding, guest mode disabling, room-field eligibility and connected-state
disabling remain in that menu. No network/session/gameplay handlers, engine or
project settings, source authority, other menus, package tools or common launcher
were changed. No engine signal filtering or error suppression was added.

This is a **lobby-local workaround for the proven release engine popup defect**.
Combat setup and board popup issues remain OPEN. It is not a global engine repair
or acceptance of the final integrated lead package.

## Verification

### Offline regressions

[final-checks/checks.json](final-checks/checks.json): **25 executions passed**,
totalling **3,357 numbered checks**, plus unnumbered HUD/scoreboard scene fixtures
and the 3,616-frame protocol replay. Includes existing lobby geometry at 960×640
and 1280×800, context/spectator lifecycle, envelopes, input queues, control/focus/
stall/recovery, HUD, scoreboard, weapon selection and specialized-scene gates.

The new [lobby_popup_free.gd](../../../godot/tests/protocol/lobby_popup_free.gd)
passes **63 actual-scene checks**: silent API selection, native mouse/key selection,
focus and Tab order, signal counts, map/mode rebuilding, repeated wraparound,
Escape, disabled states, both-size geometry and absence of lobby popup nodes or
parent callbacks. Its connected phase is an explicit synthetic fixture.

The first offline execution is preserved in `checks/`: it found that forwarding
all child GUI events moved focus from a clicked button to the row (two assertions).
The runtime now forwards only key events from the buttons. The final suite passes;
no failing capture was overwritten.

### New private release artifact

Built by the existing, unchanged `tools/godot-package/build.py`:

```sh
python3 tools/godot-package/build.py \
  --state /tmp/opencode/lobby-popup-free-package \
  --archive-directory /tmp/opencode/lead-native-linux-package/toolchain
```

Build execution used a private temporary HOME/runtime directory; the builder owns
its staged project and XDG directories. Cached official archives were read as
inputs, with the builder's normal official checksums. No final lead artifact was
edited. [build-result.json](build-result.json) locates this focused artifact:

`/tmp/opencode/lobby-popup-free-package/builds/1790055896590242802/cocs-native-linux`

| Artifact | SHA-256 |
|---|---|
| Manifest | `14fb45cdf63030a6f1ee0545cb4afe6ccc1cc0daa04aca8d067bbc9900cc5b07` |
| PCK | `49eb359b24c85bf20f258c8a2523cb7d170ab8b4256fff4d759c7e8d886afc8e` |
| Official release executable | `3c0994716982c2f557f7738a789269074520ac0c0a3f11bb7a84a34ee96c683d` |
| Archive | `03c796a44b8754661cf0b0b919e83dffd033898a367fba826f6a8ba707cdd8f5` |

The release executable is byte-identical to the one that exhibited the old popup
defect. It reports `4.5.2.stable.official.6ce3de25a`. The new PCK contains the exact
committed inline control/menu input bytes and excludes test fixtures. This
worktree's older common routes and unrelated runtime baseline are intentionally
not promoted to lead's final package; lead must integrate the narrow runtime
commit and rebuild there.

### Two purposeful release runs

Both instantiate the real `res://world/session.tscn` from the new PCK via an
external observer. Ordinary UI/gameplay uses `Input.parse_input_event`; Window
APIs manage the private test windows. These are engine-input results, not physical
or OS-input acceptance. No widget selection APIs, emitted widget signals or
direct gameplay calls are used by the observer/flow.

1. [targeted/summary.json](targeted/summary.json): **PASS**, 23.378 seconds,
   **22 assertions**, zero engine errors. Role/map/mode cycling and repeat,
   Left/Right, Tab/Enter, focus, Escape, disabled guest mode and both resolutions.
   Zero lobby popup nodes in every sample; parent signal counts stay constant.
   The packaged authority is idle: no room or simulation messages were sent.
2. [full-flow/summary.json](full-flow/summary.json): **PASS**, 93.792 seconds,
   **82 assertions**, zero engine errors. Ordinary two-client Create /
   Join, real map/mode controls, roster/Start, movement/fire, active Leave and
   spectator rejoin. Spectator receives ongoing state through natural 60-second
   results, then explicitly leaves. A fresh post-results guest joins before host
   restart and freshly captures controls for round two. Final explicit Leaves
   clean up both clients. Zero lobby popup nodes and stable parent signal counts
   throughout. Natural source results time is `60.01666666666454`, reached after
   59.104 seconds of source start-to-results wall time.

The spectator's results connection and the fresh playing guest are different
connections. This flow does not promote the spectator on restart and does not
claim token resumption. Prior same-connection spectator-through-restart evidence
remains in the earlier spectator report; this package flow does not repeat that
different sequence.

### Direct PNG review

- [1280×800 row focus outline](targeted/04-focus-outline-1280.png)
- [960×640 row focus outline](targeted/05-focus-outline-960.png)
- [1280×800 disabled guest mode](targeted/03-guest-disabled-1280.png)
- [960×640 full-flow host results](full-flow/12-host-results-960x640.png)
- [1280×800 full-flow host results](full-flow/13-host-results-1280x800.png)
- [1280×800 active spectator](full-flow/11-active-rejoin-spectator.png)
- [1280×800 fresh guest recaptured after restart](full-flow/16-guest-fresh-recapture-captured.png)
- [1280×800 connected/disabled selectors and roster](full-flow/04-guest-roster.png)

These PNGs were opened directly. The focus outline, selected value/count and both
cycling buttons are visible and separate; disabled mode is visibly dimmed. No
popup is hidden behind the inline control.
The linked full-flow PNGs were also opened: Leave/Restart, HUD and scoreboards
remain separated at both sizes, the spectator is explicitly read-only, and the
fresh playing guest has the regular equipment HUD. `hud-caption-review.png` is a
2× nearest-neighbor crop of the host results header (original bounds 20,16–540,60),
used to confirm the visible Team Deathmatch caption; the full PNG is unchanged.

## External observer/flow API for lead

Use [lobby_export_observer.gd](lobby_export_observer.gd) with `--main-pack PCK
--script ABSOLUTE_OBSERVER -- --lobby-menu --map=... --mode=...
--endpoint=ws://127.0.0.1:OWNED_PORT --lobby-inbox=ABSOLUTE_JSON
--lobby-out=NEW_DIRECTORY`. It instantiates the real product child scene. No
observer script is placed in the PCK.

The inbox is an atomically replaced JSON object with increasing `id`, optional
`stage`, and an operation:

- `focus` (only when needed by default), `resize {width,height}`;
- `key {key,pressed,ctrl?,shift?}`; keys include Left/Right/Tab/Enter/Escape/W/A;
- `mouse {x,y,pressed,button?}`; `text {text}`; `capture {name}`.

`LOBBY_SAMPLE` exposes `ui.role/maps/modes` with `selected`, `items`, `disabled`,
`focused`, and distinct `role_previous`, `role_current_label`, `role_next`
(likewise maps/modes) with actual rectangles/focus state. The new flow clicks
those child-button rectangles and records target bounds plus viewport alongside
each click. There is **no `get_popup`, `popup_visible`, or `popup_focused` API**.
Historical OptionButton observers remain unchanged and are intentionally
incompatible with the new selector shape.

`EXPORT_WITNESS` records command/stage/time, choices, lobby popup count and root
connections. Raw stderr is retained and separately timestamped with current
command/latest UI. `LOBBY_APPLIED` records recipient/round/sequence/local actor,
camera and remote visual ingest/rendered positions for source correlation.

Lead can use the new flow against its own rebuilt artifact without editing shared
tools in this lane:

```sh
node port/reports/lobby-popup-free/lobby_live.mjs targeted BUILD-RESULT.json NEW-OUTPUT
node port/reports/lobby-popup-free/lobby_live.mjs full BUILD-RESULT.json NEW-OUTPUT
```

Existing output directories are refused. The two authorized live runs here are
the only ones performed; no seed retries or source-state/timing changes.

## Audit, isolation and remaining gates

[lobby_audit.py](lobby_audit.py) checks click bounds, no popups/callback accumulation,
raw clean logs, every native visual application against its exact recipient
source snapshot, real living displacement/shot growth, spectator rendered
movement, authoritative clock/results, cleanup and immutable prior reports.
Receipts/ACKs alone are never used as gameplay application proof.

The audit passes **176 assertions** and matches **3,847 native visual/application
frames** to source snapshots (host 1,992; guest 1,855), including **1,469 spectator
applications**. The spectator wire traffic is exactly one `join` and one `leave`;
the subsequent fresh guest is a distinct connection. Measured source effects:

| Burst | Living displacement | Shot growth |
|---|---:|---:|
| Host round one | 18.815m | 16 |
| Original guest | 17.644m | 16 |
| Host while guest spectates | 17.620m | 15 |
| Fresh guest after host restart | 19.819m | 15 |

The spectator's delayed renderer shows 17.784m of host displacement during its
corresponding observation window. Source and interpolated-renderer windows differ
slightly. Dead intervals reset the living-distance origin rather than counting
respawn displacement as movement.

Owned SIGTERM interrupted the last `LOBBY_SAMPLE` stdout write from each of the
four native processes. These four final partial JSON lines remain in the raw
archives and are explicitly hashed/listed in `audit.json`; they are not counted
as valid samples. The audit initially stopped on the partial line, then was
updated to allow only a final unterminated native stdout record. Interior malformed
records remain failures, and the entire raw logs are still scanned for errors.

Both runs use unchanged packaged 84-module authority + ws, loopback `listen(0)`,
private Xvfb with `-nolisten tcp -nolisten unix` and isolated HOME/XDG. All 111
manifested package files are verified before/after play; no unmanifested package
files may appear. Private artifact files remain available for lead inspection.
All six live child processes are reaped; authorities have zero sockets, private
temporary environments are removed and former ports **46495/45237** refuse
connections. Protected port **4332** remains under original Node PID **1094444**.
No existing service is targeted. Generic/common-launch/final-package integration
remains lead-owned; other menus' popup defects remain OPEN.

Offline reproduction (new directory for checks):

```sh
python3 port/reports/lobby-popup-free/lobby_checks.py --out /tmp/opencode/lobby-popup-free-review-checks
python3 port/reports/lobby-popup-free/lobby_audit.py
```
