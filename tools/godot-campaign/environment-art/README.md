# Campaign biome scenery

Run `LP_NUM_THREADS=1 /path/to/blender -b -t 1 --python tools/godot-campaign/environment-art/build.py` from the repository root to regenerate 15 editable `.blend` files and their compact `.glb` runtime exports. All assets are independently modeled meshes with physically based, texture-free material slots, ground origin and unit-scale bounds. Blender source is kept next to the generator; no proprietary source files or downloaded art.

Biome mapping: Rootfall = forked trees, roots, serrated ferns, mossy shoulders and fallen logs; Siltwake = reeds/cattails, wet stones and riverbank cobbles; Emberline = scrub, low basalt and slag/industrial remnants; Crown = wind-clipped trees, dry grass, lichen boulders and weathered technological scraps. The terrain shader adds continuous ground weathering and gently breaks up hard trail and stone color transitions, without changing the triangle mesh.

## Production hook for terrain owner

In `godot/campaign/terrain.gd`, immediately after `_build_horizon()` in `build(id)` and before `return true`, add:

```gdscript
var biome_art := preload("res://campaign/environment_art.gd").new()
biome_art.name = "CampaignEnvironmentArt"
add_child(biome_art)
biome_art.build(self)
```

This decorator recognizes **only** `Scenery_tree`, `Scenery_fern` and `Scenery_crag-*` MultiMesh batches that carry the existing `instance_transforms` metadata; it hides each replaced original visual batch and recreates its exact transform positions from the corresponding imported GLB. It preserves skyline trees beyond the playable bounds, authored relay/bridge/pump facilities, block visuals, authoritative surfaces, water and every collision shape. Do not also draw primitive foliage/crags from those original batches after this hook. The decorator is a child so terrain's existing rebuild child cleanup removes it naturally. The imported GLB meshes retain their own Blender-authored material slots and batch by 32 m chunk and kind.

Standalone validation without the production hook: `godot --headless --path godot --script res://tests/campaign/environment_art.gd`. This test builds every terrain recipe and adds the decorator as a child, checks collision and height invariance, placement clearance, bounds, and batched draw-call budget.
