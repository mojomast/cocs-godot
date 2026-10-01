# Security automata — Blender source

Six original hard-surface models are authored in Blender 4.5.14 by `build.py`, saved as editable `blend/*.blend` here, and exported to `godot/campaign/art/robots/*.glb`. The imported meshes attach to the existing `robot_visual.gd` articulated pivots; animation and gameplay remain source-driven. Rebuild using:

```sh
BLENDER=/home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender
LP_NUM_THREADS=1 "$BLENDER" -b -t 2 --python tools/godot-campaign/robot-art/build.py
```

Portable official release: https://download.blender.org/release/Blender4.5/blender-4.5.14-linux-x64.tar.xz ; upstream checksum list https://download.blender.org/release/Blender4.5/blender-4.5.14.sha256 ; Linux archive SHA-256 `9ba871ff2ecd36526b77432745980b7e6664ecd0c7ca11c48849073dcfe06da3`. All dimensional, palette and component construction sources live in `build.py`.

Coordinate contract: local -Z faces front; body/turret/cradle pivots and all hip/knee pivots are inherited unchanged from `robot_visual.gd`; sole bottoms are y=0 relative to `FeetOrigin`, itself y=-0.9. LOD0 has bevelled panels, vents and fittings, LOD1 preserves big armor and role profile, and LOD2 is a cheap silhouette. Meshes are baked as one vertex-colored surface per moving assembly. No modeling code runs in-game.

Imported scene presets turn off Godot's redundant mesh LOD/shadow mesh generation: these assets already have three manually authored rigid assembly bands. Assets are loaded once per class into a shared mesh cache. Class LOD0/1/2 visible costs (triangles; draws) measured by `godot/tests/campaign/robots.gd`:

| Class | Near | Medium | Far |
|---|---:|---:|---:|
| Scrapper | 3840; 12 | 2628; 12 | 1920; 8 |
| Skirmisher | 2632; 8 | 1784; 8 | 1308; 6 |
| Sentinel | 3392; 10 | 2340; 10 | 1748; 7 |
| Mortar | 3932; 12 | 2632; 12 | 1836; 8 |
| Bulwark | 2692; 9 | 1756; 9 | 1192; 7 |
| Warden | 5564; 16 | 3900; 16 | 2872; 10 |

Matched Godot-lit synthetic evidence is stored outside the repository at `/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/enemy-blender/`: original `before/` gallery and closeups, superseded first `after/` pass, and the accepted `repair-2/final/` gallery (all LODs), six class closeups, Scrapper/Mortar near/medium/far closeups, plus the Warden's 10-second `warden-animation.mp4` (gait, windup, recoil, collapse, reset). The fixture is `godot/tests/campaign/robot_gallery.gd` with `--capture=... --focus=0..5 --pose=0..3 --lod=0..2` or `--frames-dir=...`.
