# Shared new-map dressing integration

Source implementation; native execution and visual acceptance **pending Astra's
exclusive grant**. No Godot/Blender/import/render/audio/encoding was run here.

## Production contract

`res://multiplayer_worlds/dressing/binder.gd` exposes:

- `apply(root: Node3D, map_id: String, geometry_hash: String) -> Dictionary`
- `cleanup(root: Node3D)` restores original instance surface overrides and frees
  owned nodes immediately.
- `set_root_detail(root: Node3D, level: int)` persists a root-local detail setting.
  Off restores original art and releases detail geometry; Low textures surfaces
  and retains essential panels/signs; Full adds all authored details and pockets.
- Created `NewMapDressing` nodes expose `set_detail(level)` and `diagnostics()`.
- `map.gd` calls apply after art instantiation and exposes `set_dressing_detail`.
  An optional `dressing/detail_control.gd` OptionButton binds a map via `bind_map`.

Only the three exact CONTRACT geometry identities are eligible. Recognition is
not route registration. Parallax art/catalog registration remains with its map
and integration owners. Unknown maps return `ineligible`; eligible missing JSON
returns `missing_profile`, with no log output or material change. Other statuses
include `identity_mismatch`, `invalid_profile`, `unresolved_resources`,
`missing_art`, `incomplete_coverage`, and `ready`. Inspect `errors` too: native
font metrics can reject a sign that was too small. Counts are ceilings/actual
constructed objects, not measured performance.

Selectors match exact imported **mesh surface material resource names** beneath
`BlenderArtNoGameplayCollision`. Materials are bound per instance/per surface.
Cached family materials are duplicated before parameter changes. Shared meshes,
cached materials and shader resources remain immutable. Preserved materials retain
their original alpha/emission; Helix glass and Parallax sea are exclusions.
Parallax mirror is explicitly opaque optical alloy. Missing resource resolution
aborts dressing construction; incomplete selector coverage is reported honestly.
Existing instance-wide material overrides are reported rather than silently
defeating a surface binding.

## Backwards-compatible v1 fields (published here)

Every original v1 field remains supported; **unknown keys are rejected**.

### Panels

Optional `normal`: exact normal key accepted by the material-language registry,
e.g. `baked:metal` or `derived:normal--metal-oxide`. With no explicit normal, the
texture's same-name baked/derived normal is required. `brushed_metal` has no
same-name normal: Helix `pump-access-0/1/2` explicitly select `baked:metal`.

Optional wear fields:

```json
{"wear_mask":"dust-field","opacity":0.22,"feather":0.15,"seed":610022}
```

- `wear_mask`: **existing Moth texture** key, resolved before any dressing binds.
- `opacity`: finite 0..1, default 1 when a mask is present.
- `feather`: finite 0..0.5, default 0.15; normalized local quad UV edge width.
- `seed`: integer 0..2147483647, default 0; deterministic repeat-texture UV offset.
- Alpha is mask luminance × edge feather × opacity. Wear uses lit, non-emissive
  texture color, modest source normals and roughness. Depth testing stays enabled;
  it does not write depth or cast shadows. No mask means an opaque service inset.
- `opacity`, `feather` and `seed` without `wear_mask` fail validation.

Fields are serialized on each authored placement, with no runtime ID heuristics.
Geometry/face mounting stays in map authors' proof. The production binder never
projects a panel automatically across doors or routes. Existing authored offsets
are 18 mm Helix, 45/65 mm Foundry, and independently verified Parallax offsets;
the new shader introduces no additional displacement. Native proof samples actual
imported triangles behind nine points per mount.

### Surface material options

All existing `material_language/library.gd` bounded options are accepted,
including real packed-data roughness variation and normal strength. New optional
options operate on a private extension of the existing family shader:

| Field | Range / default |
|---|---|
| `macro_tiles_per_metre` | 0.01..0.25 / 0.06 |
| `macro_strength` | 0..0.5 / 0 |
| `wear_strength` | 0..0.65 / 0 |
| `wear_tint` | six hex RGB digits, required for nonzero wear |
| `wear_height_min`, `wear_height_max` | -100..100 map-local metres; required ordered interval for nonzero wear |
| `wear_roughness` | 0..1 / 0.95 |

Macro variation samples the **existing packed data texture** triplanarly at a
separate architectural scale. Height-bound deposition uses that texture's AO
creases, a selected source material, and an authored height interval. This is
texture-backed surface response, not random map-wide noise or a claim of simulated
rust/paint loss. Local wear panels are the preferred solution for district-specific
deposits. The global family shader/library were not edited.

### Limits and environments

Hard ceilings: 32 material variants, 96 panels, 24 signs, 12 pockets, 96 motes.
Counts also obey lower profile budgets. Positions are bounded to ±512 m;
panel/sign dimensions 0.05..16 m, pocket dimensions 0.05..8 m. Native font metrics
fit signs with 12% margin and reject cap heights under 8 cm. Colors require a
4.5:1 foreground/background contrast ratio. Signs face local +Z and depth-test.

Dust/pollen/ash/mist/vent are shader-animated, fixed-anchor MultiMesh pockets using
existing Moth `dust-field` and `flow-field`, depth-tested, with no CPU particle
updates or timer. Each is at most 32 small sprites and fades beyond 55 m. Mist is
a sparse small-sprite pocket, not volumetric fog. Conservatively expanded AABBs
cover shader excursion. Collision/routes remain authored geometry; map owner
receipts validate placement envelopes. No source events or networking are added.

## Source checks / pending native proof

```sh
node --test port/map-finish/shared/validate.test.mjs
node port/map-finish/shared/validate.mjs PROFILE.json ART.glb
gdparse godot/multiplayer_worlds/dressing/*.gd godot/multiplayer_worlds/map.gd
```

The shared Node checker reads option bounds, exact identities and family recipes
from production GDScript, resolves real PNGs, checks closed schema, contrast,
budgets and exact GLB names. It accepts explicit input paths, never scans active
worker profiles. Map-owned source validators additionally prove backing faces.
Parallax schema/resources can be checked here; its geometry validator requires
the isolated accepted GLB and cannot be claimed passing in this checkout.

Prepared native entry: `res://multiplayer_worlds/dressing/proof.gd`, with
`--map=<id> --proof-dir=<absolute dir> --camera=x,y,z --target=x,y,z` after the grant.
It checks actual profile loading, selector/resource coverage, native negative
schema cases, face mounting, Off/Low/Full budgets, reapply/cleanup/reload and
immutable mesh/material restoration. It captures identical-camera detail pairs
and records raw frame cadence plus renderer. Repeat per district using the map
owners' camera plans. Native type-checking, shader compilation, readable glyphs,
after-images, full gameplay/compact UI, lifecycle observations and frame costs
are pending. This harness has not run; source grammar is not engine type checking.

## Viewer / missing detail findings

The actual production `multiplayer_worlds/demo.gd` uses ambient energy 0.68 and a
fixed shared daylight sky; `viewer.gd` uses 0.8. These settings can wash out normal
and wear contrast differently. The older `world/viewer.gd` uses a different
procedural geometry/material path and does not prove this binder's appearance.
Use the production map root and identical lighting/FOV for paired captures.
Lighting/route redesign is not part of this shared finish. Owner recommendations:
Helix already has real articulated fronds; review species variety and grass-normal
response, rather than inventing missing foliage. Foundry owns optional parapet
bolts/valve handles; preserve aisles. Parallax's accepted archive/pump share an
architectural rhythm; its separate interiors-v2 promotion must revalidate mounts.
