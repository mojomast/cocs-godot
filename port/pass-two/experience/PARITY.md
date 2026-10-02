# Second-pass experience / spectator parity

Status: **READY FOR ENGINE — source/code checks only, 2026-10-02**.
Branch `improvement/pass-two-experience`, base `51c29dc9`.
Evidence: `/home/mojo/.tmp-on-disk/cocs-pass-two-experience-evidence-20261002`.

Read before selecting this work: `port/next-port/experience/PARITY.md` and
`ACCEPTANCE.md`. Their accepted captions, priority/duplicate behavior, operator
status and campaign docking are inherited work, not new parity claims here.

## Confirmed source and native gaps

| Journey | Source authority | Audited native baseline / change |
|---|---|---|
| Select, follow and cycle live targets | `game/hud.mjs:1208–1251`, `game/view.mjs:1500–1502,4199` | Shared `world/session.gd` explicitly supplied a fixed spectator view and released the pointer every snapshot/process. Added a public-actor allowlist model with exact live/fallback/cycle behavior, including integer and string IDs (numeric JSON representations accepted; strings are not coerced into numeric target IDs). |
| Free camera | `app/page.tsx:606`, `game/view.mjs:1533–1682`, `game/camera-modes.mjs:89–135` | Added keyboard/mouse-only camera owner, follow/free button + V, target buttons + brackets, explicit capture/release indications. Source motion uses speed 16, boost 2.4, acceleration/braking half-lives, world-up, speed bound, trapezoid integration and floor 0.4. Native oracle vectors cover movement, diagonal, brake, boost, floor and step clamp. |
| Public target HUD | `spectatorBoard` / `spectateActor` in `game/hud.mjs`; `filterCocsSnapshot` in `game/cocs-intel.mjs`; `server/room.mjs:791–800,1254–1262` | Name, health and team come only from the accepted recipient snapshot. Target selection never changes client actor ID, local kit, damage recap, first-person actor or private LATTICE context. Model retains only ID/name/health/team/position/look/eye height. |
| Public kill feed / local assist | `app/page.tsx:572–605`, `game/hud.mjs:175–203,525–537`, `game/core.mjs:916,928` | No shared native public feed was found. Added up to three authority feed rows, weapon/ability text and event-time + victim-name enrichment. ASSIST requires positive local damage followed by a credited other-player kill within source's inclusive five-second window. Spectators have no personal damage marks. No proximity inference. |
| Seat/lifecycle privacy | Existing `player_info.gd` role key and int/string phase adapter; client spectator assignment in `godot/net/client.gd` | Added event-first seat invalidation (even before a lobby callback), explicit spectator recap/kill suppression, capture release on handoff, and source-public COCS caption filtering for queued old-seat contexts. Dedicated native contract covers shared and independent signal lifecycles. |
| Independent actor input isolation | `sports/demo.gd`, generated `multiplayer_worlds/sports_demo.gd`, `combined_arms/demo.gd` | Sports previously attempted neutral input in active/results spectator phases. Both attempts now gate on seat role. Independent actor input handlers yield to spectator camera; combined-arms no longer releases spectator capture every frame/snapshot. |
| Combined-arms compact HUD | First-pass acceptance's known UI150 overlap | Replaced fixed help/prompt offsets with wrapped VBox rows in two bounded, keyboard-scrollable regions. Visual acceptance remains required. |

## Ownership and integration

Core: `godot/experience/{spectator_model,spectator_camera,free_camera_math,
spectator_events,kill_feed,player_info}.gd` plus extracted public event names.
The existing persistent PlayerInformation binding instantiates the camera child;
it binds the actual scene `client` or `net`. Camera processing runs after scene
presentation, and it has no transport send method. Its own held-key ledger is
cleared on capture/mode/target changes, stale/focus/modal boundaries and unbind.
Key-up is observed before GUI consumption. Fresh capture + fresh presses are
required after release; held actor keys are never sampled with global polling.

The integration commit separately owns minimal hooks in shared session, sports,
generated world sports and combined-arms roots. Parent should reconcile these
with the gameplay lane. `generate-scenes.mjs --check` passes; the generator reads
the original sports root, so no generator override was required.

Campaign solo has no spectator seat and gains no invented spectator route.
Its existing docked kit/comms, narrative priority and recap ownership remain the
acceptance baseline. Modes-owned Career/results and World-owned ambience were
not rewritten. Locked `game/` and `server/` files are read-only and unchanged.

## Bounded implementation limits

- This is follow/free target control, not cinematic director/autocuts, third-person
  rigs, replay theater, target roster/team grouping or camera collision parity.
- Kill feed does not infer killer/victim streak counters between snapshots.
  It displays streak badges only when supplied; overkill uses the actual death
  event. Harness/wing chips and full source feed richness remain unimplemented.
- Stable numeric event IDs use a monotonic watermark; string IDs use a bounded
  4096-entry ledger which fails closed at capacity. Start/results/error/seat or
  backwards source clock clears the epoch. New snapshots do not duplicate rows.
- Standalone sports is a host-only launcher. Connected spectator acceptance uses
  the existing world sports `--join-room` route, not an invented solo join UI.
- New native contracts are written but **not executed** before the engine grant.
  The non-engine grammar parser cannot prove Godot type checking or rendering.

Source vectors and provenance hashes are generated by
`tools/experience/spectator-oracle.mjs`. Test helpers and fixture data are under
`godot/tests/experience`; runtime code never preloads tests.

## Connected harness follow-up (code/Node only)

`tools/experience/connected-native.mjs` now provides executable mode, world
LATTICE, sports and combined-arms plans. It drives
`godot/tests/experience/connected_native.gd` through a bounded loopback command
channel. Two native players join before start; a third native process joins late
as spectator. The ordinary source or reviewed multiplayer-world derived factory
is selected exactly as the existing development launcher does. Actual source
start map/geometry (worlds) or semantic catalog content hashes (source maps) are
checked. No authority source file is modified.

The driver uses ordinary key/mouse events, actual F12 and native window focus,
source starvation, per-seat wire observations, staged real damage/death receipts,
duplicate transport delivery, natural 120-second round config, results, restart
and Settings Leave. Its supervisor then opens the real Home scene, matching the
production launcher's process-exit handoff. Tests-only sports and combined-arms
subclasses add a two-player lobby barrier and bounded host config respectively;
their input/render/lifecycle implementations remain inherited production code.

Mode exercises actual Retry-button same-seat resume and expired-token admission.
The other three routes expose Home/rejoin instead; their reports explicitly say
`explicit-home-rejoin`, not same-seat resume. Sports rules disable infantry
damage, so sports omits ASSIST/death staging rather than fabricating such events.
Source `Room.leave()` retains a departed actor as a BOT; the harness records that
takeover, checks the public snapshot, and does not invent actor removal.

**Static integration concern awaiting native work:**
`godot/mode_expansion/demo.gd:166–168` still resets spectator camera position on
each snapshot. A new per-frame free-camera continuity assertion detects this
route override; this harness-only follow-up does not silently change Modes-owned
production code. It remains a likely native gate failure requiring integration.

## Required package closure addition

Parent must add **`godot/experience/public_event_types.json`** to its explicit
runtime JSON/package allowlist. `spectator_events.gd` loads it at
`res://experience/public_event_types.json`; it is a runtime dependency, not a
test fixture. Include the new experience `.gd` helper closure normally, but keep
`godot/tests/experience/connected_*` and `spectator_fixture.json` test-only.
Export/package closure is still parent-owned and has not been run here.
