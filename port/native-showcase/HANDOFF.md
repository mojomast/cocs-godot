# Prism Foundry — additive native exploration

Entry scene: **`res://showcase/demo.tscn`**. Baseline: `a95f8564e330410c4b65a13fd0fb71e1cdc9f1c0`.

## Unapplied lead-owned launch hooks

1. Recognize `--experience=showcase` in the launcher **before** constructing any shared world/session/client. Select `res://showcase/demo.tscn` and use the standalone native launch path. This experience has its own local `CharacterBody3D`; it does not need a Node server.
2. Keep it in a separate experiences entry, outside the source nine-map catalog/schema. Suggested visible label: **Prism Foundry · Native exploration**.
3. Include `godot/showcase/**` in native export/package staging. Its resource closure also needs existing `res://moth/library.gd`, `surfaces.gd`, `surface.gdshader`, the Moth manifest, and imported generated Moth PNGs. The library resolves textures by manifest strings, so packaging only statically referenced assets is insufficient: keep the lead's complete Moth generated-asset inclusion hook.
4. A standalone process may select the scene directly; a native Godot experience switcher may call `get_tree().change_scene_to_file("res://showcase/demo.tscn")`. Free the previous experience first through its existing lifecycle.
5. Forward user argument `--smoke` to the scene for a four-second auto-exit with `PRISM_FOUNDRY_READY` and `PRISM_FOUNDRY_SMOKE_OK` JSON feature/timing logs. `--smoke-seconds=N` selects an interval clamped to 1–300 seconds. Use the pinned renderer `gl_compatibility`.
6. CI can run `python3 port/native-showcase/verify.py`. It creates isolated HOME/XDG directories under `/tmp/opencode`, a private Xvfb with `-nolisten tcp -nolisten unix`, and per-run local evidence. It never starts or connects to a web/gallery service.

Direct development launch, from the repository root:

```sh
/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
  --path godot --rendering-method gl_compatibility --audio-driver Dummy \
  --resolution 1280x800 res://showcase/demo.tscn
```

Direct smoke launch:

```sh
/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
  --path godot --rendering-method gl_compatibility --audio-driver Dummy \
  --resolution 960x640 res://showcase/demo.tscn -- --smoke
```

For a fresh checkout, run the existing project import before launching. The verifier performs this automatically. `--audio-driver Dummy` is for this currently silent scene and avoids ALSA errors in CI.

## Optional first-person visual rig hook

After the root scene's `ready` signal:

```gdscript
var camera: Camera3D = showcase.exploration_camera
# Or get_node("Explorer/ExplorationCamera") relative to the scene root.
# Attach the concurrently authored visual-only rig through its own API.
```

`showcase.player` is the local `CharacterBody3D`; `player.velocity`, `is_on_floor()` and `controls_enabled` are available for cosmetic animation. The separate `PhotoCamera` is selected during the optional tour; `tour_index == -1` means walking. Attach the rig below the exploration camera and hide its visual root while that camera is inactive. The map ships unarmed, with no replacement weapon design or firing/network input. The scene owns its local environment and HUD; no shared-world environment mutation is required.

## Walkthrough

You arrive underneath the south mezzanine, looking directly toward the Prism Engine.

* Walk toward the reactor or around its coolant moat. Either side ramp climbs four metres to the upper loop.
* The upper loop runs continuously around the reactor. Its east portal reaches the cantilevered Salt Reach observation deck.
* At ground level, the west portal leads to the enclosed amber-lit turbine hall, with two slowly rotating recovery turbines.
* The north portal leads to the open pergola of the coolant garden, with planted water basins and a bench.
* Follow the opposite ramp down to complete a floor–mezzanine–floor circuit.

| Input | Action |
|---|---|
| Mouse / WASD | Look / walk |
| Shift / Space | Sprint / jump |
| Escape / left click | Release / recapture cursor |
| R | Return to arrival; exit photo view |
| F1 | Small controls/walkthrough help |
| P | Toggle photo viewpoints; walking is the default |
| `[` / `]` | Previous / next photo viewpoint |
| F2 | Hide / show HUD |

Focus loss clears held movement, sprint and pending jump, and releases the cursor. Falling below `y=-9` or outside `±65 m` in X/Z resets to arrival.

## Authored rendering and resource bounds

The four connected areas use actual native mesh geometry and collision. The atrium's piers, angled knees, roof trusses, copper orbital rings, turbine housings, water basins, cantilever supports and distant mesa/solar silhouette define the map. Repeated rail posts, treads, joints, pergola slats and reeds are material-batched MultiMeshes.

Moth weathered concrete/stucco, brushed metal, metal/oxide, mottled hex paneling, sand and grass retain their original imported albedo/normal images. Warm plaster, graphite metal and copper use different roughness/metallic responses. Two native spatial shaders animate the faceted prism and opaque flowing coolant. Standard depth fog, a procedural sky, one shadow-casting sun, three unshadowed omni lights and 48 bounded CPU motes work in GL Compatibility. Emission gives visible surface contrast; no glow or volumetric-fog dependency is used.

All moving nodes and particles are created once. Runtime only rotates three ring pivots and two turbine rotors, updates the local character, and refreshes short HUD text at ~6 Hz. Scene teardown releases capture, restores the caller viewport's MSAA setting and frees owned nodes. The Moth library's immutable bounded cache remains library-owned. Final counts, actual native input checks, inspected images and software-renderer timings are recorded in [README.md](README.md).

This is a local exploration showcase with native physics, not combat, campaign, or source-simulation acceptance. Hardware-GPU performance and final exported-package/launcher integration remain lead verification.
