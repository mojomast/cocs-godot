# World presentation parity — 2026-10-01

Status: implemented, **awaiting explicit engine-slot grant and native acceptance**.
Worktree: `cocs-port-world-20261001`; base `29e242a0`.

## Current-code inventory

| Source anchor | Native code already present | Confirmed gap / delivery |
|---|---|---|
| `game/environment.mjs`, `WEATHER_PRESETS`; `game/view.mjs`, `_applyArenaLook`, `_applyLookLighting` (3891–3900) | `ambience/weather_service.gd` selects source weather, consumes `singleplayer.weather`, renders precipitation/lightning | **Ported:** weather density, fog tint, exposure, key/fill energy and linear-space light tint, relative to each native map's existing baseline. |
| `game/environment.mjs`, `wetSheen` (650–652); `game/view.mjs`, `_updateWeather` (3944), `_applyWetSheen` (4073–4091) | Material-language and Moth shaders expose roughness/metallic; imported opaque StandardMaterials carry authored values | **Ported:** source wetness integration and roughness/metallic response on those existing surfaces. Unique shared materials cloned once per map binding; originals restored exactly. |
| `game/environment.mjs`, `skyLuminance`, `skyPhase` (19–30) | `weather_profile.gd::time_at` classified raw sRGB | **Corrected:** convert to linear before luminance. Oracle includes gray values spanning both classification boundaries. |
| `game/environment.mjs`, backdrop/biome/weather particle/wind descriptors | `moth_scenery`, `graphics_atmosphere`, `weather_service`, `weather_profile` | Existing implementation retained. This audit does not treat the historical roadmap as evidence of absence. |
| `game/destination-details.mjs`, `foundryDetails` in `game/lattice-foundry-view.mjs` | Native map/material/scenery modules and authored map art already dress map surfaces | No geometry generated here. Facade/cover/door/collider provenance remains untouched. |
| `game/view.mjs::updateVehicleModels` (3004); `game/vehicles.mjs` | `vehicles/renderer.gd`, `combined_arms/fleet.gd`, `chassis.gd`, `vehicles/shot_fx.gd` already consume five chassis, turret/body transforms, rolling and shot feedback | Not redone. Native rolling intentionally uses signed forward velocity. Vehicle heat/exhaust detail needs a separate public-field and production-model audit before claiming parity. |
| `game/camera.mjs`, native `combined_arms/camera.gd` / sports chase | Existing camera ownership/control paths | No camera/root/physics modifications in this delivery. Wall-avoidance parity is not claimed by this audit. |
| LATTICE source view/foundry modules; native `lattice/world_demo.gd` | Inherits the shared world session and its new weather hook | Environmental response reaches that composition through the existing AV source feed. Dedicated LATTICE entity VFX are not claimed complete. |

## Implementation and production contract

- `godot/ambience/weather_look.gd` is a passive, map-local presentation adapter. `bind(world, environment, sun)` captures the current authored baseline, duplicates the Environment, and clones supported materials within the supplied static map subtree.
- `weather_service.gd::bind_presentation` integrates it with existing weather state, settings, focus and authoritative clock. Host snapshots are still the only campaign weather source; noncampaign profiles retain the current deterministic map/seed fallback.
- The sole shared-parent hunk is `world/session.gd::av_start`, immediately after `audiovisual.bind_session`: `audiovisual.weather.bind_presentation(world, environment, sun)`.
- Static map binding excludes session-owned actors, weapons, pickups and vehicle fleets. No transforms, collision objects, map recipes, source manifests, textures, GLBs or source pins change.
- Repeated snapshot time freezes wetness integration. Focus/stale suspension freezes the look through the existing AV host. Rewind resets wetness to the newly resolved preset. Disable/reduced motion/zero weather quality immediately applies exact dry values. Rebind/exit releases clones; a replacement environment owner is never overwritten.
- F8/F9 controls retain their existing ownership: no new scenery nodes, light nodes, emitters or particle pools. The added weather response follows weather settings, independently of optional decorative detail.

## Limits and deliberate adaptations

- At most **256 cloned materials**, **16,384 scanned nodes**, **16,384 material bindings**; two scalar writes per material when the wetness band changes. Diagnostics expose caps/visits/writes. Overflow preserves the untouched material.
- No added geometry, colliders or render passes. Actual native draw counts and CPU binding time remain to be measured; no FPS claim.
- Native applies wetness in 0.002 bands (source uses 0.02) for smoother roughness changes. The integration equation, target wetness, density/exposure and lighting coefficients match source.
- Existing normal/data maps remain intact. The browser's procedural `wetSheenTexture` roughness-map substitution is **not** ported here; the native response uses existing authored texture detail.
- Sky panorama replacement, time-of-day sky blending, interior-volume fog, rain ground splashes, dedicated entity effects and vehicle exhaust are remaining work, not silently inferred from this delivery.
- Native weather currently includes its previously shipped lightning envelope/schedule. This delivery does not claim to reconcile that pre-existing difference with the browser's 90-second/0.55-second lightning presentation.

## Source oracle

`scripts/world-weather-oracle.mjs` calls actual `ArenaView` methods and source environment functions. It exports six look samples, a 60-step transition replay, four luminance boundary cases, and eight sheen clamp samples into `godot/tests/world_weather/source.json`.

The native test compares against that fixture rather than a second JavaScript implementation of the port. It also checks shared-resource isolation, shader surface restoration, transform invariance, replacement-owner safety, duplicate timestamps, suspension, settings, rewind and map reset. Execution is pending the engine slot.
