# Foundry authored-light preservation after native B

Parent `bb02e34b` merged into `surface-refinement/maps-20261002` before this work.
Status: **source correction verified; new native appearance/lifecycle checks pending**.
Heavy grant C belongs to Parallax owner `ses_f055a6b41ffe42yCL8AxbOL676`.
No Godot/Blender/import/render/audio/encoding job was run for this follow-up.

## Actual defect and root cause

Reviewed actual flat/rejected/refined captures in
`/home/mojo/.tmp-on-disk/cocs-fighting-animation-evidence-20261002/surface-refinement-b/`.
Opened all eleven district triplets and the refined cooling/furnace/assay images
at original resolution. The three affected light types visibly become dull brown:
cooling ceiling inspection lamps, furnace molten sight-glass strips and the tiny
assay status indicators. The brass assay backing is not itself a light.

Accepted GLB SHA-256 remains
`46bf1648b32d23e337cd11b2c639a47f17d36c41361aab9434e1e621361e5935`.
It has eight coarse named material/node batches. The only emitting material is
**`GM / orange`**, on node **`Gravemill / orange`**, one primitive / 328 triangles:

| Actual decoded disconnected solids | Count | Source semantics |
|---|---:|---|
| Thin roof boxes, size .8 × .1 × 1.312 m in sheared GLB coordinates, Y 23.45–23.55 | 8 | `cooling-nave.roof-inspection-light-*` |
| Vertical narrow cylinders, bounds .25981 × 2 × .3 m | 8 | Two furnaces × four `sight-glass-*` strips |
| Small instrument boxes, .12 × .28 × .0368 m, Y 16.66–16.94 | 6 | Three assay stations × two `assay-status-lamp` faces |

The source author explicitly sets orange Principled emission colour and strength
2 (`checkpoint-blender.py:42–44`). Lamp roles are authored at lines 213–219 and
285–287; revision3 adds the six assay lamps at `revision3/author.py:68–74` and
skips the obsolete assay vault. Actual exported `emissiveFactor` is
`[1, 0.23749999348074208, 0.03125]`, with
`KHR_materials_emissive_strength.emissiveStrength = 1.600000023841858`.
The earlier description of this source as safety paint was wrong: decoded
components and source authoring agree that it contains exclusively these lights.

The dressing profile previously selected this material and replaced it with a
private matte `pearl-ceramic/cast` shader with LUT gain zero. `_collect()` in
`dressing/binder.gd` selected by material name, and its `_bindings.after` then
replaced the source StandardMaterial during Low/Full. `Surface.build()` works
from profile options rather than imported emission. Both rejected and refined
profiles therefore lost the authored light response; this was not a new palette
colour-space failure.

## Narrow correction

Move only `GM / orange` from the Foundry `materials` list into the existing
`preserve_materials` list. `_collect()` checks that list **before** creating a
binding. The native source material remains active in Off, Low and Full, with its
exact emission colour, energy multiplier, texture/operator and other imported
properties. No emission values are approximated or copied through another shader.

This is a source-material exclusion backed by actual luminaire-only anatomy,
not a rule that makes everything orange emit. Painted structure, brass housings,
hazard overlays and all seven remaining refined materials retain their current
finish—including the same variation seeds. Every panel/sign/pocket, geometry
identity, budget and mount is unchanged. Helix font-front correction is unchanged.
The existing binder already handles the exclusion and lifecycle, so no runtime,
global material-language, shader or catalog change is required.

Helix's accepted GLB has **zero** positive authored emissive materials. Its bright
teal areas in flat views are material/light response, not evidence of stripped
source emission. Glass exclusion and all Helix materials remain unchanged.
Parallax profile/recipe/mounts remain owned by its original author and untouched.

## Eleven-district B inspection notes

| Refined view | Local assessment / follow-up |
|---|---|
| Foundry cooling | Shared machine/wall/floor diamonds are gone; restrained grain and vent read appropriately. Roof lights clearly need source emission restoration. |
| Foundry furnace | Warm kiln arch and quieter vessel finish are coherent. Small molten strips have the same dimming defect. Existing low hazard plaque remains localized. |
| Foundry assay | Plain lintel and warm instrument backing replace purple/green repetition. Small status lamp is dim; keep the non-emissive backing distinct. |
| Foundry crusher | Structure and roof ribs now read as quiet coatings/metal, not diamond wallpaper. No additional emission defect demonstrated in this view. |
| Foundry crown | Long floor no longer shows lavender plate repetition. Preserve the accepted palette; moving/grazing review remains useful for subtle distant grain. |
| Foundry transfer | Broad cut wall is quiet and sign is legible; no new localized correction justified. |
| Helix archive | Wall/ceiling repetition is substantially subdued; forward-facing archive lettering retained. No source-emission loss is established. |
| Helix irrigation | Mineral wall and vessel are far less pitted; teal vessel identity remains. No emissive source exists to restore. |
| Helix pavilion | Cyan-grid floor replaced by quiet mineral finish; plinth treatment stays localized. |
| Helix botanical | Authored leaves retain clear silhouettes and two green tones, without rock-like grain. |
| Helix lightwell | Leaf crown remains distinct; support finish retains restrained texture. No proven additional defect warrants a palette rewrite. |

These are observations of the existing B images, **not post-fix native acceptance**.

## Checks and source contracts

- Foundry author regeneration passes all existing PNG/resource/face checks.
- New source assertion pins the sole emitting GLB selector, factor/strength,
  328 triangles and all 22 decoded components; broad/non-light geometry or
  rebinding the luminaire as paint fails the audit.
- Shared source suite: **11/11 pass**, including exact real-GLB emissive exclusion,
  coverage of the remaining painted structure, and rejection of duplicate
  dressed/preserved selectors. Rendering-owner variation fields now validate.
- Fresh generation is byte-identical for the profile and receipt. Comparison
  against `bb02e34b` proves all seven remaining finish entries/seeds and all
  placement/sign/pocket data are identical.
- `gdparse godot/tests/map_finish/proof.gd` passes grammar parsing only; this is
  not a Godot import/typecheck or native lifecycle run.
- The prepared native proof now snapshots actual imported emissive material,
  colour, energy, texture and operator. It asserts identity/values through three
  Off/Low/Full cycles, reapply, cleanup and reload, and requires exactly one
  emissive Foundry surface. Running it remains grant-gated.

Source-only commands:

```sh
python3 port/map-finish/gravemill-foundry/author.py
node --test port/map-finish/shared/validate.test.mjs
git diff --check
```

## Precise future native commands — not executed here

Run only when the integration owner supplies the next serial grant. `$PROJECT`
must be a prepared isolated Godot project containing this correction and the
unchanged accepted assets; `$GODOT_BIN` is the approved native executable.
Use a **new** `$OUT` directory. Preserve existing B images/gallery. Snapshot the
pre-fix refined profile from the parent for a direct emission comparison:

```sh
git show bb02e34b:godot/multiplayer_worlds/dressing/profiles/gravemill-foundry.json > "$OUT/gravemill-foundry-before-emission.json"

xvfb-run -a "$GODOT_BIN" --audio-driver Dummy --path "$PROJECT" --resolution 1280x800 --script res://tests/map_finish/refinement.gd -- --map=gravemill-foundry --rejected-profile="$OUT/gravemill-foundry-before-emission.json" --proof-dir="$OUT/cooling-lights" --camera=-84,13.65,13.24 --target=-84,14.3,17.64 --clock=12

xvfb-run -a "$GODOT_BIN" --audio-driver Dummy --path "$PROJECT" --resolution 1280x800 --script res://tests/map_finish/refinement.gd -- --map=gravemill-foundry --rejected-profile="$OUT/gravemill-foundry-before-emission.json" --proof-dir="$OUT/furnace-sight-glass" --camera=80,1.65,-18.8 --target=80,6,-10.3 --clock=12

xvfb-run -a "$GODOT_BIN" --audio-driver Dummy --path "$PROJECT" --resolution 1280x800 --script res://tests/map_finish/refinement.gd -- --map=gravemill-foundry --rejected-profile="$OUT/gravemill-foundry-before-emission.json" --proof-dir="$OUT/assay-status-lamp" --camera=66,13.65,45.24 --target=66,19,41.24 --clock=12

xvfb-run -a "$GODOT_BIN" --audio-driver Dummy --path "$PROJECT" --resolution 1280x800 --script res://tests/map_finish/proof.gd -- --map=gravemill-foundry --proof-dir="$OUT/foundry-emission-lifecycle" --camera=-84,13.65,13.24 --target=-84,14.3,17.64 --clock=12

xvfb-run -a "$GODOT_BIN" --audio-driver Dummy --path "$PROJECT" --resolution 1280x800 --script res://tests/map_finish/proof.gd -- --map=helix-conservatory --proof-dir="$OUT/helix-exclusion-font-regression" --camera=-46.671552,9.65,1.629806 --target=-50,11,-8 --clock=12
```

The refinement harness's `rejected` column in this queue is specifically the
**B pre-emission-fix refined profile**, not the older purple Moth version. Label
it accordingly. The old flat/rejected/refined B comparison remains intact.

Acceptance checks by name:
1. `cooling-lights`: roof lamps regain the flat-source yellow intensity/colour;
   housing, vent and nearby floors retain refined grain and remain non-emissive.
2. `furnace-sight-glass`: both near and distant molten strips regain source
   emission; copper vessel body and kiln masonry do not acquire glow.
3. `assay-status-lamp`: tiny indicator lights again; broad brass instrument
   backing and finish inset remain ordinary lit material.
4. `foundry-emission-lifecycle`: ready coverage is 7 dressed + `GM / orange`
   preserved; exact imported emissive reference/properties survive all detail
   transitions and cleanup/reload. No surface/cache mutation or node accumulation.
5. `helix-exclusion-font-regression`: glass exclusion and forward-facing archive
   text survive; no added emission treatment appears on frames/leaves/solar roof.

Use the existing B camera/light settings (FOV 75, sun -48/-30/0, energy 1,
ambient a0adb5/.68, clock 12). If a new motion check is granted, repeat cooling
with `--frames=12 --motion=0.7,0,0 --sun=-12,-65,0` in a separate output directory.
Report native failures and inspect actual new images before declaring the lights
fixed. Capture cadence remains distinct from GPU-performance proof.
