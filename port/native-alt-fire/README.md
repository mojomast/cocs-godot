# Native alt-fire variety: distinct bodies, trails, impacts and voices

Presentation pass on top of `cd0038a4` ("Register the recoil and projectile-flight
gates after the weapon oomph landing") for the owner request: *"i also need the
alt fire to be more varied and have different visual effects from normal fire."*

Before this lane every alt projectile was the same generic sphere, every alt
explosion read as the primary `combat_feedback` burst, and every alt launch /
explosion played the primary weapon voice. Four projectile alt modes exist in the
locked source (`game/alt-fire.mjs`): **cluster** (weapon 1), **mortar** (4),
**proximity mine** (5) and **flak bomb** (7). Each one now owns a shared body, an
exhaust character, an impact burst and a voice.

No gameplay or simulation value is read, written or faked: aim, spread, ammo,
damage, projectile speed/position from authority, snapshot cadence, the ADS
sight-picture contract, decals and every counter in `combat_feedback.gd` are
untouched. The only snapshot fields consumed are the ones the authority already
spreads (`alt`, `altId`, `mine`, `bomblets`, `flak`, `arm`), verified in
`game/core.mjs` `snapshot()` and the `rockets[]` rows.

Toolchain: Godot **4.5.2.stable.official.6ce3de25a**, GL Compatibility under a
private Xvfb (llvmpipe) for the rendered captures, `--audio-driver Dummy` for the
audio gate.

## What changed

| Path | Change |
|---|---|
| `godot/world/projectiles.gd` | Four shared alt bodies built once in `_init` (no per-shot mesh/material allocation): cluster segmented drum, mortar teardrop with fins, flat proximity-mine disc with a separately pooled blinking eye, boxy flak canister with vents. Source weapon colours (1 `#ffad61`, 4 `#72cfff`, 5 `#ff806b`, 7 `#ffd166`) plus alt accents (`#ffb066`, `#c9a6ff`, `#8fd9ff`, `#ff9a7a`); accent surfaces carry real `emission_enabled` materials. `alt_kind()` mirrors the source's own `altRocketKind` precedence. Alt rows carry `arm` so the mine blinks at the source's 7 Hz once armed. One exhaust ribbon per projectile with per-kind colour/width/alpha and character (`spark`, `smoke`, `pulse`); the mine idles on a slow breath and blinks hard when armed. |
| `godot/weapon_effects/controller.gd` | Pooled alt explosion bursts on the existing flash pool: cluster pop + split ring, mortar dome + dust + rising smoke, mine sharp core + fast ring + concentric pulse, flak pop + plume + a bounded fragment fan (8 shards Extreme / 4 Low). Shader kinds 13-16 added; staggered bomblet pops ride a hidden delay on `remaining`. Counters `blasts`/`blast_shards` added; every existing pool/counter untouched. |
| `godot/weapon_effects/flash.gdshader` | Four new shapes (13 cluster shards, 14 mortar dome, 15 mine core, 16 flak star). Defaults elsewhere unchanged. |
| `godot/world/audio_feedback.gd` | Original alt voices keyed `alt/<id>/<cue>` from `altId`: four projectile launch/explosion voices (cluster pop + bomblet ticks, mortar whoomp + whoosh, mine dull thunk + two arming blips, flak crackle) and six hitscan alt shot voices. Same lazy deterministic cache, 3 ms/18 ms envelope, peak ≤ 0.65, cooldowns and 8-voice pool unchanged; unknown ids fall back to the primary voice. |
| `godot/world/combat_feedback.gd` | Minimal: the detached no-controller fallback tints and sizes alt explosions per `altId` instead of painting them orange. Counters, pools and the primary path are byte-identical. |
| `godot/tests/weapon_effects/alt_fire.gd` | New headless contract (105 checks): bodies, kind precedence, low stance, arm blink, trail characters, pool reuse/bounds and every alt burst. |
| `godot/tests/weapon_effects/alt_fire_capture.gd` | New rendered evidence harness (107 checks, 33 PNGs + metrics JSON) under a private Xvfb. |
| `godot/tests/protocol/audio_feedback.gd` | Extended from 287 to 411 checks: 14 alt voices cached, bounded, peak/RMS/length-distinct from each other and from primary fire, deterministic; alt flag/unknown-id fallbacks. |

## Distinctness table (body, trail, impact, voice)

All figures are from the same rendered run as the images
(`evidence/alt-fire-metrics.json`). "ROI px" is changed pixels vs a clean
baseline in the body/trail/impact region of interest.

| Mode | Body parts (surfaces) | Base / accent | Body AABB (m) | Body ROI / vs primary | Trail | Trail ROI | Impact burst (pooled cards) | Launch s / explosion s |
|---|---|---|---|---|---|---|---|---|
| primary rocket (reference) | body + nose + exhaust (3) | grey / `#ffad61` | 0.17×0.42×0.73 | – / – | orange ribbon 0.062 m | 3547 | landed flash + puff + scorch + shockwave | 0.50 / 0.42 (base) |
| **cluster** (w1) | drum + 3 ribs + emissive band + cap + emissive tail (7) | `#ffad61` / `#ffb066` | 0.23×0.24×0.54 | 7143 / 9249 px, Δ0.64 | spark, 0.050 m, flicker | 2853 | pop + split ring (2); bomblets add 3 staggered small pops | 0.34 / 0.42 (RMS 0.109 vs 0.130) |
| **mortar** (w4) | core + shell + collar + 4 emissive fins + emissive exhaust (8) | `#72cfff` / `#c9a6ff` | 0.24×0.25×0.76 | 7736 / 9266 px, Δ0.93 | smoke, 0.115 m, breathing | 7673 | dome + dust + rising smoke (3) | 0.40 / 0.50 |
| **mine** (w5) | flat disc + hub + 3 prongs (5) + pooled eye | `#ff806b` / `#8fd9ff` | 0.34×**0.085**×0.35 | 3864 / 8269 px, Δ0.60 | pulse, 0.070 m → 7 Hz blink armed | 1514 | sharp core + fast ring + concentric pulse (3) | 0.34 / 0.30 |
| **flak bomb** (w7) | canister + cap + 2 vents + emissive slit + emissive tail (6) | `#ffd166` / `#ff9a7a` | 0.25×0.40×0.58 | 10676 / 13353 px, Δ0.68 | smoke, 0.135 m, drifting | 8905 | pop + plume + 8-shard fragment fan | 0.36 / 0.46 |

The mine is the only flat, low body (`S.y = 0.085 m`, centre ≤ 0.06 m above its
origin) and the only one with an arming state: its emissive eye is dark while the
fuse burns, then blinks at the source's 7 Hz once the snapshot `arm` elapses
(`body-mine-armed.png`). Cluster/mortar/bomb point down their flight axis; the
mine only yaws and keeps its low stance.

Audible distinctness (from `AUDIO_ALT` in the audio gate and the capture metrics):
every alt launch and explosion differs from its primary counterpart and from the
other alts in length, peak or RMS; all 14 alt voices sit at peak 0.598 with zero
endpoints, and the whole expanded cache (47 waveforms, 311 753 samples ≈ 609 KB)
stays under the bounded-PCM contract. The mine's two arming blips ride the launch
token at +0.14 s / +0.26 s the way the source's own alt voice does; the visual
blink follows the snapshot `arm` exactly.

## Impacts reuse the landed marks

`player_fx` already treats any `alt: true` explosion as a large blast (scorch +
shockwave band + puff). This lane does not add a decal system: the capture asserts
one new pooled scorch per alt explosion, three for the cluster's three bomblet
events, and one shockwave each — all from the existing `impacts.gd` /
`mark_pool.gd` pools (High: burst pool 12, mark pool 44). The new
`weapon_effects` bursts are transient pooled cards/shards drawn on top at the
authoritative position; no ground contact is invented when the composition
cannot confirm a surface.

## Measured pool / draw costs at F9 levels

`evidence/budget-*.png` show 48 alt projectiles in flight (12 of each mode) plus
7 alt explosions at the same instant, sampled at each F9 level. Draw calls and
objects are `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` /
`RENDER_TOTAL_OBJECTS_IN_FRAME` under llvmpipe.

| F9 | markers | flash slots | fragment shards | impact pool/limit | mark limit | marks live | draw calls | objects |
|---|---|---|---|---|---|---|---|---|
| Low | 48 / 128 | 17 / 64 | 4 | 6 / 6 | 20 | 7 | 296 | 765 |
| High | 48 / 128 | 21 / 64 | 8 | 12 / 12 | 44 | 14 | 314 | 756 |
| Extreme | 48 / 128 | 21 / 64 | 8 | 20 / 20 | 72 | 14 | 314 | 771 |

Every pool is preallocated or recycled: markers never exceed `MAX_PROJECTILES`,
flash slots never exceed `CAP`, no lines are spent, and the shard fan halves at
F9 Low. Alt bursts stay enabled at F9 Low (the composition maps Low to
weapon-effects quality 1 by design), only the fan shrinks.

## Gates (all run in this worktree, all green)

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
"$GODOT_BIN" --headless --path godot --import
"$GODOT_BIN" --headless --path godot --script res://tests/weapon_effects/lifecycle.gd
"$GODOT_BIN" --headless --path godot --script res://tests/weapon_effects/rig_integration.gd
"$GODOT_BIN" --headless --path godot --script res://tests/weapon_effects/projectile_flight.gd
"$GODOT_BIN" --headless --path godot --script res://tests/weapon_effects/alt_fire.gd            # NEW
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/projectiles.gd
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/combat_feedback.gd
"$GODOT_BIN" --headless --path godot --script res://tests/combat_integration/contracts.gd
"$GODOT_BIN" --headless --audio-driver Dummy --path godot --script res://tests/protocol/audio_feedback.gd
"$GODOT_BIN" --headless --path godot --script res://tests/first_person/ads_contract.gd
"$GODOT_BIN" --headless --path godot --script res://tests/first_person/handling.gd

# rendered evidence (private Xvfb, 1280x800, GL Compatibility)
python3 tools/godot-dev/xvfb_run.py "$GODOT_BIN" --path godot \
  --rendering-method gl_compatibility --audio-driver Dummy \
  --script res://tests/weapon_effects/alt_fire_capture.gd -- \
  --output=port/native-alt-fire/evidence
```

| Gate | Result line |
|---|---|
| import | exit 0 (`.uid` sidecars generated) |
| weapon-effects | `WEAPON_EFFECTS_LIFECYCLE failures=0` |
| weapon-effects-rig | `WEAPON_EFFECTS_REAL_RIG weapons=10 poses=2 max_projection_error_px=0.00001526 failures=0` |
| projectile-flight | `WEAPON_EFFECTS_PROJECTILE_FLIGHT {"checks":22,"failures":[]}` |
| **alt-fire (new, register this)** | `WEAPON_EFFECTS_ALT_FIRE {"checks":105,"failures":[]}` |
| projectiles | `PORT_PROJECTILES_OK checks=27` |
| combat-feedback | `PORT_COMBAT_FEEDBACK_OK synthetic_checks=13 recorded_shots=610 recorded_hits=32` |
| combat-integration | `COMBAT_INTEGRATION_RESULT {"checks":1013,"failures":[],"max_projection_error_px":0.000019073486328125}` |
| audio-feedback | `PORT_AUDIO_FEEDBACK_OK checks=411` |
| first-person-ads | `NATIVE_ADS_CONTRACT {"checks":93,"failures":[]}` |
| weapon-handling | `FIRST_PERSON_HANDLING {"checks":5295,"failures":[]}` (all ten weapons, hip + ADS corridors green) |
| rendered alt-fire capture | `ALT_FIRE_CAPTURE {"checks":107,"failures":[],"bodies":4,"trails":5,"impacts":5,"budgets":3,"audio":8}` |

Adjacent owners checked green after the `combat_feedback.gd` touch:
`player-fx-integration` (37), `player-fx-impacts` (42), `combat-particles`
contracts.

## Rendered evidence (1280x800, private Xvfb, GL Compatibility)

- `evidence/body-sheet-1280x800.png` – primary rocket, cluster, mortar, mine,
  armed mine, bomb, primary grenade sphere, side by side in the same lane.
- `evidence/body-<kind>.png`, `evidence/body-mine-armed.png` – full-size pairs.
- `evidence/trail-sheet-1280x800.png` + `evidence/trail-*.png` – mid-flight
  ribbons: primary, cluster spark, mortar smoke, mine pulse, flak plume.
- `evidence/impact-sheet-1280x800.png` + `evidence/impact-*.png` – primary burst
  for reference, then each alt burst at +0.05 s, settled scorch frames, and the
  cluster three-bomblet split.
- `evidence/budget-low|high|extreme.png` – 48 alt projectiles + 7 alt explosions
  at each F9 level.
- `evidence/alt-fire-metrics.json` – every measured number above from the same
  run as the images.

## Judgement calls

- **One ribbon per projectile is kept**; the mine's arming eye is a second child
  (`Blink`) created only for mine markers, so the marker/ribbon budget stays as
  the oomph lane left it. Non-mine markers still have exactly one child.
- **Alt bursts are transient pooled cards/shards**, not decals; persistent
  surface damage remains exclusively `player_fx`'s pooled scorch/shockwave.
- **Bomblet stagger is presentation-only**: the three cluster bomblet events
  arrive on the same authoritative tick, so their pops are delayed by their own
  `bomblet` index; the authoritative positions, timings and damage are unchanged.
- **The mine launch cue carries its arming blips** at +0.14 s / +0.26 s (the
  source's own alt voice does the same) rather than scheduling against the
  snapshot `arm`; the visual blink does follow `arm` exactly.
- **Flak shrapnel `shot` events** (`altId: "bomb"`) keep the flak cannon's short
  primary report; the bomb's launch and explosion have their own crackle voices.
- **Draw-call numbers are llvmpipe**: the capture harness runs on software GL, so
  the deltas between F9 levels are meaningful, the absolute values are not a GPU
  budget.

## Deliberately left out

- No changes to `game/**` (locked), `godot/first_person/**`, `godot/player_fx/**`,
  `tools/godot-dev/verify.py`, `port/handoffs/**`, `scripts/**`, assets or
  packages.
- No new decal system, no new snapshot fields, no gameplay/simulation writes.
- The hitscan alt modes (salvo/overload/slug/chain/double/twin) get distinct
  `shot` voices only; they have no projectile body, trail or explosion to style.
- No release sweep (lead-owned) and no push.
