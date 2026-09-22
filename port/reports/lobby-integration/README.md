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

Active-room rejoin exposed the source informational spectator notice being
treated as fatal. That path remains OPEN pending a separately reviewed narrow
client/session repair. No general server-error suppression is approved.

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

The integrated77-gate suite passes (including LATTICE usability24). Four focused
option tests and six process tests pass for external-authority ownership across
ordinary exit, native failure and missing executable. The latter deliberately
use a stub executable and a factory that fails if called; they are process-boundary
regressions, not live multiplayer evidence. Fresh exported-client ownership and
two-client product-scene checks are prepared in the package tools and remain
pending the spectator repair/final runtime build.
