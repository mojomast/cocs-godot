# New-map surface and Moth environment finish

Owner requested Sol agents to finish surface texturing, Moth environments,
variation, wear, signage and missing environmental detail for Helix, Gravemill
and Parallax. Current GLBs contain coloured materials but no image textures.

## Ownership

- Shared lane: `godot/multiplayer_worlds/dressing/binder.gd`, common helpers,
  shared profile validation/tests and the minimal `map.gd` integration hook.
- Map lanes: only their own `dressing/profiles/<map-id>.json`, optional map-local
  resources under `dressing/assets/<map-id>/`, map-local tests and
  `port/map-finish/<map-id>/`. Optional Blender finishing recipes belong to the
  same map-local namespace, preserving original masters and geometry.
- No map worker modifies common shaders, shared catalogs, the loader, authority,
  existing collision, or another map profile. Shared owner reconciles common API.

## Initial profile v1

JSON path: `godot/multiplayer_worlds/dressing/profiles/<map-id>.json`.
All placements use Godot world-local metres (Y up), rotations in degrees. Map root
is the same coordinate frame as source arena geometry; no arbitrary GLB scaling.

```
{
  "version": 1, "map_id": "...", "geometry_hash": "...",
  "materials": [
    {"source": "exact GLB material name", "family": "existing material-language family",
     "options": {"tint": "rrggbb", "variant": "default", "tiles_per_metre": 0.5}}
  ],
  "panels": [
    {"id": "...", "texture": "existing Moth texture key", "position": [0,0,0],
     "rotation_degrees": [0,0,0], "size": [1,1], "tint": "rrggbb", "essential": false}
  ],
  "signs": [
    {"id": "...", "text": "COOLING / C2", "position": [0,0,0],
     "rotation_degrees": [0,0,0], "size": [2,0.6], "foreground": "rrggbb",
     "background": "rrggbb", "essential": true}
  ],
  "pockets": [
    {"id": "...", "kind": "dust", "position": [0,0,0], "size": [2,2,2],
     "color": "rrggbb", "count": 12}
  ],
  "preserve_materials": ["intentional glass or special material name"],
  "budgets": {"material_variants": 16, "panels": 96, "signs": 24, "motes": 96}
}
```

Quad/sign fronts are local +Z; size is local XY. Mount just clear of an actual
verified face, not inside walls or across doorways. Sign size must contain its
text. Family options must be verified against `material_language/library.gd` and
`families.gd`, with real baked textures/normals resolved through Moth. No invented
keys or success from coloured fallback. `preserve_materials` documents intentional
exclusions such as glass; report every other unmatched surface. Initial budgets
are ceilings to validate, not performance measurements. Supported pocket kinds
are dust, pollen, ash, mist and vent; unsupported ones must fail validation.

Shared public entry: `apply(root: Node3D, map_id: String, geometry_hash: String)
-> Dictionary`, idempotently replacing owned dressing and returning counts,
matched/unmatched material names and resolved resource references. Provide a
bounded Off/Low/Full detail API and explicit cleanup; no accumulating nodes or
mutable shared-mesh resource pollution across stages/maps. Return honest missing
profile/resource diagnostics. No new physics, source events or networking.

The shared owner may add backwards-compatible fields for grounded wear masks,
macro variation or detail placement, documenting them before others depend on
them. A real projection/texture solution is required: colour changes alone do
not complete surface finishing. Existing triplanar material families avoid
re-UVing accepted geometry; do not batch-regenerate every GLB unnecessarily.

## Visual and evidence gates

- Each map gets its own palette/material story, district treatments, believable
  wear placement, environmental storytelling and useful route/district signage.
- Maintain silhouette and floor readability, collision correspondence, player/
  objective contrast, clear apertures and routes. No floating clutter, arbitrary
  glowing labels, billboard forests, excessive fog or map-wide moving noise.
- Test resource existence, exact selector coverage and profile bounds cheaply.
  Numeric/source proof does not establish rendered appearance.
- Native review later: comparable before/after overview and player-height closeups
  of every distinct district, normal gameplay, compact UI, low/full detail and
  teardown/reload. Record actual frame cadence and renderer; do not claim GPU FPS
  from llvmpipe capture.
- Preserve accepted GLBs/masters/evidence. Any asset rebuild requires explicit
  grant, new identities, reopened master and collision/visual correspondence.

## Exclusive tool grant

`FINISH-COMBINED-NATIVE-20261002-A` currently belongs to integration Astra
`ses_f0294303bffed6Fb8UJLKe4ZDz`. These four Sol lanes are source-only until a new
explicit grant: no Godot, Blender, imports, rendering, audio capture or encoding.
Lightweight image inspection, GLB parsing, Node/Python validators and source
authoring are allowed. Work in background without nested agents.
