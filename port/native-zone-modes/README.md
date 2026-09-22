# Native KOTH + Domination vertical slice

Base `013ad65`; owned branch `agent/native-zone-modes`, worktree
`/tmp/opencode/native-zone-modes`. Source authority remains the accepted
`51289b79c627a26a381ba556b92bab71f93f3732` contract. Changes live only in
`godot/zone_modes/`, `godot/tests/zone_modes/`, and this directory.

## Play

From the repository root, with generated semantic/GLB assets imported:

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
node port/native-zone-modes/play.mjs --map=meridian-exchange --mode=domination
node port/native-zone-modes/play.mjs --map=verdant-reliquary --mode=koth
```

The owned helper launches `res://zone_modes/demo.tscn` with an ephemeral loopback
authority. Close the window or Ctrl+C to stop both. Default: two normal source
bots, 60-second round. Optional `--bots=0..8`, `--round-seconds=60..180` use legal
ordinary host configuration. No direct match mutation, tick override, injected
state, preferred seed, or nonstandard loadout.

Click to capture the pointer, WASD/mouse to move/look, Space jump, Shift sprint,
Ctrl crouch, R reload, E interact, F mobility, weapon keys/wheel, Tab scoreboard,
Esc release. Release movement/action keys before clicking to resume. Enter at
results requests another authoritative round and requires fresh pointer capture.

The compact panel shows local team, friendly/enemy score order, source clock,
ownership/contested state, each zone's capture percentage, nearest/active target
distance and cardinal direction, source radius, and local occupancy. Rings and
world labels use received position/height/radius; friendly is teal, enemy coral,
neutral white, contested gold. Capture, ownership, scoring and rotation are never
simulated in Godot. Shared session, GameHUD, scoreboard, presentation, weapons,
combat/audio, and lifecycle controls are reused through subclass/composition.

## Source discovery (completed before implementation)

- `game/config.mjs`: KOTH and Domination are team modes, default target 100,
  five-second base capture, no vehicles; KOTH rotates every 30 source seconds.
  Ordinary bot range 0..8, legal source time limit 60..900 (this helper deliberately
  exposes the smaller 60..180 range). No score/time settings were injected.
- `game/mode-data.mjs`: authored points → map objectiveZones → safe candidates;
  next-generation terrain uses `clearZone`. KOTH template initially names its
  selected zone `hill`; `Match` initialization snaps/rotates the authored points
  and publishes their actual IDs. Domination has three zones.
- `game/core.mjs` snapshot: public `objectives.kind`, `zones`, objective `winner`,
  `leaders`; zone copies include `id,x,y,z,radius,owner,captureTeam,progress,
  captureSeconds,contested`. The first unticked start template can omit contested;
  the native adapter waits for the complete ticked snapshot. No guessed false.
  KOTH `rotation`, `rotationIndex`, `rotationEvery`, and `rotationTimer` are private
  and absent from the public snapshot. The native scene never infers them.
- Snapshot top level includes `mapId`, `config.mode/timeLimit`, `time`, `over`,
  `teamScores`, and `winner`. Timed results can leave objective winner null while
  the top-level winner contains the winning team. Null means neutral/no winner;
  a missing field means incomplete state. JSON integral floats 0.0/1.0 are valid
  teams; strings, booleans, fractions, NaN and other numbers are not.
- `game/objectives.mjs`: live actors participate within horizontal distance
  `<= radius` and `abs(actor.y-zone.y) <= 5`. Multiple teams contest. An enemy
  occupant neutralizes the old owner before capturing. Contested owned progress
  drains at 0.75 capture rate; progress to 100 captures. Rate includes the source
  tool multiplier. An uncontested friendly occupant on an owned zone earns
  `dt` team score; **empty owned zones do not score**. Source assigns objective
  time/captures/contests to actors and emits zone progress/capture/score events.
  Source mode buffs remain source-owned. No local capture-time extrapolation.
- Zone `y` and radius are public here: **no static fallback or guessed geometry**.
  Meridian: alpha `(0,.9,0), r3.5`; bravo `(-14,0,-19), r3.5`; charlie
  `(27,0,16), r3.2`. Verdant's opening source hill is alpha `(8,0,-4), r4`.
- Locked `port/contracts/map-selection.json` remains nine maps. The scene accepts
  only KOTH/Domination explicitly listed in the generated locked catalog:
  Meridian/Verdant/Ember both; Tidal/Sunscar Domination only. Asterion, Monsoon,
  Ion and Aurora remain in overall scope with their existing experiences.

## Verification commands

```sh
node --test port/native-zone-modes/route.test.mjs
"$GODOT_BIN" --headless --path godot --script res://tests/zone_modes/unit.gd
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/control_safety.gd
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/stall_controls.gd
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/round_boundaries.gd
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/local_lifecycle.gd
GODOT_BIN="$GODOT_BIN" node port/native-zone-modes/run.mjs --map=meridian-exchange
GODOT_BIN="$GODOT_BIN" node port/native-zone-modes/run.mjs --map=verdant-reliquary
git apply --check port/native-zone-modes/integration.UNAPPLIED.patch
git diff --check
```

Graphical runner: pinned Godot, private Xvfb with `-nolisten tcp -nolisten unix`,
`server.listen(0,'127.0.0.1')`, isolated XDG runtime, no persistent history, normal
rate, ordinary zero-bot practice configuration, 60-second rounds, 85-second
native / 150-second outer ceiling. Route computation happens **before** starting
the live server. The driver uses `Input.parse_input_event` key/mouse events on the
shipped scene; it does not call session input handlers, change the camera/actor,
teleport, or modify source state. Source geometry routing reuses the existing
`native-projectile-combat/route.mjs` support/collision/short-segment `walkEdge`
planner, with supplies allowed. All authored spawn routes on both tested maps
are checked. Route failure retains exact start, goal and waypoint information.

Wire archives record the native recipient, round, snapshot sequence, outbound
zone state/score/actor stats, received inputs, results and events. Native logs
separately record queue telemetry, ACK high-water, and actually rendered zone
projection. Validation correlates rendered coordinates/radius/ownership/progress,
scores and clock with the same recipient/round/snapshot. Capture requires a
source ownership transition plus actor capture stats; held scoring requires
source score growth with a living actor in the zone. ACK is **input receipt**,
never objective success. Archived gzip logs have uncompressed SHA-256/byte
counts, and summaries hash runtime code plus source files and record cleanup.

## Integration proposal — UNAPPLIED

`integration.UNAPPLIED.patch` adds `--experience=zones` routing to the common dev
and package option tables. The patch checks cleanly against this base; it has
not been applied. Defaults use the scene's two bots / 60 seconds. For integration:

1. Apply/reconcile the two routing entries with parallel experience additions;
   add help examples and option-table regression coverage.
2. Keep map/mode checks against the locked selection. The other nine-map
   experiences stay available; do not replace any existing entry.
3. The current package exporter includes all resource scenes. Include the new
   zone scripts/scene in the staging tree, inspect them in the PCK, then run the
   package's existing resource/hash/launch/cleanup gates. No package rebuild or
   package acceptance is claimed by this scoped branch.
4. If exposing settings through the common launcher, translate validated zone
   time/bot settings to `--round-seconds`/`--bots`; do not silently reuse sports
   `--time-limit`/`--round-target` semantics.

Actual runtime results, reviewed image paths, retained failure and limits are in
`RESULTS.md`.
