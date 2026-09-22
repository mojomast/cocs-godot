# Native player-state feedback lane

Impact + player-state feedback owned by this lane:

| Path | Role |
| --- | --- |
| `godot/world/combat_overlay.gd` | Screen-space drawing: existing hip reticle, hit markers and hurt pulse, plus damage-direction arc, low-health tint/heartbeat, shield-break, elimination and materialize cues. |
| `godot/world/combat_feedback.gd` | Composition wiring: creates, feeds, drains, quality-gates and reports the new owners. |
| `godot/player_fx/director.gd` | Authoritative local-player state machine (bearing, low health, break, death, respawn). |
| `godot/player_fx/impacts.gd` | Bounded, pooled, occlusion-checked material impacts. |
| `godot/player_fx/surface.gd` | Read-only surface classification from map context. |
| `godot/tests/player_fx/**` | Bounded suites plus the rendered capture harness. |

Nothing here predicts. Damage direction, break, death and respawn cues exist only
after the authority publishes the corresponding public state/event, and impacts
require the composition's own map geometry to confirm the recorded endpoint.

## Documented thresholds and budgets

| Constant | Value | Notes |
| --- | --- | --- |
| Low-health threshold | strictly below `35%` of public `maxHealth` | `Director.LOW_HEALTH_FRACTION`; dead actors never tint. |
| Heartbeat | `1.15 Hz`, strength scaled by `low_health` | Disabled at F9 Low; static bounded tint remains. |
| Direction cue | `0.9 s` actor bearing, `0.5 s` neutral pulse | Bearing recomputed every frame from the public attacker actor. |
| Shield break | `0.8 s` distinct cue | Requires `shieldBreak: true` and no spawn protection. |
| Elimination / materialize | `1.6 s` cue / genuine protection seconds | Materialize mirrors the live `protection` pool and ends with it. |
| Impact pool | Low 6, High 12, Extreme 20 | Core + dust billboard per pooled slot; no per-impact allocation. |
| Impact life | Low 0.18 s, High 0.28 s, Extreme 0.32 s | Distance-bounded to 70 m and occlusion-checked. |
| Edge frame | inset `10%` of the short axis | Every cue lives on this frame; the sight picture centre is never drawn on. |
| ADS | reticle hidden at weight `>= 0.98` (unchanged) | Edge cues scale by `1 - 0.35 * ads_weight` and stay readable. |

Surface families are chosen in a fixed order: collider/node name keywords, then
the semantic block `material`/`kind`, then the map biome, then the map default,
then neutral `stone`. The tables (`Surface.BIOME_FAMILIES`, `KIND_FAMILIES`,
`NAME_KEYWORDS`, `MAP_DEFAULTS`) are unit-tested, including the "no guess"
fallback.

## F9 / F10 honesty

* `quality_changed` reaches both new owners. Low caps the impact pool at 6,
  hides the dust layer, shortens impact life and disables the heartbeat pulse.
* `_update_metrics` adds `player_fx_low`, `player_fx_heartbeat`,
  `player_fx_direction`, `player_fx_protection`, `player_fx_cues`,
  `impact_pool`, `impact_active`, `impact_family` and `impact_counters` (F10).
* Focus loss, stale snapshots, results, identity changes and round restarts
  drain both owners through the existing `_sync_activity`/`clear_round` paths.
  Consumed public event IDs are remembered, so recovery cannot replay a cue.
* Shots already covered by the integrated weapon-effects path
  (`surface_hit: true` plus a unit normal) are counted as `legacy` and are never
  drawn twice.

## Verification

```sh
node port/native-player-fx/run-checks.mjs
```

The runner writes a timestamped `port/native-player-fx/evidence/render-<stamp>/`
containing:

* one log per headless suite (`player-fx-*`, `protocol-*`,
  `combat-integration-*`, `combined-arms-graphics`),
* `960x640/` and `1280x800/` PNGs plus `measurements-<size>.json` from
  `godot/tests/player_fx/capture.gd`.

Capture frames are labelled by provenance:

* `hip-hit`, `hip-impact-ground` and `ads-damage-direction` use recorded
  server/source events (`tests/protocol/captured.json` shot 164 and
  `tests/combat_integration/source.json` frame 0) on the real semantic
  `meridian-exchange` geometry.
* `shield-break` uses the recorded armor-break damage event from
  `tests/combat_shields/source.json` frame 3.
* `low-health`, `death`, `respawn` and `materials` are explicitly labelled
  fixtures, because the recorded matches contain no local health/death
  transition; `respawn` uses the genuine `protection: 1.5` pool from the same
  source fixture.

Each capture measures the effect against a clean baseline (edge region, impact
ROI) and asserts that the centre viewport region is pixel-identical with the
cues active, so an obscured sight picture cannot pass.

`combined-arms-graphics` can print a pre-existing intermittent
`ObjectDB instances leaked at exit` warning (reproduced without this lane's
changes, 1 of 3 runs); the runner records it under `runner.json.notes` and keeps
its own scripts strict.

## Not delivered

* No impact decals or audio changes (out of lane; the legacy weapon-effects
  owner keeps the `surface_hit` + normal cue).
* No prediction of hits, directions or protection windows.
