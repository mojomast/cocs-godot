# Moth material language

Eight named families built only from the baked Moth asset set, one shader, one
shared material per family (plus variants), world-space triplanar, GL
Compatibility first. Written for the applying lane and for the owner's eye.

* Interface: `res://material_language/library.gd`
* Family table: `res://material_language/families.gd`
* Shader: `res://material_language/family.gdshader`
* Review viewer: `res://material_language/gallery.tscn` (F toggles glow, N toggles normals, L cycles lighting)
* Derived assets: `res://moth/derived/**`, built by `tools/godot-moth/derive.mjs`
* Coverage and cost evidence: `port/native-material-language/`

## 1. The palette story

The bake already contains a coherent mineral identity: desaturated teal hex
panels, bone-white stucco, blue-grey concrete, a nearly black ice tile, amber
hazard paint, turquoise alien chitin, purple-tinged diamond plate. The families
do not invent colours; they *name* eight places on that palette and then move the
baked pixels into them with a tint multiplier plus a bounded exposure gain.

The order is the colony's own material history, and it is the order the tabs in
the viewer are numbered:

| # | family | role in the story | tint (primary palette slot) | baked base it is built from |
|---|---|---|---|---|
| 1 | `pearl-ceramic` | fired interior mineral | `#cfc9ba` warm bone | `hex_paneling-mottle`, `weathered_concrete*` |
| 2 | `enamel-glaze` | kiln-bright instrument housing | `#e2ecef` cool milk | `hex_paneling`, `ice-cracked`, `rough_stucco-weathered` |
| 3 | `brushed-alloy` | machined working metal | `#b9c5cf` cold steel | `brushed_metal`, `diamond_plate`, `metal_grating`, `circuit_board-etch` |
| 4 | `oxidised-copper` | decay / verdigris | `#7dae8f` patina green | `metal-oxide`, `riveted_armor*`, `metal` |
| 5 | `bioluminescent-membrane` | living chitin, the only animated accent | `#4f8f86` deep teal | `alien_chitin`, `macro-organic` |
| 6 | `regolith` | ground truth: sand, rock, moss, grass | `#c6b189` dust | `sand`, `rock`, `rock-moss`, `grass` |
| 7 | `polar-ice` | frozen water over the same mineral story | `#cfe6ee` glacier white | `ice-cracked`, `ice` |
| 8 | `hazard-industrial` | amber warning over corrugated stock | `#d5c9a3` paint | `hazard_stripes`, `corrugated_metal`, `diamond_plate`, `metal_grating` |

Two rules make that a language rather than eight presets:

1. **Every albedo multiplier is a palette slot**, never an ad-hoc colour. A family
   is its palette; `describe(family).palette` is the single source, and
   `describe(family).tint` is the slot the shader actually multiplies with.
2. **Two families never share a primary slot.** The contract test asserts this, so
   the tabs stay distinguishable at a glance in the sheet.

## 2. Which family belongs where

| surface | family | why |
|---|---|---|
| interior walls, pillars, hull plates, relic inlay | `pearl-ceramic` | matte fired mineral; the mottled tile is the only interior-scale ceramic in the bake |
| clean-room walls, display housings, medical bays, prop shells | `enamel-glaze` | low roughness, no metal; the holographic grid normal reads as glazed panel edges |
| catwalk rails, machinery, bulkheads, weapon hardpoints | `brushed-alloy` | the only directional metal texture, `metal` normal carries real relief |
| pipes, ruin machinery, vent hoods, salvage | `oxidised-copper` | `metal-oxide` pixels are corrosion; the family adds nothing but patina and a crease-gated cold bloom |
| alien growth, organic vents, creature-adjacent props | `bioluminescent-membrane` | chitin is near-flat in luminance but saturated in colour; the accent is the only one that travels |
| floors, dunes, terrain caps, crater rims | `regolith` | the two strongest baked normals (`sand`, `rock`) live here |
| ice floors, frozen walls, crystal props | `polar-ice` | the only gloss family with a baked crackle atlas |
| hazard trim, walkways, door frames, barriers | `hazard-industrial` | the only family whose accent is masked to the baked yellow, so the glow means "walk carefully" |

## 3. Naming rules

* **Family id** = `surface-intent` in lower-kebab (`pearl-ceramic`). Stable; the
  applying lane persists these strings.
* **Variant** = a *source swap*, never a tuning shortcut: `variant: "scoured"`
  binds `rock` + the `rock` normal instead of `sand`. Variants are sorted and
  listed by `variants(family)`.
* **Options** = uniform tuning for an instance (`tiles_per_metre`, `tint`,
  `glow`, `normal_strength`, …). Options are canonicalised and bounded; unknown
  keys are ignored. Two calls with the same canonical options return the *same*
  material object.
* **Derived keys** are `kind--source`, so `data--rock`, `normal--alien_chitin`,
  `mask--hazard_stripes`. `derived(key)` also accepts the bare source name.
* **Normal ids** are `baked:<key>` or `derived:normal--<key>` when stated
  explicitly; `normal_map(key)` prefers the bake and falls back to a derived
  normal only when the bake has none.

## 4. Rules that keep it a language

1. **At most one albedo atlas, one normal, one LUT per material.** Variants may
   swap which single atlas or normal is bound; nothing stacks two normals. The
   shader has exactly one normal sampler, so this is structural, not a promise.
2. **At most four base textures per family** across all its variants (measured in
   `budget().per_family[*].bases`; the widest is four).
3. **Emissive only where it means something.** Every family reads its accent from
   one of the five baked LUTs at a declared phase, and each behaviour is
   documented in `describe(family).emissive.behaviour`. Emissive is never a flat
   glow: it is a fresnel/phase band, optionally gated by a derived mask
   (`hazard-industrial`) or by derived creases (`regolith`, `oxidised-copper`).
4. **The look must hold with glow off.** `glow = false` removes the accent
   entirely; the sheet is captured with glow on *and* off and the difference is
   measured (it is a switch, not the lighting).
5. **No new pixels except derived maps with a manifest.** `godot/moth/derived/**`
   is generated by one deterministic tool from the shipped bake; the 101-plane
   inventory in `godot/moth/generated/manifest.json` is untouched.
6. **Bounded identity.** Eight families, 22 variants, one shader, a 96-material
   cache. Adding a ninth family requires deleting something else; the point of
   the limit is that the owner can still recognise the game.

## 5. Tiling, texel density, shimmer

The shader is **world-space triplanar** with no UV or tangent input, matching
`res://moth/surface.gdshader`. That is deliberate: arena and scenery meshes have
no trustworthy UVs (one lane already reserves `UV.x` for depth priority), and
triplanar lets the applying lane re-materialise geometry without editing meshes.

Honest density, per family (`tile_px × tiles_per_metre = px per metre`):

| family | tile px | tiles/m | px/m | notes |
|---|---:|---:|---:|---|
| `pearl-ceramic` | 64 | 0.50 | 32 | architectural panels; one tile is 2 m |
| `enamel-glaze` | 48 | 0.80 | 38 | glazed plate, one tile is 1.25 m |
| `brushed-alloy` | 64 | 1.10 | 70 | rail/machinery scale |
| `oxidised-copper` | 64 | 0.70 | 45 | ruin scale, coarse on purpose |
| `bioluminescent-membrane` | 64 | 1.00 | 64 | one tile is 1 m |
| `regolith` | 64 | 1.50 | 96 | the finest tile in the bake (`sand`) |
| `polar-ice` | 64 | 1.00 | 64 | crackle atlas at 1 m |
| `hazard-industrial` | 48 | 1.00 | 48 | stripes stay legible at 1 m |

The bake tops out at 96 px/m. Close-up magnification is a known limit: these are
64 px tiles, and no amount of shader work invents texels.

Distance behaviour:

* mipmaps are generated and every sampler is `filter_linear_mipmap_anisotropic`;
* `detail_fade` (2–200 m, default 26) fades the normal, the crease darkening and
  the accent as `1 / (1 + (d/fade)²)`. The accent falls to 15% beyond the fade
  distance, which is what stops the emissive speckle on a distant floor;
* derived roughness is deliberately low-frequency (the high-pass term is blurred
  by 2 px) so a rough surface cannot fizz under a moving specular highlight.

`DEPTH` is not modified. The existing `moth/surface.gdshader` adds a 1e-6·UV.x
coplanar priority bias for semantic support surfaces; this language writes normal
opaque depth. If the applying lane replaces a surface that relied on that bias,
it should report to lead rather than expecting the bias here.

## 6. The LUT accent, precisely

The five baked LUTs are 24×24 or 32×32 RGB planes, sampled as
`texture(lut_r, vec2(fresnel, phase))`. Measured facts:

* All five **R planes are white-on-black spatial masks** — the bright texels form
  one small blob in (fresnel, phase) space, not a gradient. The accent *colour*
  therefore comes from the family palette, and the LUT supplies the *geometry*
  (which viewing angles, which phase).
* **All five T planes are entirely black** in this bake. The `lut_t` sampler stays
  bound at `lut_t_gain = 0` so a future re-bake can light it up without a shader
  edit; nothing in the language samples a black plane to no effect.
* Measured blob regions (u = fresnel, v = phase), read from the shipped pixels:
  * `entanglement` — facing wash, fresnel 0.08–0.27, phases 0.46–1.0
  * `entanglement-arcane` — mid band, fresnel 0.38–0.50, phases 0.67–1.0
  * `entanglement-ceramic` — mid band, fresnel 0.53–0.66, every phase
  * `entanglement-ember` — rim, fresnel 0.80–1.0, every phase
  * `entanglement-void` — mid band, fresnel 0.53–0.66, only phases 0.94–1.0
    (a phase gate, not a rim)
* Each family declares one LUT, one phase and one gain; `regolith` uses the void
  phase gate on purpose, so its "glint" is invisible at the default phase and only
  appears if a lane drives the clock there (measured: turning glow off changes
  0.1% of that panel's pixels).
* Two knobs place the band, and both are documented in `describe()`:
  `lut_fresnel_power` (how tightly the accent hugs grazing angles; 3.0 is the
  baked/existing convention, `bioluminescent-membrane` uses 1.0 so the band sits
  on the body rather than the silhouette) and `lut_fresnel_bias`.
* `pulse_speed`/`pulse_depth` breathe the phase with a bounded
  `sin(clock · speed · 0.6)` travel instead of an unbounded drift: the band stays
  inside its LUT window at any clock and merely inspects the edges on the turn,
  which is what keeps a 33-60 s cycle from spending most of its life invisible.

## 7. Derived assets (`godot/moth/derived/**`)

`tools/godot-moth/derive.mjs` reads the shipped PNGs listed in
`godot/moth/generated/manifest.json`, verifies each source plane against its
recorded `pixel_sha256`, and writes 28 planes plus its own manifest:

* **24 `data--*` planes** (one per family base texture): R = occlusion proxy,
  G = roughness, B = signed detail, A = 255, untagged linear. Roughness starts
  from a documented per-class prior and is modulated by the local high-frequency
  contrast (blurred); occlusion is `1 - 1.6 · max(0, blur₆(L) - L) / max(blur₆(L), 24)`,
  floored at 80/255. The height field is Rec.709 luminance for most tiles, or the
  mean of luminance and the max channel when that carries more structure
  (measured per texture, recorded as `height_channel`).
* **2 `normal--*` planes** where the bake has no normal: `alien_chitin` and
  `riveted_armor`. Height from the same field, Sobel with wrap-around edges, and
  a *per-texture normalised* magnitude so the declared target (0.30 / 0.55 mean
  slope) is what the file contains.
* **2 `mask--*` planes**: `mask--hazard_stripes` (baked yellow bands, 48.3% of
  texels on) and `mask--circuit_board` (green traces), min/max normalised per
  texture so off is exactly 0 and on is exactly 255.

Determinism: integer kernels (rounded box blur, Sobel difference, min/max
normalisation); the only floating point is `sqrt`/division/`round`, which are
IEEE-deterministic. No timestamps, no RNG, no locale, no colour management. The
test re-derives twice into temp directories and compares bytes with each other
*and* with the committed bucket.

Honesty about the green channel: the baked normals are 8-bit quantised and
largely sparse, so the sign convention cannot be proven from them. The tool
correlates derived normals against the eight baked normals that share a base
texture (mean Pearson correlation +0.051 for the chosen sign vs −0.012 for the
flipped one, best single sample +0.28 on `rock`) and records the whole
calibration table in the manifest under `calibration`. The choice fixes texture
orientation; it is not a claim of physical parity.

## 8. Cost (measured)

All numbers are measured by `Language.budget()` (PNG bytes on disk, VRAM estimate
= IHDR RGBA8 + mipmaps) and captured in the evidence JSON.

* One shader, 8 families, 22 variants, 7 samplers per material.
* **Shared materials only**: `material()` returns one cached `ShaderMaterial` per
  canonical family+options signature; `apply_to()` installs it as a surface
  override (MeshInstance3D) or `material_override` (MultiMeshInstance3D). No
  per-surface instances.
* **Draw impact, measured**: a station of 8 meshes renders in **8 draw calls**
  with the language *and* in 8 draw calls with one plain `StandardMaterial3D`
  (the capture's control tile, same geometry, same lights). The material swap
  itself adds nothing; it changes shading, not batching.
* Total PNG payload of the whole language: **382,640 bytes** (374 KB) for 76
  unique planes; VRAM estimate **1,350,291 bytes** (1.29 MB) including mipmaps.
  Per family: 24.5 KB (`polar-ice`) to 63.7 KB (`oxidised-copper`).
* Cache cap 96 materials; overflow fails closed (returns `null`, counted in
  `cache_stats().rejected`) instead of allocating.
* Measured A/B on the 1280x800 family panels (every third pixel, out of 114,009
  samples): turning normals off changes 4.2–38.0% of pixels depending on the
  family; turning glow off changes 0.1% (regolith, by design) to 16.5%
  (brushed-alloy's cold sheen). The grazing-floor capture changes 17.9% with
  normals off and 2.0% with glow off.

## 9. Constraints and what still looks wrong

* **GL Compatibility**: no Decal, SSAO, SSR, transmission or volumetric work is
  used. Metallic reflects only what the environment gives it: these scenes have
  no reflection probe, so `metallic` above ~0.5 goes dark. `brushed-alloy` is
  therefore 0.45 metal, not 1.0 — a deliberate compromise that keeps the alloy
  readable without an IBL the renderer cannot provide.
* **The baked normals are shallow.** 13 of 13 are used, but several are >80% flat
  (hex_paneling, metal_grating, corrugated_metal, ice, diamond_plate), so the
  bump contribution on those families is a few sparse dents rather than a full
  relief. Depth beyond that is not available in the bake.
* **Derived AO is a heuristic.** It is a relative local-mean darker, not contact
  occlusion; it reads as dirt in creases, and it will darken genuine bright
  markings along their edges. The mask is bounded at 80/255 so it cannot go black.
* **`ice` is almost black** (mean luminance 18/255). Its variant relies on a 4.2×
  gain, which means its 8-bit banding is amplified too; the crackle atlas is the
  better default and is one.
* **`regolith`'s accent is intentionally invisible** at the shipped phase (0.5).
  If the owner wants the dust glint, a lane must drive `lut_phase` towards 0.97.
* **`industrial_mesh` and two effect sheets remain unused** by this lane
  (`effect-capture-ring`, `quantum-rift` belong to the VFX lane). Nothing here
  pretends those are covered.
* **Silhouette tiling** is inherent to a 64 px atlas: at 32 px/m (pearl ceramic) a
  2 m panel repeats visibly on a long wall. Variants and per-surface option
  choices are the mitigation; a second atlas is not available in the bake.
