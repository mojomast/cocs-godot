# Natural map surfaces — rendering implementation and source diagnosis

Status: **source verified, native compilation and visual acceptance pending**.
Base `068e3ce2`; scope is dressing runtime/schema, private shader, shared source
checks, this study and a separate proof harness. No baked pixels were rewritten.

Map dependency `0d20d7d6` was cherry-picked as `bef7c193` for actual integration
checks. All three refined profiles now pass the real shared validator including
actual GLB selector coverage (Parallax uses the explicitly allowed read-only
asset root). Results/hashes are recorded in `rendering-source-validation.json`.
Map-owner source checks and package dressing-provenance tests also pass. Parent
already owns the map dependency; cherry-pick only this lane's rendering commit.

## Root cause established from files, pixels and shader algebra

Run `node port/surface-refinement/pixel-study.mjs`. It checks manifest PNG SHA-256
identities, decodes actual RGBA bytes, enumerates PNG chunks and reports albedo,
normal and packed-data means for ten representative materials. It also evaluates
the old Foundry soot albedo equation per pixel, including sRGB decode and tint.
The output is a reproducible source study, not a synthetic native screenshot.

The lavender **is not evidence of a normal sampler leaking into albedo**:

| Actual plane | Mean stored RGB, 0–255 | Contract |
|---|---|---|
| `generated/textures/diamond_plate.png` (48²) | 150.11, 111.12, 170.51 | sRGB albedo; first pixel 199,98,231 |
| `generated/normals/diamond_plate.png` (64²) | 127.67, 127.29, 239.02 | linear tangent normal; first pixel 125,125,255 |
| `derived/data/diamond_plate.png` | 229.37, 105.90, 127.99 | linear AO / roughness / detail |
| `generated/textures/weathered_concrete.png` | 96.27, 102.38, 112.05 | mildly cool, near-neutral sRGB mineral |
| `generated/textures/brushed_metal.png` | 61.11, 64.38, 68.68 | mildly cool, near-neutral sRGB metal |
| `generated/textures/hex_paneling.png` | 39.53, 139.99, 130.30 | strongly teal sRGB pattern |
| `generated/textures/rock-moss.png` | 79.60, 75.88, 63.92 | warm muted sRGB mineral |

Albedos have an sRGB PNG chunk; normals do not. Registry lookup is path-keyed:
`Moth.texture` reads the `textures` bucket, `Moth.normal` reads `normals`, and
`Language.material` binds those to separate shader parameters. The albedo sampler
has `source_color`; normal/data samplers do not. The diamond albedo `.import`
uses lossless `compress/mode=0`, identity channel remaps, `normal_map=0`, mipmaps
enabled. Normal pixels are decoded only in the normal branch; packed channels
affect scalar AO/roughness and scalar crease, never the albedo RGB chroma.
The private extension previously copied all sampler bindings after shader swap;
the new explicit shader retains that protection.

**Foundry:** `GM / soot` selects `brushed-alloy/plate` = the violet diamond albedo,
including on cooling housings, pillars and broad walls. Old options use texture
strength .72, gain 1.9, tint `879199`, inherited saturation .32. Before scalar AO,
crease and illumination, per-pixel evaluation averages linear RGB
**.16227/.16207/.23266**, or sRGB-of-mean **112.08/112.01/132.50**. At saturation
zero it becomes **106.80/114.91/121.40**, the remaining cool bias belonging to the
authored tint. Thus the source equation independently predicts violet without
any normal-map mixup. The cool proof ambient `a0adb5` can amplify coolness, but
does not explain why the diamond silhouettes repeat in lavender. Lighting's exact
contribution requires matched native controls and is not claimed from this math.
`GM / chalk` also uses teal hex albedo plus unrelated holographic-grid normals;
this produces a separate patterned teal finish, not neutral enamel.

**Helix:** archive/pavilion `ceramic` uses `pearl-ceramic/polished` = teal
`hex_paneling`, .6 tiles/m (1.67 m per whole source tile), inherited saturation
.40 and strength .55. Grid structure exists *inside* that small tile and repeats
many times across ceilings/floors. Archive brick/worn concrete and mossy stone
have other strong repeated/large grain. Baked normals can intentionally differ
from albedo (`enamel-glaze/default`, for example); that is a family recipe issue,
not a runtime semantic binding error. For naturally matching detail, existing
derived-normal variants such as `pearl-ceramic/worn` are preferable.

**Parallax:** the old profile already chooses near-neutral cast concrete/damp
concrete, with saturation .18, and modest metal strength. Its paving `rock` base
is nearly black (mean 4.73/4.28/3.67), so grain/normal response should be judged
separately from albedo gain. No Parallax image is in the 11-district evidence set;
this is source diagnosis only and needs its own native views.

## All eleven rejected Full captures reviewed

Actual originals, retained in place:
`/home/mojo/.tmp-on-disk/cocs-finish-integration-evidence-20261002/moth-districts-final/`.
Each row refers to its district folder and the map's `-2.png` Full capture.

| District | Observed issue / retained useful read |
|---|---|
| foundry-cooling | Clear lavender diamond housing, repeated pillars and floor; vent grating is a distinct legitimate construction feature. |
| foundry-assay | Same diamonds wrap large walls/ledge; pale patterned top competes with the sample sign. |
| foundry-crown | Diamond grid dominates long route and side rails; scale repeats toward vanishing point. |
| foundry-crusher | Broad highly patterned cladding and floor; low roughness highlights magnify the pattern. |
| foundry-transfer | Large signed housing repeats lavender diamonds uniformly; sign backing itself remains legible. |
| foundry-furnace | Mineral support and dark floor repeat coarse motifs; copper vessel retains useful distinct green patina. |
| helix-archive | Teal ceiling grid, repeated shelf grain, oversized contrasting stone grain at right; needs quiet mineral surfaces. |
| helix-botanical | Leaves/soil read more appropriately than industrial tiles; restrain grain while keeping leaf identity. |
| helix-irrigation | High-contrast repeated stone foreground and copper grain; keep copper/mineral differentiation. |
| helix-lightwell | Large mottling on pillar; retain warm vertical architecture and vegetation contrast. |
| helix-pavilion | Teal grid dominates broad floor/roof; quiet mineral finish required. |

Foundry cooling and Helix archive were additionally opened at full 1280×800.
Archive mirrored text is old evidence: integration's `f2c82794` font exclusion
must remain. That commit changes **binder.gd only**; `e95e379a` has no changes to
the three existing files owned by this rendering lane. Neither requires copying
dirty work or an owned-file cherry-pick. The private surface remains two-sided
for architectural meshes; production binder excludes one-sided baked font faces.

## Four additive controls and implementation

| Option | Accepted | Default |
|---|---|---|
| variation_mode | `none`, `organic`, `manufactured` | `none` |
| variation_strength | finite 0..1 | 0 |
| variation_scale | finite .01..1 per metre | .08 |
| variation_seed | integer 0..2147483647 | 0 |

`none` or zero strength retains the shared family shader unless old macro/wear
requires the private shader. Every family uniform retains its exact type/default,
sampler color-space hint and filter. `surface.gd` duplicates the cached material,
assigns the explicit shader, then copies every shared uniform. Only the four
implemented new controls and existing wear controls are forwarded privately.
Family saturation/gain/strength remain handled by the existing library bounds.

Organic: two affine micro samples per triplanar projection, original density and
.731 density with a deterministic seeded offset. A continuous world-space C1
value field sets the secondary weight to strength × (.35..65). The same weight,
coordinates and seed apply to albedo (including linear-base variants), packed
data, normals and accent masks. No rotation or reflection is introduced, so the
existing sign-aware projected normal axes remain correct. Normal RGB is blended
before existing slope reconstruction; these are authored detail normals, not a
claim of a physically derived displacement gradient. The texture coordinates
never jump at field-cell boundaries. Explicit secondary gradients use .731 times
the original UV derivatives, preserving mip choice across the blend.

Both active modes add at most ±8% neutral macro albedo and ±.025 roughness at full
strength. Manufactured reads the original micro coordinates only: no shifted
rivets, random brushing rotations, stretched panels or broken masonry courses.
It relies on map-authored quieter `texture_strength`/normal/roughness settings
and sensible density to make structural repeats unobtrusive. The organic mixture
reduces repetition, it cannot turn a strongly patterned plate into natural stone.

No time dependence, UV cell jitter, screen-space random values, hue noise, or new
texture resources. Existing mipmapped anisotropic filtering and distance normal/
crease fade remain. Existing local-height, baked packed-data macro/wear deposition,
LUT/pulse behavior, front/back normal handling and opaque rendering are preserved.
The stable world mapping is intended for these static map surfaces; this change
does not apply a new mapping to animated operator materials.

## Cost gate (source count, not performance measurement)

Typical nonemissive albedo + data + normal: **9 reads** in none/manufactured;
**18** in organic. Macro/wear adds **3** only when active. Accent mask adds 3/6,
flow adds 1, LUT R adds 1, optional LUT T adds 1. Fully enabled maximum is therefore
**18 none/manufactured / 30 organic** including wear, mask, flow and both LUTs.
Organic does not reduce texture count by calling a helper: it doubles each
active micro projection. Both active modes evaluate eight scalar spatial hashes
and interpolation per fragment; that ALU is additional too. Uniform branches
bound the work. Draw calls, passes, material-instance strategy, resource set and
geometry counts do not increase. Native GL 4.5 compilation, actual GPU cost and
camera-motion shimmer still require the serial grant and visual inspection.

## Required map-owner adjustments

- Foundry soot/housings: use existing `brushed-alloy/default` or a quiet cast/worn
  mineral for painted housings; avoid `plate` across all walls/pillars. Keep plates
  only on physically justified tread. Use near-zero saturation for neutral paint,
  lower strength/normal/roughness variation; `manufactured` for metal structure.
- Foundry chalk/enamel: replace teal hex/holographic default with an appropriate
  quiet existing variant, restrained saturation/strength and roughness. `organic`
  only where the chosen micrograin is genuinely unstructured.
- Helix ceramic: quiet cast/worn finish, suitable warm-neutral tint, low saturation
  and strength; avoid huge teal checker surfaces. Organic grain on stone, concrete,
  soil; manufactured on shelves/brushing and built structure. Preserve plants'
  authored greens and justified small copper/accent areas.
- Parallax: retain neutral cast mineral direction, add restrained organic mineral
  variation; keep brushing/mirrors manufactured with subtle strength. Validate its
  own close/far native views rather than inferring success from Helix/Foundry.

The map owner owns those choices and matching generator/profile/receipt updates.
Dependency `0d20d7d6` now supplies them: broad Foundry slate coating uses quiet
desaturated cast grain, Helix ceramic uses warm mineral grain, and Parallax
paving uses worn concrete rather than near-black rock. Their restrained active
strengths (.18–.32 organic, .10–.12 manufactured) keep macro response subtle;
the cost remains the full active-branch count even at these lower strengths.

## Verification and later native commands

Completed source-only:

```sh
node --test port/map-finish/shared/validate.test.mjs
node port/surface-refinement/pixel-study.mjs
/tmp/opencode/replay-gdtoolkit/bin/gdparse godot/multiplayer_worlds/dressing/surface.gd godot/multiplayer_worlds/dressing/profile.gd godot/tests/map_finish/refinement.gd
git diff --check
```

10 source tests passed: real resources/coverage, negative schema including all
variation boundaries/nonfinite/noninteger values, full shared-uniform signature
parity, implemented option presence, sampler-coordinate consistency, bounded
helper reads, and static balanced shader structure. `gdparse` is a source parser,
not Godot type checking. Static shader checks are **not compilation**.

Package provenance: the existing package builder hashes profiles dynamically.
Actual current committed Helix/Foundry hashes pass `verifyDressingProvenance`;
substituting the old `068e3ce2` hashes fails as required. Two package provenance
tests pass. Do not rewrite a previous release manifest to imply a rebuild: the
next granted integrated package build must record the new committed profile
hashes listed in the receipt. Parallax's production discovery/export is the
parent's integration responsibility; its profile itself has passed schema,
resources, source identity and accepted external GLB coverage here.

Prepared `godot/tests/map_finish/refinement.gd` accepts an external rejected
profile, loads flat/rejected/refined in one scene with identical camera, FOV,
lighting and frozen clock; uses production binder prepare/collect methods so the
integrated font fix remains. It records input profile hashes and camera/target/
light settings. It refuses to overwrite image names. No production file swap.
It supports bounded `--frames=... --motion=x,y,z` for matched camera translation
and `--sun=x,y,z` for a separately matched grazing-light set. Existing
`proof.gd` remains the detailed lifecycle/restoration acceptance harness.

**Only after the parent's explicit exclusive grant**, from the integrated tree:

```sh
git show 068e3ce2:godot/multiplayer_worlds/dressing/profiles/gravemill-foundry.json > /tmp/opencode/foundry-rejected-068e3ce2.json
godot --path godot --rendering-method gl_compatibility --resolution 1280x800 --script res://tests/map_finish/refinement.gd -- --map=gravemill-foundry --rejected-profile=/tmp/opencode/foundry-rejected-068e3ce2.json --proof-dir=/tmp/opencode/refinement-foundry-cooling-v1 --camera=-84,13.65,13.24 --target=-84,14.3,17.64 --clock=12
```

Use the native owner's actual Godot 4.5 binary/display wrapper. These light values
match the inherited proof rig; compare against the production multiplayer rig
before describing them as production-light proof. Repeat every district
camera/target from `maps/capture-plan.json` and `maps/CAPTURE.md`, add gameplay-distance
and grazing-light sets and matched camera-motion frames. Review originals at
the retained gallery alongside new comparisons; do not equate coverage, capture
cadence or source algebra with visual acceptance. Parent must integrate native
type fixes and font exclusion before running this harness. No Godot, Blender,
render, import, shader compile or audio process was launched in this lane.
