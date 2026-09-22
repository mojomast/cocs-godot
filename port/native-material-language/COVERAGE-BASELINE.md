# Moth asset coverage — measured baseline (before the coverage pass)

Source: `godot/moth/generated/manifest.json` plus a literal scan of `godot/**/*.gd` for
each key. Counts are conservative: keys reached through variables or data-driven lookups
can read as unreferenced, so treat this as a lower bound on coverage and a reliable
ranking of what is untouched.

| Bucket | Keys | Referenced | Notes |
|---|---:|---:|---|
| textures | 31 | ~9 | most surface textures never applied outside the shader lab |
| **normals** | **13** | **~1** | **the baked bump maps are essentially unused game-wide** |
| sky | 5 | 2 | atmosphere uses a subset |
| materials (LUTs) | 5 | 2 | `entanglement` + `entanglement-arcane`; ceramic/ember/void unused |
| effects | 10 | 3 | `arc-burst`, `spark-impact`, `effect-shield` used; explosion, heal, teleport, capture-ring, weather-snow, quantum-rift, qrc-glyphs unused |

## Unused or barely used (ranked by likely visual value)

1. **Normals** — `hex_paneling`, `diamond_plate`, `metal_grating`, `corrugated_metal`,
   `hazard_stripes`, `rough_stucco`, `weathered_concrete`, `ice`, `sand`, `grass`,
   `metal`, `holographic_grid`. These are exactly the surface treatments the game needs:
   bump/detail for floors, walls, rails, ice, sand and hazard trim across all six
   playable maps and the nine locked maps.
2. **Textures** — the majority, including the metal/stone/organic family.
3. **LUTs** — `entanglement-ceramic`, `entanglement-ember`, `entanglement-void`.
4. **Effects** — `effect-explosion`, `effect-heal`, `effect-teleport`,
   `effect-capture-ring`, `effect-weather-snow`, `quantum-rift`, `qrc-glyphs`.

## What this tells us for the design language

The game already has a coherent baked palette; the problem is coverage and consistency,
not a shortage of assets. A **named material family library** built from the unused
normals + textures + LUTs, applied uniformly to world geometry, is the shortest path to a
distinct look — and every family can be reviewed on real geometry in one scene.

## Constraints carried into the pass

- Compatibility renderer first: no Decal, no SSAO/SSR, no volumetric reliance; glow
  optional and A/B measured; the look must hold with glow off.
- No new external or paid assets; every new material derives from assets already in the
  repo.
- The manifest's 101-plane inventory is asserted by `godot/tests/package_inspect.gd` and
  `godot/tests/moth/validate.gd`: derived files go in a separate `godot/moth/derived/**`
  bucket with their own manifest and must not change the 101 count.
- Render-only: no collision, terrain, spawn, pickup or nav data may change, and the arena
  compilers must not be re-run.
- Bounded: shared materials (no per-surface instances), documented texture budget, and
  measured before/after frame cadence on the same cameras.
