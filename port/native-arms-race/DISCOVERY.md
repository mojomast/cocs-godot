# Arms Race discovery — before implementation

Baseline: `8a58c97`. Ownership: only new `godot/arms_race/`,
`godot/tests/arms_race/`, `port/native-arms-race/`. Read
`port/handoffs/ACTIVE_LANES.md:1–86`: shared session/client, launch/package,
Horde, pulse assets and other gameplay lanes reserved; campaign deferred.
`port/contracts/map-selection.json:6–23,82–99,165–182` requires Arms Race on
Meridian Exchange, Verdant Reliquary and Ember Crucible. All nine remain intact.

## Authority and rules

- `game/config.mjs:122`: FFA ladder, fixed ten-rung goal. `:155–159` defines
  legal difficulties; `:259` actually defaults to easy despite Normal's label.
  This slice explicitly requests **normal**, two bots, time limit 180 by default;
  optional legal 60–900 second timer. No mutators or difficulty reduction.
- `game/core.mjs:834`: spawn restores ladder weapon and sufficient ammo.
  `:867–885`: living non-self killer gets a promotion; victim dies/demotes;
  falling also demotes. Frags alone are not progress.
- `:1148–1149`: ladder 0..9, +1 kill (or +2 when at least two rungs behind),
  clamp to 9; killing while already at 9 sets ladder 10, explicit actor winner,
  objective end and `armsrace-win`. Death floors at zero. Promotion resets alt,
  grants weapon ammo and 0.2 second switch delay. Catch-up never skips final kill.
- `:1008,1033,1070,1192`: switches refused/weapon pinned, external weapon
  selection ignored. `:1157`: weapon/ammo pickups do not auto-switch this mode.
  `game/bots.mjs:551` also keeps bots on their rung.
- `:1298–1314`: time ending ranks ladder then frags, excludes Arms Race from
  sudden death; snapshot includes full actors (`ladder`, `weapon`, ammo, health,
  dead, frags, deaths), config, time, over, overReason, winner and leaders.
  `game/outcome.mjs:34,74–81`: explicit winner outranks inferred ranking;
  time ties can award multiple actors; zero ladder/zero frags is a draw.
- `game/armsrace.test.mjs:9–100` already exercises final kill, switching lock,
  bot weapon, demotion/respawn, catch-up and bounty not ending early. These are
  injected **fixtures**, not live native acceptance.

## Wire / lifecycle inspection

- `server/room.mjs:758–788`: deep-copy quantization preserves ladder fields.
  `:982–1049`: public host normalizes config, resolves map, ordinary start creates
  Match, assigns actors, resets input state and broadcasts lobby/start.
  `:1052–1097`: receipts and latest input differ from applied input;
  `:1288–1302`: ACK advances only after source step. `:1334–1344` ends round.
  `server/game-server.mjs:51–55` default scheduler is normal 1/60, ~16.67ms;
  no custom clock/random/state will be supplied by evidence harness.
- `godot/net/client.gd:29–88,129–206`: allowlist/map checks, v3 delta=0,
  queue-success sequence numbers, monotonic snapshots/ACK, deduplicated events,
  final results freeze, explicit fresh reconnect required.
- Entire `godot/world/session.gd:1–402` inspected: phases 0/1/2/20 -> 3 -> 4,
  public create/host/start/restart, focus releases capture, missing/stale actor
  neutralizes controls, respawn reseeds look from authority, errors clear visuals
  and disconnect; exit closes owned client. Movement/fire is generated from
  Godot Input at 60Hz, never locally simulated. Weapon selection normally runs
  independently and must be disabled by the subclass for this mode.
- `godot/world/local_lifecycle.gd:18–40`: health and dead establish alive,
  timer zero alone does not; result state disables control. Add a slice-local
  held-input latch to require releases before fresh capture across boundaries.
- `godot/objectives/demo.gd:16–81`: established standalone initialization pattern
  permits composition without shared session edits. Reuse viewer, presentation,
  pickups, combat/audio (`world/combat_feedback.gd`, `audio_feedback.gd`) and HUD.
- `godot/ui/scoreboard.gd:144–208,289–314` sorts frags/deaths, not suitable as-is;
  subclass presentation ranking/header while retaining passive pagination,
  lifecycle binding and result/restart UI. `ui/game_hud.gd:107–140,149–223`
  already presents ammo, vitals and lifecycle; subclass adds authoritative rung,
  current/next weapon, transition and end result, removes switch advertisement.

## Acceptance plan and honest limits

Fixture boundaries: missing/fractional/out-of-range progress; normal/bonus up,
demotion, rung 9 is not victory, explicit finisher, timed tied result and draw;
fresh-input boundary latch and weapon request suppression. Explicit failures,
never GDScript `assert` as the sole failure path.

Ordinary isolated source server startups on all three maps. One bounded Meridian
native-event driver route approaches a visible bot, aims using mouse motion and
fires using Godot button events; maximum two purposeful attempts <=180s each.
No source state writes, direct input frames by the driver, injected time/physics,
shortened ladder or fake victory. Public snapshot-guided automation is evidence
of the native event/control path, not human playtesting. Record queued inputs,
server receipts, applied ACK and distinct source effects. Open actual 960x640
and 1280x800 screenshots. Timer results/restart can be accepted independently
of full-ladder victory. Missing live wins stay explicitly unaccepted.

### Attempt 1 plan (recorded before launch)

Meridian, 1280x800, two Normal bots, 180-second source match, unchanged fixed ten
weapons, no mutators, source-default loadout. Driver wall bound 174 seconds plus
capture completion, hard 177-second native deadline / 180-second process bound.
Public solid boxes feed a test-only 2m navigation grid; nearest living bot with
an approximate unobstructed box sightline is preferred. Approach to 12m, turn
with bounded mouse motions, fire with left-button events; public recoil fields
can guide mouse compensation. Geometry checks are approximate routing aids,
not replacement game physics. Stop on first source-local promotion plus native
ladder display capture. No victory attempt or full-ladder acceptance is claimed.

### Attempt 2 decision (recorded before launch)

Attempt 1 (`6f67ab4b-c215-421d-9e50-43f27af7788f`) reached a local kill and
promotion at source time 7.617, native rung 2 / Rocket Launcher at seq 230,
ACK 194. Overall run correctly failed because inherited map loading selected an
item in the standalone's empty hidden OptionButton. Populate the nine catalog
entries before map loading. No combat, difficulty, route or driver change.
Attempt 2 repeats the same route/config to establish clean-log acceptance after
this initialization repair. It is the final authorized live combat attempt.

The first launch of attempt 2 (`24dc64cd-0ffd-45c4-b99c-f9067278ec50`) never
created a room: Xvfb display-fd was read with one short `os.read`, then closed
before Xvfb wrote its newline. Godot could not create a display. Its wire archive
has starts=0, inputs=[], samples=[], so it is an infrastructure preflight failure,
not a live combat attempt. The concurrent startup run `7a26e248-...` failed the
same way. Retain both. Read the complete newline-terminated display number and
run xdpyinfo before launching a server/client; retry the still-unused second live
attempt sequentially. No runtime/driver/rules changed.

Preflight `e57fff1f-508c-4dee-9907-f2fc3ee74797` then found `xdpyinfo` unavailable
(exec PermissionError). No server was launched. Use the pinned Godot viewer's
one-frame `--quit` as graphical preflight instead. These preflight failures are
retained separately; only runs with a source start and native input count as live
combat attempts. There is still exactly one completed live combat attempt here.
