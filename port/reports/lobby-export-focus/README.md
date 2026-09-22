# Exported lobby focus-error triage — HOLD full package play

**Verdict: HOLD clean-log/full exported package-play acceptance.** The release
executable reproduces embedded `PopupMenu` signal-cleanup errors during ordinary
selection/dismissal. Focus-only-when-needed did not resolve them. The pinned debug
engine, loading the **same unchanged production PCK** with the same external
observer and identical 72-command sequence, produced zero errors and correctly
removed the popup callbacks. Generic package-startup acceptance remains a separate
lead-owned gate.

This isolated lane adds only this report directory, helpers and evidence. Runtime,
`tools/godot-package/*`, shared launcher, primary reports and the packaged artifact
were not modified. No merge/push/deploy, agents, shared restart or additional full
gameplay execution was performed.

Helper/audit commit: `c3a9067`. Both fresh executions used the isolated worktree
baseline `e9ed72f`; the new helpers were uncommitted during capture. The same
observer was used in both. Between runs, only runner support for selecting the
debug executable, recording its hash and correcting the module-count metric was
added. The 72 UI actions and observer behavior were unchanged.

## Findings and attribution

The original lead run at
`/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/port/reports/linux-lobby-play-independent`
remains byte-identical. Its 93.605-second execution reached all 22 milestones but
failed `no native script errors`. Guest stderr contains two nonexistent-disconnect
errors for root `focus_entered` and `tree_exited`; host stderr contains only the
VSync-driver warning. Its stderr had no per-command timestamps, so exact timing of
that original pair cannot be recovered. All saved summary/actions/wire/native
records were read directly from primary. See [lead-failure-inspection.json](lead-failure-inspection.json).

Fresh targeted release evidence supplies the missing timing:

| Command | UI operation / policy | Release error lines |
|---|---|---:|
| 22 | Enter selects Guest in first role popup; old unconditional-focus policy | 2 nonexistent disconnects |
| 34 | Reopen role popup; redundant focus skipped | 2 already-connected errors |
| 38 | Enter selects Host; needed-only focus policy | 2 nonexistent disconnects |
| 52 | Enter confirms map popup; needed-only focus policy | 2 nonexistent disconnects |
| 61 | Enter confirms mode popup; needed-only focus policy | 2 nonexistent disconnects |
| 65 | Reopen role popup before deliberate focus probe | 2 already-connected errors |
| 68 | Escape dismisses popup after deliberate redundant root focus | 2 nonexistent disconnects |

No error was emitted on a `focus` command. The first pair is at receipt wall time
`1790054872431`, command 22, while the observed role popup is embedded/visible with
focused index 1. Root signal lists still contain that popup's valid callbacks after
`popup_hide`. Subsequent map and mode hides leave their callbacks too: final
`tree_exited` callback count is **3**. Debug returns to **0 after every hide**.
Release's `focus_entered` count similarly grows to 5 (two baseline observers plus
three retained popup callbacks); debug returns to its baseline count of 2.

**Supported attribution:** a release-engine/build-specific embedded-popup
connection identity/cleanup failure on this artifact. Normal role/map/mode
interaction reaches the engine defect. The observed error is not fixed by simply
removing redundant harness focus calls, and a normal-looking screen is not clean
engine acceptance. This agrees with the earlier unresolved popup errors in
`29b0a59`'s combat/board usability recordings, which used OS input; those older
recordings are supporting history, not new reproductions here.

**Not established:** the precise C++/compiler reason why the release disconnect
does not match the registered callback. Debug/release processing timings differ,
and this is one paired scenario, not a general proof across all builds or displays.
No speculative production UI or engine patch is supplied. A guarded
`is_connected()` around disconnect would not establish a fix for the retained
connections and later duplicate-connect errors.

### Source basis

[engine-source-excerpts.json](engine-source-excerpts.json) records exact upstream
4.5.2-stable URLs, full downloaded-file hashes, original line ranges and excerpts:

- `scene/gui/popup.cpp:48–73`: embedded popups register root/visible-parent
  `focus_entered → _parent_focused` and `tree_exited → _deinitialize_visible_parents`;
  deinitialization disconnects those same callbacks and clears its parent list.
- `popup.cpp:75–101,121–136`: visibility/tree changes and parent-focus closure use
  that cleanup path; close defers hiding.
- `scene/gui/popup_menu.cpp:991–1005`: top-level PopupMenu closes through Popup.
- `scene/main/viewport.cpp:496–520` and `window.cpp:813–826`: removing the focused
  embedded subwindow restores parent focus and emits root `focus_entered`.
- `window.cpp:2141–2147` and X11 display-server `3317–3336`: root `grab_focus()`
  requests foreground activation; it is not equivalent to neutral observation.
  Avoiding redundant calls is sensible harness hygiene, but was insufficient here.
- `core/object/callable_method_pointer.h:53–58`: method-name reporting is compiled
  out without `DEBUG_ENABLED`, explaining release's empty callable string. The
  empty string alone is **not evidence of an invalid or freed Callable**. Our
  retained-callable witnesses report `valid:true`. Comparator/hash implementation
  excerpts are included for further engine investigation, without claiming a
  proven comparator/compiler defect.

The actual lobby script does not disconnect either root signal. The observer only
adds passive signal witnesses; it never emits widget signals, selects items by API,
calls UI/gameplay handlers, or edits source simulation state.

## Exactly two purposeful executions

| Run | Engine / product | Duration | Functional assertions | Clean-log result |
|---|---|---:|---:|---|
| [targeted](targeted/summary.json) | Final release binary + production PCK | 30.006s | 8/8 | **FAIL: 14 errors** |
| [targeted-debug](targeted-debug/summary.json) | Pinned debug engine + same PCK | 16.095s | 8/8 | 0 errors; VSync warning retained |

Both runs instantiate `res://world/session.tscn` from the production PCK through
the external [export-lobby-observer.gd](export-lobby-observer.gd). The PCK excludes
tests and is never rewritten. The paired 72 actions are identical after removing
wall timestamps. They cover real text entry, role selection via mouse/Down/Enter,
map/mode confirmation, Escape dismissal, requests to focus host/guest windows and
one explicit redundant-focus probe while the popup is open. These are
`Input.parse_input_event` and Window API observations, **not OS/physical-input
acceptance**; focus calls/flags are not claimed to prove an OS focus transfer.

Each invocation owns an idle packaged authority on loopback `PORT=0`. No Create,
Join or gameplay command is sent in these targeted runs: their wire archives are
empty. The second run was used for the necessary build comparison instead of
repeating the long flow after a known unresolved clean-log failure. There were no
seed retries. **No fresh full-flow PASS is claimed.**

The preserved first summary counts 85 runtime `.mjs` files because that initial
counter included `runtime/node_modules/ws/wrapper.mjs`; the corrected audit counts
the expected **84 authority modules plus packaged ws**. No archive was rewritten
to conceal this reporting detail.

### Timestamp witnesses and screenshots

Each run contains full raw stdout/stderr, `actions.jsonl.gz`,
`witnesses.jsonl.gz`, `wire.jsonl.gz`, summary and PNGs. Engine witnesses record
wall/monotonic time, command/stage, popup visibility/focus, and root signal
connections. Stderr chunks retain their original bytes separately and are also
timestamped on receipt with current command and latest UI/engine witnesses.
Separate-pipe delivery order is not a C++ stack trace; the before/after command
and popup callbacks establish the observed operation boundary.

Opened and visually reviewed:

- [Release 960×640 form](targeted/01-host-menu-960x640.png)
- [Release 1280×800 Guest role and room field](targeted/03-always-after-role.png)
- [Release 1280×800 map/mode after needed-only focus](targeted/05-needed-map-mode.png)
- [Debug 960×640 same product form](targeted-debug/01-host-menu-960x640.png)
- [Debug 1280×800 same map/mode state](targeted-debug/05-needed-map-mode.png)

Forms remain readable and ordinary selection takes effect despite release errors.
This visual result does not override the clean-log failure.

## Archived lead gameplay correlation — not a new live run

The read-only audit matches **2,572 saved native applications** (host 2,035,
guest 537) to their recipient/round/sequence source snapshots. It verifies source
living displacement/shot growth during the lead's held-input bursts:

| Recorded burst | Source displacement | Shot growth |
|---|---:|---:|
| Host round 1 | 17.201m | 16 |
| Original guest round 1 | 16.626m | 15 |
| Fresh guest round 2 | 16.339m | 15 |

The active spectator connection sent only one `join` and one `leave`. It left
before results. The post-results guest was a **new explicit connection**, which
received a playing seat after host restart and freshly captured controls. This
is not spectator promotion or token resumption. These application/effect checks
are stronger than receipts/ACKs alone, but the saved lead run remains
`PARTIAL/FAIL` for clean logs. Its final guest sample line is truncated at shutdown;
that raw line remains recorded and was not treated as valid JSON evidence.

## Integrity, cleanup and reproduction

[audit.json](audit.json) passes **194 offline assertions**, including preservation,
error attribution boundaries, action equivalence, archived application/effect
correlation, artifact integrity and cleanup. It validates the HOLD verdict, not
release acceptance. Both fresh runs also passed their 8 functional assertions.

Artifact (read-only):
`/tmp/opencode/lead-native-linux-package/builds/1790054125934591826/cocs-native-linux`

- Manifest: `8f602b1cc48ab07a05378365a5890d96efea6b8b3d90e9d1c8a916ee085f40cc`
- Release executable: `3c0994716982c2f557f7738a789269074520ac0c0a3f11bb7a84a34ee96c683d`
- PCK: `54124ec449e8b5d0c6b243b8f4d88b1ed05b0c03a7c30fc24c152c0698fcbe49`
- Debug executable: `5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae`
- Both engines report `4.5.2.stable.official.6ce3de25a`.

All 112 manifested packaged files were verified before and after both runs and
again in the offline audit. The original lead report's 33 files remain
byte-identical. Private Xvfb uses `-nolisten tcp -nolisten unix`; HOME/XDG are
isolated. Six owned child processes were reaped, authorities closed with zero
sockets, temporary directories removed, and former ports **35877/36329** refuse
connections. Protected `127.0.0.1:4332` remains under Node PID **1094444**, without
requests, kills or restarts from this lane.

Offline reproduction from the isolated worktree:

```sh
python3 port/reports/lobby-export-focus/export-lobby-audit.py
```

The new helper's targeted commands are `node .../export-lobby-run.mjs targeted`
and `... targeted-debug`. Both refuse existing output directories. Future live
reproduction requires fresh output paths and a new authorized run budget; the
two-run budget here is exhausted. The inherited `full-flow` branch is retained
but **not executed or accepted** in this lane. Primary verifier and X11 changes
remain lead-owned. No unapplied runtime fix is represented as proven.
