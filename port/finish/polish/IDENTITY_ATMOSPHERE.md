# Identity atmosphere parity — Sol

## Root cause and fix

`godot/identity_maps/inspection.gd:44` and `godot/tests/identity_maps/capture.gd:46` use `Style.configure_environment` from `godot/identity_maps/style.gd:193-264`: three map-specific Moth panorama horizons, FILMIC tonemapping, individual fog, ambient fill and sun. Playable Deathmatch, Vermilion Domination and Nacre Horde instead constructed `godot/native_arenas/identity_environment.gd` via `godot/native_arenas/demo.gd`, `identity_zone_demo.gd` and `identity_horde_demo.gd`, using a generic palette-derived procedural sky and LINEAR tonemap. The geometry-only identity builder supplies neither sky nor sun.

The shared composition-owned rig now delegates to the same authored `Style.configure_environment` for the three keys in `Style.ENVIRONMENTS`. It still owns exactly one WorldEnvironment and one DirectionalLight3D under the map root. Canopy Divide and Basalt Reach stay on the preexisting procedural sky/LINEAR implementation, including their custom top/horizon/fill and shadow setup. Other native Deathmatch builders remain independent. No shared global tonemap change or asset rebake.

The viewer's detached default sun/environment are freed in each of the three playable composition constructors. The session passes these freed references to `weather.bind_presentation`; `weather_service.gd` checks `is_instance_valid` and resolves the *single* pair under the map. `weather_look.gd` duplicates that environment, preserves its authored fog/exposure/fill and key light as the baseline for storm changes, then restores the original on clear/rebind. Freeing the arena on map replacement or Home frees the owned nodes; the weather service clears its lease on teardown/rebind. This keeps dynamic weather and user weather quality toggles relative to each map's authored values.

## Verification

- Source mapping check: catalog identity keys match the three authored style keys, all three live compositions build the shared rig and free viewer defaults, inspection and live both call Style, session weather discovers exactly one valid pair. **PASS** (`IDENTITY_ATMOSPHERE_SOURCE_MAPPING_OK`).
- Added `godot/tests/identity_maps/environment_parity.gd` for native follow-up: all three identity maps compare sky shader/parameters, tonemap, background, fill, fog and sun to inspection; weather lease/restore and map-root cleanup; canopy/basalt retain procedural LINEAR skies and original fill/key. **Pending native engine/import session**.
- Actual gameplay/inspection side-by-side captures and team-colour readability at day/storm are **pending** the single heavy native render session. No render/performance claims from this source-only pass.
