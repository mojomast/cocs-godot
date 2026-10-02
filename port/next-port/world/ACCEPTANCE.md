# World lane native acceptance — 2026-10-01

**Accepted scope:** source weather fog/lighting/exposure; wet-sheen transition and material coefficients; linear-luminance classification; production lifecycle/resource restoration. This is a lane acceptance, not the parent package/release gate.

Evidence root: `/home/mojo/.tmp-on-disk/cocs-port-world-evidence-20261001`.

## Engine and inputs

- Explicit exclusive engine grant honored; Godot processes ran serially with `LP_NUM_THREADS=1`.
- Binary: `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`.
- Native renders: GL Compatibility, Mesa llvmpipe. No Blender process or geometry authoring.
- Local semantic content copied from the parent's generated directory after the first gallery failed for absent content. Manifest source remains `515daf07589150dd3241f4ae1425cc1b093912f5`; core58ff/explicit-derived authority files are unchanged.

## Passing checks

| Check | Result / evidence |
|---|---|
| `node --test game/environment.test.mjs game/weather.test.mjs` | 46 pass, zero failures; `source-tests.tap` |
| `node scripts/world-weather-oracle.mjs --check` | Six actual Three.js look samples, 60 transition steps, four luminance cases, eight sheen clamp samples; `source-oracle.log` |
| `res://tests/world_weather/unit.gd` | Source coefficients/replay, color-space tolerance, originals untouched, shared clone reuse, shader restoration, exact dry restoration, replacement owner, transforms, fixed timestamps, focus, quality/reduced motion, rewind/rebind, cap pressure, mute, map-owned lighting and campaign ground; `world_weather-unit-accepted.log` |
| `res://tests/world_weather/standalone.gd` | Three real source-map viewer compositions through sports/combined-arms AV adapter; `standalone-worlds.log` |
| Existing `audio_new/weather_ownership.gd` | Pass; `audio_new-weather_ownership-accepted.log` |
| Existing `audio_new/standalone_lifecycle.gd` | Pass; `audio_new-standalone_lifecycle-accepted.log` |
| Existing `audio_new/horde_recipe_binding.gd` | Three production Horde compositions pass; `audio_new-horde_recipe_binding-accepted.log` |
| Existing `campaign/environment.gd` | Four chapters, repeated starts/retries and ownership teardown pass; `campaign-environment-accepted.log` |
| `node scripts/world-weather-evidence.mjs <evidence-root>` | 17 matched maps, 51 images, six passing wire journeys, zero draw-count deltas and zero cap hits; `acceptance-summary.json` |

Typical native command (headless tests):

```sh
LP_NUM_THREADS=1 "$GODOT_BIN" --headless --path godot --script res://tests/world_weather/unit.gd
```

Graphical commands (existing output directories):

```sh
LP_NUM_THREADS=1 xvfb-run -a "$GODOT_BIN" --path godot --audio-driver Dummy --script res://tests/world_weather/capture.gd -- "$EVIDENCE/nine-worlds"
LP_NUM_THREADS=1 xvfb-run -a "$GODOT_BIN" --path godot --audio-driver Dummy --script res://tests/world_weather/styles.gd -- "$EVIDENCE/styles-final"
```

## Actual-wire journeys

`scripts/world-weather-journey.mjs` owns an untouched loopback source/derived authority and a single native process. It uses real production scenes, native key/click input, settings callbacks and legal protocol restart. Public snapshots drive presentation. No actor/weather state or colliders are injected.

| Invocation suffix: kind / map / evidence directory | Snapshots | Observed result |
|---|---:|---|
| `mp rainmarket-exchange journey-rainmarket` | 262 | Movement ACKs; clear→ash after authoritative restart; settings and stale/focus recovery |
| `campaign siltwake-crossing journey-siltwake-final` | 61 | Movement; authoritative restart/spawn; clear→ash; actual F3 authority pause/resume with fixed simulation/weather clocks |
| `campaign emberline-ascent journey-emberline-second` | 50 | Movement, restart/spawn, ash, settings and stale/focus recovery |
| `mp thermal-divide journey-thermal` | 231 | Movement, restart, source-selected ash, settings and recovery; the existing source profile is honored rather than inventing snow from the art |
| `spectator rainmarket-exchange journey-spectator` | 132 | Real late-join spectator: actor −1, zero input ACK, read-only controls, world weather continues |
| `source tidal-citadel journey-tidal-accepted` | 303 | Actual snow/wetness 0.05 on revision two; dry disable/reduced/zero tier; resumed wetness 0.03581730; F8/F9 three-cycle receipts |

Example:

```sh
node scripts/world-weather-journey.mjs source tidal-citadel "$EVIDENCE/journey-tidal-accepted"
```

Each directory contains `journey.json`, production player-view PNGs and `authority-boundaries.json`. Collider signatures remained identical across weather/settings/restart in every journey. Source snapshots/actor positions were read only. Native opacity/geometry/terrain support/depth priority was not changed.

## Render review and budgets

- `nine-worlds/`: all nine original maps, `*-before.png`, `*-wet-only.png`, `*-weather.png`; inspected contact sheets `review-1.jpg` through `review-3.jpg`.
- `styles-final/`: all four campaign chapters, Rainmarket, Thermal Divide, Breakwater and Tern; same three states; inspected `review-1.jpg` through `review-4.jpg`.
- Wet-only uses the **same camera and illumination** as before. Full-weather intentionally changes exposure/light/fog. Diagnostic storm is offline art review; wire journeys use source-selected states.
- Scene identities remain distinct: Rootfall's green canopy, Siltwake's warm silt, Emberline's gray basalt, Crown's pale green corridor, polar Thermal, industrial Breakwater, dark Rainmarket and maritime Tern. Trails, barriers, floor markers and silhouettes stay legible under source storm darkening. Wet-only response is subtle rather than a blanket glow.
- Raw RGB mean absolute channel differences excluding the top 100 pixels: wet-only **0.983–4.707 / 255**. This corroborates material changes at matched illumination; it is not a perceptual-quality score.
- Measured static draw counts were **identical before / wet-only / full weather for all 17 maps**. Counts range 70–1,547 for these viewpoints; this patch adds no draw nodes/passes.
- Observed maximum: **57 materials, 588 bindings, 2,836 scanned nodes**. Caps: 256 / 16,384 / 16,384. Existing precipitation stays capped at 48; no new particle pool.
- Map-binding CPU scope only: **1,031–13,977 μs** in the final run. No FPS or GPU-time claim. Full metrics are in both capture manifests and `acceptance-summary.json`.
- Inspected production captures include `journey-tidal-final/round-two-weather.png`, `journey-siltwake-final/recovered.png`, `journey-emberline-second/recovered.png`, `journey-thermal/round-two-weather.png`, and `journey-spectator/recovered.png`.

## Failures preserved and corrected

1. `nine-capture-first.log` / `nine-empty-manifest-first.json`: missing ignored semantic content incorrectly allowed a zero-image success. Copied pinned content; gallery now requires all nine maps. `nine-capture-second.log`: 27 images, no errors.
2. Production audit found freed inherited campaign/native arena environment/light references. Adapter now resolves a unique map-owned composition; unit and live campaign checks pass.
3. AV mute previously returned before weather ticking. Moved the visual tick before the mute-only return; mute remains enabled throughout native journeys.
4. `journey-siltwake-first.log`, `journey-siltwake-second.log`, `journey-emberline.log`: fixture movement failed. The first fixture click targeted (0,0), intercepted by campaign UI; corrected to viewport center, with fresh-click retries following software-renderer warm-up/capture release. No production input gate was bypassed. Later directories/logs preserve passing runs.
5. `styles-first.log`: fixture assumed dictionary spawns; actual MP recipes use `[x,z]`. Corrected and sampled the existing support collider for matched camera height. Added watchdog; `styles-second.log`: 24 images, no errors.
6. `world_weather-unit-final.log`: test assumed an unset shader uniform reads back its shader default; Godot returns null. Corrected assertion to require the original remain unset, while the leased clone receives wetness. `world_weather-unit-accepted.log` passes.
7. Final audit found allowlisted materials relying on shader-declared scalar defaults were skipped. Defaults now resolve from the allowlisted shader's literal declarations, cached per binding. The renderer API attempt failed (wrong method name, then headless dummy renderer returned null); both `native-uniform-defaults*.log` failures are preserved. `native-uniform-defaults-accepted.log` passes the new regression. Refreshed all 51 images (`nine-capture-accepted.log`, `styles-accepted.log`), re-inspected all seven contact sheets, and reran live wetness (`journey-tidal-accepted`). Other ownership tests passed again in `*-closure.log`. Prior images are retained in `nine-worlds-pre-defaults/` and `styles-pre-defaults/`.

## Integration and honest limits

- Parent already integrated the original `656f0830` as `8f602607`. Apply the follow-up acceptance commit on top.
- Shared conflict-sensitive hunks: original `world/session.gd::av_start`; new `sports/av_lifecycle.gd::begin`; new `audio/av_service.gd::tick` mute ordering. The latter is a narrow necessary visual lifecycle correction in EXPERIENCE's file.
- Campaign ground adds only a bounded wetness uniform and the source sheen coefficients, retaining its authored moisture/color/geometry. No map recipes, GLBs, source files or authority hashes changed.
- Actual death-triggered retry and chapter-completion traversal were not re-run; authoritative same-map restart/spawn and real pause were. Four-chapter map ownership transitions are covered by the existing native campaign environment test and the matched map teardown review.
- Source procedural wet roughness texture, sky time-of-day blending, interior-volume response, rain ground splashes, vehicle heat/exhaust, and dedicated LATTICE entity effects remain outside this scoped delivery. Existing spectator camera/HUD layout is unchanged.
- No package/release files modified. Parent retains final merged gates and package publication.

## Engine slot

Native execution complete. **EXPLICIT ENGINE SLOT RELEASE** accompanies the final handoff; no Godot/Blender process is retained by this lane.
