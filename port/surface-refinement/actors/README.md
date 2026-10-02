# Operators and queued assets — bounded surface refinement

Source candidate based on `068e3ce2`. **Ready for parent integration and serial
native review; revised native acceptance is pending.** No Godot, Blender,
import/export, capture, encoding or nested agents were run in this lane.

## Native evidence and decision

Reviewed all nine existing 1600×1000 closeups in
`/home/mojo/.tmp-on-disk/cocs-finish-integration-evidence-20261002/operator-captures-refined/`.
The receipt identifies staged native FPS operator inspection, llvmpipe, production
multiplayer illumination (sun -44/-30, energy 1.25; ambient a0adb5, energy .68).
The receipt's command identifies `operator-capture.gd`; that fixture places gallery
rows 0–3 left-to-right. `godot/source_operators/moth_finish/gallery.gd` establishes
their ground truth: **original SVG red, original SVG blue, Moth red, Moth blue**.
They are not four finish revisions. These are existing FPS models, not new fighting
animation exports. Receipt FPS is capture cadence, not production GPU performance.

`native-reviewed-crops.png` is a labeled contact sheet of those existing pixels.
`pixel-audit.json` retains capture/fixture/image hashes and the complete capture
receipt. The originals are retained at their original paths and gallery URL:
<http://100.125.104.79:8796/native-moth-review/>.

| Operator | Observed native finding | Bounded decision |
| --- | --- | --- |
| ChatGPT | Teal chest and optics survive; purple antenna/arm accents occur in the original too. Moth shoulder detail remains subordinate. | Keep accents, overlays and response; remove shared shell bracket stamp. |
| Claude | Broad red/blue ceramic form is readable. The same shield/V seam bends over head and pelvis. | Quiet shared shell; preserve fitted shield shoulder panels. |
| Grok | Asymmetric antenna and cream wing forms lead. Dark equipment remains distinct. | Keep industrial identity and shoulder patch; remove repeated shell patch outlines. |
| Meta | Twin pods and heavy silhouette read well. Broad surfaces do not need extra riveted bays on every island. | Keep heavy roughness/metallic response and bolted fitted panel; quiet shell. |
| Gemini | Blue-purple secondary identity and cream wing structures remain distinct from teams. Petal seam repeats over unrelated shell parts. | Keep intended colors and fitted petal motif; quiet shared shell. |
| DeepSeek | Strongest pressure-collar repetition: circular pattern wraps head and repeats on pelvis/thigh regions. | Remove collar from shared shell maps, retain fitted shoulder pressure plate. |
| Mistral | Gold details and swept silhouette remain readable. Diagonal shell scratches do not follow every limb's construction. | Keep swept fitted overlays and lower roughness; quiet shared shell. |
| Kimi | Pink halo, magenta chest and purple details are intentional in the original. Concentric shell circles repeat over head/body. | Keep palette/halo and fitted orbital panel; remove cloned shell rings. |
| Qwen | Purple chest/arm details and lamellar shoulder geometry are intentional. Horizontal shell courses repeat on head/pelvis. | Keep purple and physical lamellae; remove shared shell courses. |

This is a repeated-layout correction, not a hue purge or blanket operator redesign.
The existing matte Moth response already improves team readability relative to the
very glossy originals. Metallic/roughness baselines and normal strengths are retained.

## Actual operator pixels and unchanged contracts

Inspected the actual raw Moth albedo/data sources, derived RGB albedos, scalar
roughness maps and tangent normals. Moth source images are 48/64-pixel baked images;
operator derivations are 256×256. **All operator albedo R/G/B values are equal**:
the multiplier cannot introduce lavender. Purple normal-map preview pixels are
linear tangent data, not evidence of color leakage. Normal bindings remain normal
bindings; no shader or binder was edited.

`shell-pixel-comparison.png` shows rejected versus candidate raw maps at the fixed
base revision. Only nine shell triplets (27 PNGs) change:

- Remove authored collar/panel/chip masks from shared shell UVs. Actual normalized
  source islands overlap among anatomical parts, so material-only layout cannot
  distinguish chest from head/limb. Sculpted geometry now owns these boundaries.
- Ceramic shells use neutral luminance from actual Moth `sand` micrograin instead
  of hex paneling. Industrial shells use actual `brushed_metal` instead of macro
  riveted plates. Existing Mistral directional mapping is retained.
- Old shell albedo ranges were approximately 222–252; new ceramic ranges are
  245–246 and industrial 244–247. Exact per-operator values and hashes are in the
  audit. This restores quiet paint without creating a new color palette.
- Shell roughness now varies by 2–4 byte values rather than macro seams. The
  validator allows this deliberate quiet-shell floor; other maps retain their
  existing ≥8-byte variation requirement. No artificial contrast was added just
  to satisfy a test.
- Fitted panel/board/vent layouts, trim, rubber and precision maps remain unchanged.
  Rubber still omits normals for its intentionally degenerate UV side triangles.

**Counts retained:** nine profiles, 63 finish records, 116 PNG paths, 538 bound and
476 preserved primitives. No material scope change, profile/binding change,
source GLB mutation, raw Moth mutation, rig/animation change or runtime change.
Generated PNG total: 1,022,276 bytes. Generator, raw-source, art-reference and pixel
hashes are regenerated in the existing manifest. No strict package count follow-up
is needed for this candidate.

## Entire queued helper audit

`tools/asset-production/moth_finish.py` retains the public
`finish_scene(root, unit, coordinate_scale=(1,1,1))` API and receipt schema version 1.
An additive `moth_finish_revision=2` distinguishes the changed recipe. Existing
version-1 finished materials require rebuilding from source, avoiding compounded
texture multiplication. The strict recipe fingerprint formula is unchanged, so
the helper edit correctly invalidates stale masters/receipts.

Every current queue palette is explicitly reviewed; unknown unit/material names
raise `Material review required` instead of falling back to metal. Only Blender's
numeric duplicate suffix is stripped. The complete mapping is machine-readable
in `pixel-audit.json` and tested against the actual builder/recipe palettes.

| Queue | Finish selection |
| --- | --- |
| Robots | `Switchyard_vertex_enamel`: coating grain; original linked COLOR_0 multiplied, no added normal. |
| Vehicles | armor/recess/team_accent/red: coating; edge: alloy; rubber: rubber; seat: fabric; lamp: preserved. |
| Scenery | bark: organic macrograin; moss: foliage grain; sandstone/silt/basalt: mineral; copper/iron: alloy; ceramic: coating. |
| Vesper | brick/plaster/slate/quay/cobbles/asphalt/sandstone: mineral grain, no invented masonry joints; iron: alloy. |
| Abyssal | navy/ivory pressure housings: coating, **not concrete/hex**; coral: fine porous grain; copper: alloy. |
| Stormglass | asphalt/concrete/salt/brick: mineral; teal painted housing: coating; steel: alloy. |
| External Parallax | Remains independently owned; no helper invocation or source changes in this lane. |

Glass/water/ocean/cyan/amber/letter keep their original special response. All warm,
cool, copper, coral, team and character palette factors remain authored. No new
grime is applied; neutral modulation is centered near unity. `queued-grain-pixels.png`
shows actual source pixels alongside derived neutral grain and explicitly labeled
normal data. This is a 2D source check, not queued-asset native acceptance.

The helper uses two aligned scales of the selected **real baked pixels** with
bounded, normalized contrast. Coating uses sand grain, not a hex-panel grid;
vegetation uses grass/macro-organic, not stucco. Manufactured brushing is neither
rotated nor shuffled. Per-component phase hashes include actual local geometry,
unit, attachment/object identity and parent bone. UVs are authored once with the
existing object scale and coordinate-scale transform; no runtime world position
or animation pose enters them. Connected parts within joined rigid meshes get
distinct stable phases. Existing `MothLocal` layers survive later material joins
(important for Vesper's second helper call). Shared mesh data is copied before UV
authoring, preserving material-instance/attachment isolation.

Coating, rubber, fabric, foliage and coral receive **no added normal map**. Alloy,
mineral and bark use weak normals derived from the exact same multiscale grain,
same UV layer and phase as albedo. Existing authored normal links win. Original
roughness/metallic values are retained. Each sampled PNG is checked against the
immutable Moth registry; the baked master fingerprint is verified and retained on
materials alongside source hashes. Builder recipe/master source fingerprints stay
compatible with `reopen.py` and `receipt.mjs`.

## Verification and parent handoff

Source checks passed:

```sh
python3 -m unittest discover -s tools/asset-production -p 'test_moth_finish.py' -v
node --test --test-name-pattern='all queued|complete bounded' tools/asset-production/consolidation.test.mjs
uv run --with pillow==12.3.0 --with numpy==2.5.3 python tools/operator-finish/content/validate.py
uv run --with pillow==12.3.0 --with numpy==2.5.3 python tools/operator-finish/content/build.py --check
uv run --with pillow==12.3.0 --with numpy==2.5.3 python port/surface-refinement/actors/audit.py
```

The helper tests cover live palette completeness, semantic traps (navy, rubber,
seat, lamp), unknown refusal, actual registry hashes and tamper refusal, bounded
neutral source-dependent pixels, normalized normals, different attachment phases,
fixed manufactured direction and UV preservation across pose/join changes.
The two applicable queue consolidation checks also pass; the historical frozen
branch comparison is not a refinement acceptance test and was not selected.

Parent native follow-up under its serial grant: identical original/rejected/refined
camera/light views for all nine operators, close and gameplay distance, grazing
light, moving-camera shimmer and team/motion/LOD checks. Queued builds must undergo
their existing strict master/GLB reopen and production-context gates, with special
attention to robot COLOR_0, tire/seat material identity, bone-part normal UVs,
Vesper post-join UV preservation and bark/foliage scale. No new queued master was
built or accepted here. Operator draw/sample count is unchanged; the queued helper
uses one albedo sample plus an optional normal sample per material, with variation
baked source-side rather than new runtime shader sampling.
