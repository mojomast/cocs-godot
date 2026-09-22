# Lead integration: opt-in multiplayer lobby

Runtime `3b96206` integrated as `ddf166a`. Git inferred an unrelated historical
directory rename for its new launch helper. The lead retained the exact delivered
`port/native-multiplayer-lobby/launch.py` path/content; no native-CI file existed
at the inferred destination. No unrelated file was removed.

Independent original review commits `0c92076`, `37f0b9e`, `0cc3b8e` are integrated
as `5f232cb`, `f370421`, `d38d4bc`. Original failed/partial attempts remain intact.
UI repair/follow-up `f762639`, `c8c1513`, `12e770d` are integrated as `bd20785`,
`e88b5a6`, `5a87f19`. The original external uncommitted handoff/evidence remains
unrecovered; acceptance here derives from new independent runs.

## Accepted bounded slice

The follow-up verified real two-client Meridian TDM roster/start, ordinary
movement/fire, active Leave cleanup, natural60s results, host-only restart and
fresh guest capture after an explicit post-results join. Ember startup/layout
passed separately. The lead directly opened the actual960×640 and1280×800 results
PNGs: Leave, Restart, compact top HUD and four-row team scoreboard are separate
and readable. This is engine-event acceptance, not physical-device/human testing.

Active-room rejoin initially exposed the source informational spectator notice
being treated as fatal. Runtime repairs `f92b0ef`/`de6f9f9` are now integrated as
`17d3657`/`96542c2`, with independent evidence `e9ed72f` as `1a00d90`. The lead
reviewed the exact queued-join → matching spectator welcome → full active roster
→ single two-field notice allowance. Unrelated, late, duplicate and malformed
errors remain fatal. Spectators retain actor−1, send no inputs/config/start and
stay spectators through restart. There is no generic server-error suppression.

Lead actual-scene checks pass **31 spectator checks** plus **75 layout checks at
each size**, using private graphical windows and synthetic transport. Directly
opened final active960 and results1280 PNGs show both status lines contained,
separate Leave/scoreboard, and no missing-local-player guidance. Live source
application and fixed-camera evidence remains in the independent report.

## Lead launch integration

`--experience=lobby` opens the opt-in menu without changing existing defaults.
Without an endpoint it owns a normal loopback authority; an explicit
`--endpoint=ws://...` / `wss://...` uses an existing authority and owns only the
native process. External authority lifetime is not tied to client exit. The
shared validator rejects non-WebSocket URLs, credentials, fragments, whitespace,
duplicate/empty arguments and non-lobby endpoint use.

Both route tables validate the expected combat map/mode. Guests still select the
expected host map and accept the authority's actual supported mode. This is a
ninth launcher route reusing `world/session.tscn`, not a ninth native scene.
The host's owned server stops when its launcher/window exits, not when merely
leaving its room through the UI.

The integrated80-gate suite passes (including LATTICE usability24, Payload823/99
and spectator context66). Four focused
option tests and six process tests pass for external-authority ownership across
ordinary exit, native failure and missing executable. The latter deliberately
use a stub executable and a factory that fails if called; they are process-boundary
regressions, not live multiplayer evidence. Fresh exported-client ownership and
two-client product-scene checks are now underway. The first exported full flow
reached all gameplay/lifecycle assertions but remains FAILED because its guest
logged Godot focus/tree signal-disconnect errors. An isolated triage owns that
remaining clean-log gap. The first generic package run separately hit an Xlib
BadWindow verifier race, now reproduced/fixed with a real destroyed-window
regression; its failed run is preserved with all recorded PIDs/ports closed.

## Release popup attribution and next repair

Independent focus triage `c3a9067` / `7f703a1` is integrated. Identical72-command
sequences against the same PCK produced14 release-engine errors and zero debug
errors. Ordinary Enter selection, popup reopening and Escape dismissal retained
popup callbacks in release. Avoiding redundant `Window.grab_focus()` calls did
not resolve the issue. Exact C++/compiler causality remains unproven.

The lead reran all194 offline assertions on a temporary evidence copy, recording
the output in `focus-reaudit/`. Its final preservation check compares the three
reviewed lobby runtime files and source to the triage baseline; newer independent
world/Payload/tool changes are intentionally outside that check. Original reports
were not rewritten. All112 package files,33 original lead evidence files and
2,572 archived native/source applications match. This confirms the **HOLD** verdict,
not clean exported play.

A narrow popup-free lobby selector is now authorized in isolation, with actual
release testing required. Combat setup and board popup findings remain separate;
this does not justify suppressing engine errors or changing global engine flags.
