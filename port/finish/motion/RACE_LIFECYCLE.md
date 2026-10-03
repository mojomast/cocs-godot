# Shared Puma race/soccer lifecycle follow-up

Branch `feature/race-lifecycle-sol`, base `e858c054`. Source of findings: Stormglass Production J (`b594432d`, `port/expansion-four/stormglass/PRODUCTION-J.md`). That report's two private hosted finishes and compact fixture are evidence of the candidate, not acceptance of these shared fixes. Existing failed runs and production assets remain intact.

## Production paths corrected

- `godot/sports/hud.gd`: the header now takes the selected registered map name supplied by the route's catalog, with a matching public snapshot name as fallback; an unknown map uses a neutral Puma Arena title. The Ion/Aurora defaults only apply to their actual map IDs. Results use the available scaled canvas rectangle, wrap standings, resize with the viewport, and temporarily hide the competing top/bottom panels. There is no fixture-only compact switch.
- `godot/sports/av_lifecycle.gd`: the sports audiovisual owner stops and detaches every service-owned 2D/3D/ordinary voice at F5 and exit, then uses the existing bounded audio-driver mixer drain. On restart it restores only service-initialized persistent score, ambience and weather streams; sampled vehicle and event voices reacquire cached streams on the next confirmed state/event. On exit all voice streams stay null and repeated release is inert. `godot/sports/demo.gd` calls this owner at F5, fatal disconnect and tree exit; `clear_round` still owns visual/controls cleanup. The service itself remains reusable for the new authoritative round.
- `godot/vehicle_assets/attachment.gd`: imported mesh ownership is dropped before removal from its staged PackedScene and reassigned to the persistent vehicle host after insertion. Geometry, pivot transforms, surface clones, LOD and turret pose are unchanged.
- `godot/multiplayer_worlds/sports_demo.gd` is regenerated from the edited standalone sports route by `tools/godot-multiplayer/generate-scenes.mjs`; no other generated derivative changed.

## Verification and pending native signoff

Source-only checks run here: GDScript grammar parser for edited files and native acceptance scripts, `node tools/godot-multiplayer/generate-scenes.mjs --check`, and `git diff --check`. No Godot launch, asset import, audio hardware claim, server run or Production J evidence rewrite was performed in this lane.

After the native owner's runtime slot is released, from the integrated tree:

```sh
godot --headless --path godot --script res://tests/sports/test_polish.gd
godot --headless --path godot --script res://tests/sports/lifecycle_release.gd
node tools/godot-multiplayer/generate-scenes.mjs --check
```

The authored-vehicle attachment owner check belongs to the existing hosted `godot/tests/vehicle_assets/journey.gd` runbook, with its native server, `--require-assets`, endpoint/map and journey command/role arguments; launching that route as a bare script is not a valid asset-acceptance run.

The new fixture asserts zero active voices after restart, transient stream detachment, score/weather reuse and vehicle engine reacquisition in the next round, then zero attached streams on leave. It also exercises result bounds at a 760×520/UI150-equivalent logical canvas and at 1280×800, with all standings and F5 text present. Live native follow-up should still inspect the actual UI scale/resize behavior, an immediate F5→Settings Leave process teardown with **no** WAV/playback leak diagnostics, a second playable round with audible engine/music/weather on available hardware, and absence of repeated attachment owner warnings. The existing Stormglass J private compact override should not be copied into production or counted as these shared fixes' native proof.
