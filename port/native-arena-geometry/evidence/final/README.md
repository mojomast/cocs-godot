# Final native DM evidence (Cinder guard-rail fix, 2026-09-22)

These files are the current, graph-verified graphical evidence for the three
generated native Deathmatch assets. Every image carries the delivered
`geometryHash` of the asset it shows and is asserted to have real PNG
dimensions by `port/native-arena-trap-fix/capture-evidence.mjs`.

| File | Size | geometryHash |
| --- | --- | --- |
| `aurora-basin-960x640.png` | 960x640 | `94f1c30664df…` |
| `aurora-basin-1280x720.png` | 1280x720 | `94f1c30664df…` |
| `aurora-basin-1280x800.png` | 1280x800 | `94f1c30664df…` |
| `aurora-basin-1920x1080.png` | 1920x1080 | `94f1c30664df…` |
| `cinder-array-1280x720.png` | 1280x720 | `f372c98c4172…` |
| `cinder-array-1920x1080.png` | 1920x1080 | `f372c98c4172…` |
| `prism-foundry-1280x720.png` | 1280x720 | `c727d8ca82f7…` |
| `prism-foundry-1920x1080.png` | 1920x1080 | `c727d8ca82f7…` |

Capture provenance (recorded in each `<map>.log` line
`NATIVE_DM_GRAPHICAL_CAPTURE`): real Node authority, five source bots, a live
first-person rig, MSAA disabled, **software rendering** —
`gl_compatibility` on `llvmpipe (LLVM 20.1.8, 256 bits)` under Xvfb.

History (kept, not silently replaced):

- `../pre-navigation-fix/` — the pre-navigation Aurora set (old hash
  `909daa29…`) plus its log.
- `history-bdfa4203/` — the previous accepted set (prism `1901d0ae…`, aurora
  `8457812f…`, cinder `2d5e5cfa…`) with its README and logs.
