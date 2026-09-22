# Final native DM evidence (refreshed 2026-09-22, trap-fix lane)

These files are the current, graph-verified graphical evidence for the three
generated native Deathmatch assets. Every image carries the delivered
`geometryHash` of the asset it shows and is asserted to have real PNG
dimensions by `port/native-arena-trap-fix/capture-evidence.mjs`.

| File | Size | geometryHash |
| --- | --- | --- |
| `aurora-basin-960x640.png` | 960x640 | `8457812f7845…` |
| `aurora-basin-1280x720.png` | 1280x720 | `8457812f7845…` |
| `aurora-basin-1280x800.png` | 1280x800 | `8457812f7845…` |
| `aurora-basin-1920x1080.png` | 1920x1080 | `8457812f7845…` |
| `cinder-array-1280x720.png` | 1280x720 | `2d5e5cfa4453…` |
| `cinder-array-1920x1080.png` | 1920x1080 | `2d5e5cfa4453…` |
| `prism-foundry-1280x720.png` | 1280x720 | `1901d0aed12c…` |
| `prism-foundry-1920x1080.png` | 1920x1080 | `1901d0aed12c…` |

Capture provenance (recorded in each `<map>.log` line
`NATIVE_DM_GRAPHICAL_CAPTURE`): real Node authority, five source bots, a live
first-person rig, MSAA disabled, **software rendering** —
`gl_compatibility` on `llvmpipe (LLVM 20.1.8, 256 bits)` under Xvfb. The
1920x1080 Prism pass that previously aborted now completes, and the stale
pre-navigation Aurora images (old hash `909daa29…`) have moved to
`../pre-navigation-fix/` rather than being silently overwritten.

The two log files are regenerated from this tree with the same revisions as
the images: `actual-source-maps.log` (source-match acceptance with per-map
`geometryHash`) and `deterministic-rebuild.log` (byte-identical second
rebuild). `native-dm-colliders.json.gz` / `native-dm-physics.json.gz` are the
earlier retained exports and are superseded by the current generated assets
and `port/native-arena-geometry/verification.json`.
