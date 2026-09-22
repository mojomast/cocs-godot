# Surface roles → published material families

Application lane (`port/native-material-apply`). The library that owns the
families is `res://material_language/library.gd` (library lane); nothing here
invents a family, a texture or a shader. Every surface decision in this pass is
"which published family + variant reads as this real surface", then "what tint
keeps the map's authored palette".

## Resolution order (one code path)

`godot/world/environment_style.gd` is the application seam. Given a role:

1. `ROLE_TABLE[role]` names `family` + `variant` + the library's own bounded
   options (`tiles_per_metre`, `texture_strength`, `albedo_gain`,
   `normal_strength`, `roughness`, `metallic`, `lut_gain`, …).
2. `MAP_ROLE_CHOICES[map_id]` may re-point the role for one map's identity
   (panel cities keep the mottled hex panel, the desert keeps stucco, Ember
   keeps scorched armour and basalt).
3. A family name that is not in `MaterialLanguage.families()` resolves to
   `null` and the caller falls back to its pre-pass Moth surface material — no
   look-alike is hand-rolled. `MaterialLanguage.cache_stats().rejected` stays
   the honest signal if the library's 96-material cap is ever hit.

The library returns one shared `ShaderMaterial` per
(family, variant, options, tint) signature: N surfaces, one material, no
per-surface instance.

## The role vocabulary

| Role | Family | Variant | Used for |
|---|---|---|---|
| floor / sand | regolith | default | sandy ground, roads, aprons |
| floor-built / stone / wall | pearl-ceramic | cast | poured/cast floors, concrete walls |
| floor-road | hazard-industrial | deck | service roads, apron plating |
| floor-grass / foliage | regolith | verdant | grass, tree crowns |
| snow | polar-ice | default | smooth frozen ground |
| ice | polar-ice | cracked | lake, berms, ice pods |
| rock / wall-natural / dirt | regolith | mossy | ruins, cave rock, earth |
| ash | regolith | scoured | volcanic basalt, ash fields |
| wall-worn / cut | pearl-ceramic | worn | weathered cut stone |
| wall-panel / landmark | pearl-ceramic | polished | panel cities, columns, plinths |
| wall-stucco | enamel-glaze | stucco | plastered shells, desert masonry |
| display | enamel-glaze | default | instrument housings |
| rail / structure / prop | brushed-alloy | default | rails, beams, masts, props |
| cover | brushed-alloy | plate | crates, covers, service hatches |
| machinery | brushed-alloy | circuit | reactors, relay feeds, consoles |
| grating / deck | brushed-alloy | grating | catwalks, walkway decks |
| pipe | oxidised-copper | default | pipework, verdigris fittings |
| pipe-scorched | oxidised-copper | scorched | Ember crucible machinery |
| riveted | oxidised-copper | riveted | riveted retainers |
| hazard | hazard-industrial | default | race rails, soccer walls, warning steel |
| hazard-deck | hazard-industrial | deck | deck plating |
| hazard-grate | hazard-industrial | grating | accent caps on equipment |
| growth / growth-veined | bioluminescent-membrane | default/veined | organic growth, vent flora |

## Tiling and texel density (documented, no shimmer)

Baked tiles are 48–64 px; normals are 32 px. `tiles_per_metre` is cycles per
metre, so texel density = tile_px × tiles_per_metre. The world-space triplanar
sampler is `filter_linear_mipmap_anisotropic` and the family shader fades
normal/crease detail with distance (`detail_fade`, default 26 m), which is what
stops a 64 px tile from shimmering on a long floor.

| Surface | tiles/m | px/m (albedo) | px/m (normal) | normal_strength |
|---|---:|---:|---:|---:|
| natural ground (rock, ash) | 0.30–0.50 | 19–32 | 10–16 | 0.34–0.40 |
| floors (cast, plating) | 0.45–0.60 | 29–38 | 14–19 | 0.30–0.35 |
| grass / foliage | 0.70–0.80 | 45–51 | 22–26 | 0.30–0.34 |
| walls (cast, worn, stucco, panel) | 0.42–0.60 | 27–38 | 13–19 | 0.28–0.34 |
| ice / snow | 0.22–0.30 | 14–19 | 7–10 | 0.16–0.28 |
| rails / masts / props | 0.70–1.10 | 45–70 | 22–35 | 0.30–0.34 |
| grating / decks | 0.60–1.00 | 29–64 | 19–32 | 0.30–0.34 |
| hazard trim | 1.00–1.40 | 48–67 | 32–45 | 0.34–0.35 |
| organic growth | 0.90–1.00 | 58–64 | derived | 0.30–0.32 |

Rules the table enforces: floors and walls never exceed 0.6 tiles/m on a 64 px
tile, rails/masts never exceed 1.1, hazard trim is where the density is meant to
read fast (1.0–1.4). The pre-pass used 0.35–0.4 tiles/m almost everywhere, so
the *bump* is what this pass adds on most surfaces, not texel density.

## Identity and exposure policy

The authored palette is the tint, and every role sets `albedo_gain` to the
reciprocal of its baked tile's measured mean luminance (sand 0.44,
weathered_concrete 0.40, hex_paneling 0.46, ice-cracked 0.48, grass 0.29,
rock-moss 0.30, rock 0.02, brushed_metal 0.25, metal-oxide 0.41,
riveted_armor-scorched 0.44, diamond_plate 0.49, metal_grating 0.50,
circuit_board-etch 0.31, hazard_stripes 0.44) so `ALBEDO` lands on the tint
instead of the family's illustrative palette. `texture_strength` stays
0.30–0.58: the tile reads as grain and bump, not as a repaint. LUT accents are
kept off structural roles and switched on where they mean something: hazard
warning rims, machinery console sheen, organic pulse, instrument displays.

## Where each site applies the vocabulary

| Site | Composition | Roles applied |
|---|---|---|
| nine locked maps | `world/viewer.gd` + `world/environment_style.gd` | every block kind by role (wall, wall-panel/stucco/worn, rock, rail, cover, prop, machinery, pipe, grating, hazard, floor-grass, foliage), plus family normals on `terrain_material()` and the trim/accent detail batches |
| Prism Foundry | `native_arenas/maps/prism-foundry.gd` | concrete→wall, warm→wall-stucco, floor→floor-built, dark→prop, metal→rail, copper→pipe, tread→grating, sand→sand, rock→rock, foliage→foliage |
| Aurora Basin | `native_arenas/maps/aurora-basin.gd` | snow→snow, ice/lake→ice, deck→grating, metal/gold→rail, shell→wall (gains matched to the basin's authored ice exposure) |
| Cinder Array | `native_arenas/maps/cinder-array.gd` | deck→grating, metal→rail, dark→prop, orange→hazard, rock→ash |
| three identity maps | `identity_maps/map.gd` | floor/shell/cut/enamel/accent/trim per map, tinted from the recipe palette |
| scenery props | `moth_scenery/scenery.gd` | plate normals resolved through `MaterialLanguage.normal_map()` (baked first, derived fallback) with a per-kind `normal_depth` |
| atmosphere | `graphics_atmosphere/atmosphere.gd` | distant ground grain from `MaterialLanguage.derived("data--sand")`, faded before the sky blend |

Terrain support surfaces keep `moth/surface.gdshader` on purpose: it carries the
locked camera DEPTH-priority contract, and the material language supplies their
baked normals instead. The family shader writes no DEPTH, which is why the
arena/identity/presentation surfaces that moved to it regained early-Z.
