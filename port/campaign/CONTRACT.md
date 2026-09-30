# Relay campaign implementation contract

Flash research precedes this contract. Astra lanes implement the following
interfaces in isolated worktrees. No changes to locked `game/` or `server/`.

## Campaign: The Quiet Relay

A maintenance operator follows a surviving archive signal along a forest-to-
canyon power corridor. Its security robots are enforcing a corrupted quarantine.
Recover the archive, restore a way across the canyon, isolate the uplink, and
transmit the repair key at the Crown Array. Text comms from ECHO reveal that the
signal is a rescue request rather than a weapons command. The finale restores
the network and returns the landscape to quiet; include a real ending screen.

Ordered map IDs/titles:

1. `rootfall-verge` — Rootfall Verge: forest ravine, fallen relay, first foothold.
2. `siltwake-crossing` — Siltwake Crossing: canyon riverworks and bridge relays.
3. `emberline-ascent` — Emberline Ascent: terraced basalt works and uplink ascent.
4. `crown-array` — Crown Array: highland forest/industrial crown, guardian finale.

Suggested footprints respectively 320×224, 352×256, 384×256, 416×288 m: roughly
9–16 times the area of either 96×80 m arena. Ordered paths target 900–1,500 m.
Five encounter anchors per level, with traversal/briefing/recovery beats between
them. Target 5–10 minutes through travel plus purposeful combat/interaction;
no forced multi-minute waits or five-minute failure clock. Actual duration needs
human timing. At least one flank/optional supply route per combat area.

## Worlds lane owns

- `tools/godot-campaign/compile.mjs`, terrain tests.
- `godot/campaign/generated/<map-id>.json`.
- `port/native-campaign/maps.mjs`: exports `CAMPAIGN_MAP_IDS` (ordered),
  `loadCampaignMap(id)` returning a validated envelope; no source registry edits.
- `godot/campaign/terrain.gd`: Node3D; `build(id: String) -> bool`,
  `recipe: Dictionary`, `height_at(x: float,z: float) -> float`.
- `godot/tests/campaign/terrain.gd` and world-design documentation.

Envelope: `{schemaVersion:1,id,name,geometryHash,arena,palette,art,routes,
spawnPoints,cameras,campaign}`. `arena` uses the existing source-compatible
terrain/nav/blocks/pickups/spawns/bounds fields. `campaign` has
`{index:0..3,targetSeconds:[300,600],criticalPath:[{x,y,z}],
anchors:{start:{x,y,z,radius},"encounter-1":{...},..."encounter-5":{...},exit:{...}},
nextMapId:string|null}`. `routes` includes critical path and local fight loops.
Anchors and spawn points must have finite supported feet coordinates and be
reachable; y is feet height. Render/collision must consume identical geometry.
Use a campaign-specific strict validator permitting reviewed bounds up to 512 m,
not a relaxation of the existing multiplayer/DM validator. No unbounded scatter.

## Authority lane owns

- `port/native-campaign/{match,missions,enemies,authority}.mjs` and Node tests.
- Loopback service `cocs-native-campaign`, WebSocket path `/native-campaign`.
- Export `createAuthority(options={}) -> {server,wss,close}` (unbound), plus
  `createCampaignAuthority` alias. Options `mapId`, `difficulty`, `random`,
  `observe` and optional trusted test seams, never wire-provided geometry/files.
- Reuse source Match movement/weapons/bots/roles via subclass seams. Avoid the
  source mission-ID fallback: port owns its mission loop/state explicitly.
- Source `npcType` remains a known brain alias; `npcModel` identifies visual.
- Input epochs/cancellation follow the existing native-arena protocol and reset
  on death/retry/map transitions; one human only. Normal create/start/input frames
  stay compatible with NativeClient; create supports `nativeArenaInput:1`.
- Additive frame `{type:"campaign-action",action:"retry"|"restart"|"continue",
  inputEpoch:<current>}`. Retry current checkpoint, restart current level,
  continue only after a completed level. Continue emits fresh `start` and resets
  input safely. Final continue yields campaign completion rather than looping.
- `snapshot.campaign` is the HUD contract:
  `{id:"quiet-relay",mapId,index,title,stepIndex,stepCount,objective,detail,
  marker:{x,y,z,radius},phase:"playing"|"dead"|"level-complete"|"campaign-complete",
  checkpoint,elapsed,totalElapsed,kills,enemiesRemaining,holdProgress,
  transmission:{speaker,text},nextMapId}`.
- Standard start/snapshot/results include `inputEpoch`; map identity/hash in
  start metadata. Exactly-once objective progression, finite encounters,
  checkpoint reconstruction, generous/no campaign time failure, seeded tests.

## Robot lane owns

- `godot/campaign/robot_visual.gd`, `robot_parts.gd` if useful, model tests/gallery.
- Robot IDs: `scrapper`, `skirmisher`, `sentinel`, `mortar`, `bulwark`, `warden`.
- Distinct articulated silhouettes: low quadruped; narrow asymmetric biped;
  tripod gun pod; heavy mortar quadruped; slab-armoured shield biped; large
  multi-legged guardian. No mere recolours. Source robot material language,
  strong value separation and visible attack anticipation/recovery.
- Node3D compatible API: `configure(actor:Dictionary, local_id:int=-1)`,
  `apply_actor(actor:Dictionary, local_id:int=-1)`, `apply_identity(actor)`,
  `advance(dt)`, `select_distance(distance)`, `set_lod(level)`,
  `visible_cost()->Dictionary`, `kick(amount=1.0)`, `reset_pose()`;
  `automatic_animation` bool. Root position uses source actor centre y,
  so feet are at local y≈-0.9 (scale for bosses explicitly).
- Known source fields supply animation/telegraphs; document exact consumed
  fields. Optional `campaignTell` string and `campaignTellProgress` number may
  be used only if authority explicitly produces them. Art must not fake damage.
- Near/mid/far manual LOD with accurate cost accounting; no time-discarding gait.

## Client lane owns

- `godot/campaign/{demo.gd,demo.tscn,client.gd,hud.gd,model.gd,catalog.gd}` as needed.
- Source Session reuse for actual input, first person, audio and combat. Campaign
  terrain and models; reuse the existing source operators for the human.
- `godot/world/presentation.gd` minimal injectable actor-visual factory seam if
  needed; no behavior changes to existing routes. Robot models only when npcModel
  is one of the six IDs. Coordinate snapshots with authority contract above.
- Entry args: `--map=<campaign-id> --mode=campaign --endpoint=ws://127.0.0.1:PORT/native-campaign`
  and `--smoke`; optional `--difficulty=easy|normal|hard`.
- Clear brief, objective/waypoint, subtitles, checkpoint feedback, death/retry,
  level-complete/continue and ending. Respect settings/Leave and no surprise
  recapture. Continuous chapter travel occurs inside the owned authority.
- Meaningful headless contracts and real owned-authority smoke evidence driver.

## Orchestrator owns integration

Launcher/parser/routes/package-discovery/build/check registries and release.
CLI route `--experience=campaign --map=<id>`; startup map is chapter selection.
All heavy imports/tests/render/builds serialized centrally. Workers may write
tests and run lightweight syntax/type inspection; request a testing slot before
running engine imports or heavyweight simulations. Finish with scoped commits,
explicit test instructions and known issues. Cross-lane contract changes need
notification, not silent guesses.
