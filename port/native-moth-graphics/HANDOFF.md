# Moth graphics lane contract

Owned delivery: `tools/godot-moth/`, `godot/moth/`, `godot/tests/moth/`, and this directory.

## Integration contract (hooks unapplied)

* `const Moth = preload("res://moth/library.gd")`: static `texture(name)`, `normal(name)`, `sky(name)` return shared `Texture2D` or null. `effect(name)` returns `{frames: Array[Texture2D], fps: float}` or `{}`. `material_lut(name)` returns `{r: Texture2D, t: Texture2D, width, height}` or `{}`. Treat shared textures as immutable.
* `const Surfaces = preload("res://moth/surfaces.gd")`: static `create_surface(key, color, vertex_tint=false)` returns a caller-owned `ShaderMaterial`. Key is the original baked texture key. Unknown keys produce a plain tinted surface. Mapping semantic kinds and grouping terrain by texture are the lead lane's responsibility.
* Generated paths: `res://moth/generated/{textures,normals,sky}/<original-key>.png`, `materials/<key>-{r,t}.png`, `effects/<key>-<zero-based-index>.png`. Manifest at `res://moth/generated/manifest.json` has top-level buckets `textures`, `normals`, `sky`, `materials`, `effects`.
* Offline generation from repository root: `node tools/godot-moth/export.mjs`. Generated PNGs and manifest are committed. No Moth API invocation or key required.
* Add `moth/generated/*.json` to **each** native/web export preset's `include_filter`; preserve existing entries. PNGs are loaded via ResourceLoader and must pass the normal Godot import step before export. For custom package allowlists include `godot/moth/**` and the JSON explicitly. Do not bundle `tools/godot-moth` or tests as runtime dependencies.

## Exact lead-side hooks

1. Cherry-pick this lane's delivery, then run the offline exporter before the normal Godot import/build. No `node_modules` is needed for this lane.
2. In `godot/world/environment_style.gd`, preload `res://moth/surfaces.gd`. Wherever the lead chooses a concrete Moth key, create/cache a material with `MothSurfaces.create_surface(texture_key, color, semantic_vertex_tint)`. Keep the lead's material cache keyed by **texture + color + vertex-tint mode**, not solely texture. Returned materials are caller-owned and may be tuned independently; textures and shader are shared. Keep separate emission/transparent/visibility-specific materials on their existing paths.
3. Terrain grouping: partition existing semantic triangles by chosen texture key and retain their original vertex `COLOR`, `UV.x` depth priority, coordinates, normals, indices and visibility rules. Pass `true` for `vertex_tint` on those materials. Texture coordinates come from world position, so do not replace the semantic UVs with texture UVs. Geometry/collision/support transforms remain the lead's existing contract.
4. `godot/export_presets.cfg` baseline `include_filter` becomes `content/generated/*.json,content/generated/maps/*/*.json,moth/generated/*.json` (also preserve any concurrent lane additions). **Also update** the generated preset string in `tools/godot-package/build.py` near its `include_filter` assignment; editing only the checked-in preset does not fix package builds. Its tracked `native_files` collection already includes `godot/moth/**` once committed. Retain `export_filter="all_resources"` for dynamic PNG lookups, or explicitly add all 101 PNG resources if switching to selected-resource exports.
5. Verify `res://moth/generated/manifest.json` exists in the resulting PCK; run registry lookups from the packaged app. This lane verified editor/native imports and rendering, not the lead's full world/package integration.

Suggested initial families (lead controls final mapping): concrete → `weathered_concrete` / `weathered_concrete-worn`; industrial → `metal` / `corrugated_metal` / `riveted_armor-scorched`; rock → `rock-moss`; snow/ice → `ice-cracked`; grass → `grass`; sand → `sand`. Original `rock` and `ice` are unusually dark, while `diamond_plate`, `metal_grating`, and `industrial_mesh` contain bright colored patterns in the source. The contact sheet makes these choices explicit.

```gdscript
const Moth = preload("res://moth/library.gd")
const MothSurfaces = preload("res://moth/surfaces.gd")

var material := MothSurfaces.create_surface("weathered_concrete-worn", wall_color, true)
material.set_shader_parameter("repeat_scale", 0.5) # repeats per world unit; a 2-unit tile
material.set_shader_parameter("texture_strength", 0.68)
material.set_shader_parameter("normal_strength", 0.24)
# Optional accent, no implicit TIME animation:
MothSurfaces.apply_lut(material, "entanglement-arcane", 0.24, 0.8)
# For replayable motion, the caller can advance lut_phase from absolute seconds * 0.05.

var effect := Moth.effect("quantum-rift")
var frame: Texture2D = effect.frames[int(floor(seconds * effect.fps)) % effect.frames.size()]
```

## Resource and sampling details

* **101 PNGs:** 31 RGBA textures, 13 RGBA normals, 5 RGBA equirectangular skies, 10 RGB planes for 5 LUT pairs, and **42 RGBA effect frames / 10 sequences**. Original key spelling, dimensions, channel bytes, scanline order, frame order and fps are retained. LUTs are RGB, not mislabeled RGBA. Manifest plane records carry `path`, `width`, `height`, `channels`, `color_space`, `alpha`, `pixel_sha256`, `png_sha256`; effects have `frames` plane records plus sequence `width`, `height`, `fps`; materials have `r` and `t` plane records plus pair dimensions.
* Source SHA-256: `80dc8c0eb1ea8d78ce91b5775a0cb2cf71f549b4b63384a11290f389d20f3eb6` (`game/moth-baked.mjs`). The manifest contains the same provenance hash. The exporter uses Node builtins only, sorted keys, fixed lossless zlib encoding, no timestamps or network. All planes validate before any writes. Existing Godot `.import` UIDs are retained; Godot augments deterministic initial import-policy stubs with UIDs/defaults. PNGs and manifest, not editor-generated UIDs, are byte-deterministic across fresh exports.
* Albedo/sky/effects use sRGB meaning. Normals, RGB LUTs, `macro-organic`, `dust-field`, `flow-field` are linear data. Macro/field classification follows `game/textures.mjs` and `game/graphics-lab-pass.mjs`. Color-space conversion is a sampler responsibility: albedo has `source_color`; normal/LUT/data samplers do not. PNGs for linear data are deliberately **untagged**: `gAMA=1.0` makes Godot's decoder change bytes.
* Committed `.png.import` files enforce lossless compression, mipmaps, no normal-map channel packing, no alpha-border fixing, no premultiplication, and no normal Y inversion. Native tests compare every imported base image's decoded channels to source hashes. Mips are runtime sampling derivatives, not part of source byte hashes.
* Registry holds at most 128 texture references (101 unique shipped planes), LRU-evicts, and does not negative-cache arbitrary missing names. Caller-owned effect arrays/dictionaries and manifest copies cannot mutate registry structure. `cache_stats()` and `clear_cache()` support diagnostics. Live caller materials retain their resource references across cache clears. Call registry functions on the main thread.
* The surface shader is opaque/double-sided, preserves vertex-color modulation and the existing `FRAGCOORD.z - UV.x * 0.000001` semantic depth priority, and does not displace vertices. Smooth world-space triplanar weights work without mesh UV/tangents; all three normal axes are mapped to world-space tangent perturbations and then view space. Repeat scale defaults to 0.5, normal strength to 0.24, texture strength to 0.68, texture saturation to 0.55; finite per-family gain keeps source dark tiles usable. Caller uniforms should be finite. Missing key is plain tint; missing normal stays geometric normal. `apply_lut` bounds nonfinite intensity/phase and returns to no-LUT behavior for missing keys.
* Source effect alpha is 255 throughout all 42 frames. The exporter does **not** invent a luminance-derived alpha mask or erase background pixels. Most FX are dark colored squares intended for an additive-style caller; frame timing, billboarding, additive/alpha choice, lifetime and budgets belong to the FX lane. Setting ordinary alpha blending alone will show the original dark square. This registry does not claim full FX behavior parity.
* The LUT shader reproduces the source cubic Fresnel coordinate and R/T half-phase blend as an additive emission term. Shipped LUTs are sparse grayscale masks, not colorful ramps; phase 0.35 can sample an all-black row. The gallery deliberately uses arcane phase 0.8 to measure an actual contribution. Lighting/tonemapping is Godot-native rather than exact Three.js outgoing-light parity.

## Verification

```sh
node tools/godot-moth/export.mjs
node --test tools/godot-moth/export.test.mjs
python3 tools/godot-moth/verify.py
```

`verify.py` uses the pinned Godot 4.5.2 binary, private XDG/HOME directories, `PORT=0`, software GL Compatibility and its own `Xvfb -nolisten tcp -nolisten unix`. It preserves every attempt under this directory's `evidence/run-*`; errors in Godot logs fail the run even if the engine exits zero. It touches no shared service. PNG dimensions are asserted, not inferred from a filename.

Tests cover independent PNG decoding against all source planes, source-pixel hashes, deterministic dual exports, committed-output freshness, malformed payload/dimension/timing rejection, native imported-pixel identity, resource sharing and cache bounds, caller mutation isolation, unknown-name fallback, finite helper defaults, material ownership, and rendered normal / vertex-tint / LUT A/B contributions on meshes with real UV/tangents deliberately removed. Full world-map selection, UV.x coplanar overlap on every map, hardware GPU/Forward+/web rendering, animation wiring, and packaged-app lookup remain integration checks.

## Source rights

Existing findings in `port/asset-audit/HANDOFF.md` remain open: Moth recipes/job metadata identify provenance, not input/output redistribution rights; missing repository redistribution grant is unresolved. This offline conversion establishes no new clearance. No external assets or paid services are used.
