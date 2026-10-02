# World presentation parity — 2026-10-01

Status: implemented and **native-accepted for the scoped weather ports**. See `ACCEPTANCE.md` for failures, evidence, measured limits and remaining work.
Worktree: `cocs-port-world-20261001`; base `29e242a0`.

## Current-code inventory

| Source anchor | Native code already present | Confirmed gap / delivery |
|---|---|---|
| `game/environment.mjs`, `WEATHER_PRESETS`; `game/view.mjs`, `_applyArenaLook`, `_applyLookLighting` (3891–3900) | `ambience/weather_service.gd` selects source weather, consumes `singleplayer.weather`, renders precipitation/lightning | **Ported:** weather density, fog tint, exposure, key/fill energy and linear-space light tint, relative to each native map's existing baseline. |
| `game/environment.mjs`, `wetSheen` (650–652); `game/view.mjs`, `_updateWeather` (3944), `_applyWetSheen` (4073–4091) | Material-language and Moth shaders expose roughness/metallic; imported opaque StandardMaterials carry authored values | **Ported:** source wetness integration and roughness/metallic response on those existing surfaces, including the production campaign ground shader. Unique shared materials cloned once per map binding; originals restored exactly. |
| `game/environment.mjs`, `skyLuminance`, `skyPhase` (19–30) | `weather_profile.gd::time_at` classified raw sRGB | **Corrected:** convert to linear before luminance. Oracle includes gray values spanning both classification boundaries. |
| `game/environment.mjs`, backdrop/biome/weather particle/wind descriptors | `moth_scenery`, `graphics_atmosphere`, `weather_service`, `weather_profile` | Existing implementation retained. This audit does not treat the historical roadmap as evidence of absence. |
| `game/destination-details.mjs`, `foundryDetails` in `game/lattice-foundry-view.mjs` | Native map/material/scenery modules and authored map art already dress map surfaces | No geometry generated here. Facade/cover/door/collider provenance remains untouched. |
| `game/view.mjs::updateVehicleModels` (3004); `game/vehicles.mjs` | `vehicles/renderer.gd`, `combined_arms/fleet.gd`, `chassis.gd`, `vehicles/shot_fx.gd` already consume five chassis, turret/body transforms, rolling and shot feedback | Not redone. Native rolling intentionally uses signed forward velocity. Vehicle heat/exhaust detail needs a separate public-field and production-model audit before claiming parity. |
| `game/camera.mjs`, native `combined_arms/camera.gd` / sports chase | Existing camera ownership/control paths | No camera/root/physics modifications in this delivery. Wall-avoidance parity is not claimed by this audit. |
| LATTICE source view/foundry modules; native `lattice/world_demo.gd` | Inherits the shared world session and its new weather hook | Environmental response reaches that composition through the existing AV source feed. Dedicated LATTICE entity VFX are not claimed complete. |

## Implementation and production contract

- `godot/ambience/weather_look.gd` is a passive, map-local presentation adapter. `bind(world, environment, sun)` captures the current authored baseline, duplicates the Environment, and clones supported materials within the supplied static map subtree.
- `weather_service.gd::bind_presentation` integrates it with existing weather state, settings, focus and authoritative clock. Host snapshots are still the only campaign weather source; noncampaign profiles retain the current deterministic map/seed fallback.
- The shared-parent hook is `world/session.gd::av_start`, immediately after `audiovisual.bind_session`: `audiovisual.weather.bind_presentation(world, environment, sun)`. Standalone sports/combined-arms uses the equivalent hook in `sports/av_lifecycle.gd::begin`.
- Campaign and several native arenas free their inherited viewer environment/light. `bind_presentation` accepts these invalid references safely and resolves the map subtree's **unique** WorldEnvironment/DirectionalLight3D. Ambiguous owners are not guessed. The existing campaign atmosphere remains the persistent baseline and survives same-map retries.
- `audio/av_service.gd::tick` now advances weather before its audio-mute early return. Native testing demonstrated that visual weather otherwise froze while muted. Focus and stale gates still precede both audio and weather.
- Static map binding excludes session-owned actors, weapons, pickups and vehicle fleets. No transforms, collision objects, map recipes, source manifests, textures, GLBs or source pins change.
- Repeated snapshot time freezes wetness integration. Focus/stale suspension freezes the look through the existing AV host. Rewind resets wetness to the newly resolved preset. Disable/reduced motion/zero weather quality immediately applies exact dry values. Rebind/exit releases clones; a replacement environment owner is never overwritten.
- F8/F9 controls retain their existing ownership: no new scenery nodes, light nodes, emitters or particle pools. The added weather response follows weather settings, independently of optional decorative detail.

## Limits and deliberate adaptations

- At most **256 cloned materials**, **16,384 scanned nodes**, **16,384 material bindings**; at most two scalar writes per material when the wetness band changes (one for campaign ground). Diagnostics expose caps/visits/writes. Overflow preserves the untouched material.
- No added geometry, colliders or render passes. Across 17 matched native map views: 9–57 materials, at most 588 bindings / 2,836 visited nodes, no cap hits; before/wet-only/weather draw counts identical. Final measured bind CPU time was 1,031–13,977 microseconds on this llvmpipe run. This is map-binding work, not frame time or an FPS claim.
- Native applies wetness in 0.002 bands (source uses 0.02) for smoother roughness changes. The integration equation, target wetness, density/exposure and lighting coefficients match source.
- Existing normal/data maps remain intact. The browser's procedural `wetSheenTexture` roughness-map substitution is **not** ported here; the native response uses existing authored texture detail.
- Sky panorama replacement, time-of-day sky blending, interior-volume fog, rain ground splashes, dedicated entity effects and vehicle exhaust are remaining work, not silently inferred from this delivery.
- Native weather currently includes its previously shipped lightning envelope/schedule. This delivery does not claim to reconcile that pre-existing difference with the browser's 90-second/0.55-second lightning presentation.

## Source oracle

`scripts/world-weather-oracle.mjs` calls actual `ArenaView` methods and source environment functions. It exports six look samples, a 60-step transition replay, four luminance boundary cases, and eight sheen clamp samples into `godot/tests/world_weather/source.json`.

The native test compares against that fixture rather than a second JavaScript implementation of the port. It passes checks for shared-resource isolation, shader surface restoration, transform invariance, replacement-owner safety, duplicate timestamps, suspension, settings, rewind, map reset, material-cap pressure, muted presentation and freed inherited lighting references. Six production websocket journeys and 51 matched-view images provide separate integration/render evidence.
