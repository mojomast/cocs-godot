# Native campaign client

Entry scene: `res://campaign/demo.tscn`. CLI:

```
--map=rootfall-verge --mode=campaign --difficulty=normal --endpoint=ws://127.0.0.1:PORT/native-campaign
```

`--smoke` begins automatically and drives the **shared session's real network input**.
Campaign guidance walks `world.recipe.campaign.criticalPath` vertices in authored
order using received actor feet coordinates, turning its movement/look at each
vertex and firing through the existing normal-rate input queue. It never teleports,
skips to a nearby later leg, or changes enemy deployment. A 12-second no-progress
watchdog reports blocked geometry honestly; the campaign deadline is 90 seconds.
The shared Session defaults remain forward/fire and 20 seconds for other routes.
The owned live-smoke driver's outer process timeout is 120 seconds; packaged
verifiers should also allow 120 seconds to collect a 90-second failure report.
Interactive entry shows a chapter brief; Begin connects, and clicking the world
captures the pointer. Enter retries a death or continues a completed chapter.
Settings, focus loss, stale state, death, errors and every fresh start release it.
Focus regain and retry never silently capture. Leave disconnects and exits.

## Composition and integration

- `demo.gd` extends `world/session.gd`, preserving actual controller, first person,
  authoritative camera, local motion, weapon selection, combat effects and audio.
- `presentation.actor_visual_factory(actor, local_id)` is the sole shared seam.
  Its empty default retains the source operator. Six known `npcModel` values load
  `campaign/robot_visual.gd`; every other actor uses the source visual. The normal
  presentation applies position, visibility/death, identity and genuine-shot recoil.
  Campaign distance selection calls `select_distance`; robot automatic animation
  retains responsibility for advancing its own articulation.
  Robot `wants_death_pose()` opts into a visible 0.65-second collapse with a short
  settled beat, bounded to 0.8 seconds. The robot hides itself at expiry between
  snapshots; local bodies remain hidden, source visuals still hide immediately,
  and authority actor removal/round clearing still retires nodes immediately.
- A route-local `CampaignCombat` subclass supplies campaign terrain colliders and
  recipe bounds to the existing occlusion, impact, particles and blood services;
  the shared feedback's source-only catalog cannot resolve campaign IDs. Its
  cosmetic vertical bounds are -32..160 m, with exact recipe horizontal bounds.
- Terrain is loaded through `build(id)` and catalog recipes; no source map fallback.
  Catalog entries include campaign mode and `geometryHash`. Starts check that hash.
- Client extends native-arena epoch/cancel semantics. A fresh start can change map
  only to the immediately following chapter advertised by level completion. This
  updates `requested_map` before the inherited strict map checks. Retry/restart
  retain current identity. Chapter starts clear presentation and audio epochs.
- Setup sends `create` with `nativeArenaInput:1`, then `host` with
  `{mapId, config:{mode:'campaign',difficulty}}`, then `start`. Parent/authority lane
  must honor that host difficulty field (or negotiate a documented deviation).
- Actions send `{type:'campaign-action',action,inputEpoch}` and await a fresh start;
  duplicate UI activation is blocked. The final ending offers Settings/Leave.
- `model.gd` only consumes `snapshot.campaign`; UI never awards progression.

## Checks (parent serialized engine slot required)

```
$GODOT_BIN --headless --path godot --script res://tests/campaign/model.gd
$GODOT_BIN --headless --path godot --script res://tests/campaign/client.gd
$GODOT_BIN --headless --path godot --script res://tests/campaign/session.gd
$GODOT_BIN --headless --path godot --script res://tests/campaign/death_presentation.gd
$GODOT_BIN --headless --path godot --script res://tests/campaign/smoke_route.gd
GODOT_BIN=/path/to/pinned/godot node port/campaign/live-smoke.mjs rootfall-verge siltwake-crossing emberline-ascent crown-array
```

The smoke driver owns an ephemeral loopback listener, isolated settings directories,
and a Godot process. It requires real authority-observed movement, shots and ACKs,
plus matching hash, first-person initialization, combat shot effects and an actual
robot visual instance before accepting `CAMPAIGN_SMOKE_OK`. Evidence is written to
a fresh `/tmp/opencode/campaign-smoke-*` directory. It does not claim human timing,
rendered performance, whole-campaign completion, or visual acceptance.

Engine import/tests have **not been run by this lane**, per serialized-slot rule.
`node --check port/campaign/live-smoke.mjs` and `git diff --check` pass.
The tests cover terminal null markers, action deduplication, epoch/hash refusal,
base result-latch reset, actor-cache retirement, held fire/mobility retry and
Continue boundaries, final ending, and focus regain without recapture.
Parent owns resource closure,
launch registry, authority/world/model integration and final render verification.
