# Map surface refinement — source candidate, native review pending

Owner feedback: remove pale purple, repetition and inappropriate all-over plate.
Base: `068e3ce2`. This directory supersedes the old material-story tables in
`port/map-finish/*/` for this candidate. It is **not visual acceptance**.

**Follow-up after parent `bb02e34b`:** reviewed the actual eleven native B
comparisons; retain the improved palette. Foundry's authored light material is
now excluded from dressing to restore its original emission. See
[`EMISSION_FOLLOWUP.md`](EMISSION_FOLLOWUP.md) for root cause, exact source anatomy,
source checks and pending native commands. Earlier `verification.json` and
`source-evidence.json` retain the historical palette-pass snapshots; the current
Foundry generator receipt and `emission-verification.json` cover this correction.

## Reference inspection and diagnosis

Opened the actual native Off/Low/Full captures for all eleven districts, then
opened Foundry cooling Full and Helix archive Full at original resolution.
References are preserved under
`/home/mojo/.tmp-on-disk/cocs-finish-integration-evidence-20261002/moth-districts-final/`.
Published originals: <http://100.125.104.79:8796/native-moth-review/>.
Also inspected all eight accepted Parallax original views in
`/home/mojo/.tmp-on-disk/cocs-new-map-observatory-evidence-20261002/native-review/`.
There is no rejected Parallax Moth image in the eleven-district gallery.

| District | Actual rejected image observation | Authored correction |
|---|---|---|
| Foundry cooling | Purple/green diamonds on equipment, pillars and distant floor; streaked pale floor; patterned roof | Neutral fine matte coating on shared soot batch; quiet mineral floor; localized vent grating retained |
| Foundry crusher | Diamonds blanket house wall and drum body; bright patterned rails/roof ribs | Coated charcoal structure, quiet warm brass grain, oxide restrained to copper family |
| Foundry assay | Lavender lintel and repeated wall pattern; green checker equipment/large overlay | Neutral structure and warm mineral partitions; plain clean inset behind existing sign |
| Foundry furnace | Armor/rivet texture reads across massive kiln arch/pier; green uniform vessel texture | Warm rough refractory masonry, reduced vessel patina, feathered low-alpha soot |
| Foundry transfer | Huge uninterrupted diamond-covered cut wall | Broad quiet slate-grey paint with bounded organic grain |
| Foundry crown | Diamond floor wallpaper at grazing distance, turquoise cross strips | Quiet coating and warm chalk mineral accents; motion/shimmer check queued |
| Helix archive | Plaid storage face, noisy moss-like retaining wall, turquoise grid ceiling/inlays, rough floor | Subtle brass finish, limestone wall, warm honed mineral ceramic, muted soil grain |
| Helix irrigation | Strongly pitted foreground wall and vessel, shared uniformly green finish | Warm quiet masonry, restrained teal metal identity and localized waterlines |
| Helix pavilion | Cyan grid floor and repeated mineral blocks | Warm matte ceramic floor and quieter terracotta blocks |
| Helix botanical | Frond geometry legible; large plant colours should survive refinement | Preserve every frond, retain two leaf tones, very subtle actual grass grain |
| Helix lightwell | Root/piers and gold support surfaces heavily mottled | Low-contrast masonry and brass; leaf crown remains authored geometry |

### Actual immutable source pixels, not names

`source-evidence.json` records PNG SHA-256, pixel means, colour-space metadata,
actual GLB primitive/triangle coverage and preserved screenshot hashes.
All selected inputs are existing Moth resources. No source image is repainted.

- `diamond_plate` is **purple/green albedo** (mean RGB approximately
  150/111/170, 48×48, sRGB), not a normal accidentally used as colour. Removed
  from all broad map materials. The old shader's direct albedo saturation/gain
  path also matters; source colour alone is not a complete native diagnosis.
- `hex_paneling` is a turquoise square grid (39/140/130), not quiet porcelain.
  Removed from broad ceramic/chalk material and clean cabinet/lintel inserts.
- `rock` is almost black (5/4/4) with a visible grid; increasing gain is not a
  convincing stone treatment. Replaced by neutral concrete grain for broad
  mineral/paving uses. `rock-moss` survives only as low-alpha localized root wear.
- `weathered_concrete` is a continuous blue-grey mottle (96/102/112). Explicit
  zero texture saturation, warm tint, low strength and restrained response make
  it suitable as mineral grain or fine matte coating. Names of its family do
  not imply glazed ceramic everywhere.
- `weathered_concrete-damp` has pronounced vertical streaks. Removed from broad
  floors and small waterline films; damp character comes from palette/response
  and localized alpha, not a stretched streak bitmap.
- `brushed_metal` includes a fine cross-grid. Limited to actual metal batches at
  strength .12–.20, normal .035–.06; manufactured variation preserves its lines.
- `grass` is low-contrast botanical grain, unlike the plaid `macro-organic` tile.
  Leaf material stays `regolith/verdant`, with explicit restrained settings.
- `dust-field` has hard rectangular lobes. Existing wear placements now use
  continuous `weathered_concrete` as mask, .4 edge feather and low opacity.
  Scorched riveted armor is no longer used as soot paint on masonry.

The accepted GLBs have coarse material batches serving multiple physical uses.
Selectors cannot distinguish a floor from a machine when both are `GM / soot`.
No new architectural partition is assumed. GLB/batch/source geometry is unchanged.

## Complete material role decisions

All values are explicit in deterministic authors and generated profiles. All
LUT gains/pulses are zero. Grain remains nonzero. Normal, detail, AO and roughness
variation are deliberately restrained so geometry carries the form.

### Gravemill Foundry (7 dressed + 1 preserved / 8 material selectors)

| Source (`GM / …`) | Physical uses / chosen appearance | Family / variant | Tint | Texture strength / normal | Variation |
|---|---|---|---|---|---|
| soot | Floors, machinery housings, walls, pillars, roofs: warm slate matte coating | pearl-ceramic / cast | 777872 | .24 / .10 | organic .30 |
| mineral | Terrain/foundations, assay walls and gables: warm rough stone/concrete | pearl-ceramic / worn | b5ab97 | .35 / .10 | organic .30 |
| copper | Vessel/roof metal: quiet grey-green patinated copper, not green noise | oxidised-copper / default | 8b9682 | .22 / .10 | organic .30 |
| brass | Ribs, rods, hopper stock: subdued warm metal; no riveted grid | brushed-alloy / default | a78a58 | .18 / .06 | manufactured .12 |
| ore | Kiln masonry, arches, piers, strata and chutes: earthy refractory finish | pearl-ceramic / worn | a7856c | .32 / .10 | organic .30 |
| orange | Eight cooling roof lights, eight furnace sight glasses, six assay status lamps: original source emission and energy | preserved imported material | source | source | none |
| chalk | Mineral linework/trim: warm chalk, no cyan grid | pearl-ceramic / cast | c4bcaa | .22 / .10 | organic .30 |
| cooling-floor | Quiet grey mineral floor, no flowing ice-like streak texture | pearl-ceramic / cast | 93948b | .30 / .10 | organic .30 |

Density 1.15–1.5 tiles/m, gain 1.15–1.35, broad roughness .55–.91. Only copper
and brass have substantial metallic response (.38/.46). Existing actual vent
insets retain `metal_grating`; crusher service plates and narrow hazard bands
remain localized. Existing footprints, counts and mounts are preserved.

### Helix Conservatory (9 materials + preserved glass)

| Source | Physical uses / chosen appearance | Family / variant | Tint | Texture strength / normal | Variation |
|---|---|---|---|---|---|
| verdigris | Curved frames, aqueducts, vessels: restrained teal metal identity | oxidised-copper / default | 547f70 | .20 / .10 | organic .32 |
| soil | Terrace/bed earth: muted brown grain | regolith / default | 827054 | .30 / .10 | organic .32 |
| stone | Retaining walls, terrace edges, piers: warm limestone/concrete | pearl-ceramic / cast | a7a28f | .33 / .10 | organic .32 |
| ceramic | Vault, floors/inlays: honed warm mineral, no wallpaper grid | pearl-ceramic / cast | c2bda5 | .20 / .10 | organic .32 |
| brick | Retaining walls, alcoves and root structure: warm terracotta masonry | pearl-ceramic / worn | a27d5c | .30 / .10 | organic .32 |
| gold | Stack faces, collars and supports: subdued brass | brushed-alloy / default | b89a5c | .16 / .06 | manufactured .10 |
| solar | Authored solar roof panels: muted blue-grey cells, existing boundaries | brushed-alloy / circuit | 344650 | .22 / .06 | manufactured .10 |
| leaflight | Light leaf faces: subdued fresh green; intentional frond geometry | regolith / verdant | 82a454 | .16 / .045 | organic .18 |
| botanical | Dark leaf faces: deep foliage green; subtle botanical grain | regolith / verdant | 496c38 | .22 / .045 | organic .18 |
| glass | Clerestory/pane glazing | preserved source | source | source | none |

Density 1.1–1.5 tiles/m; gain 1.3; roughness .53–.94. Metal response only gold
(.42) and verdigris (.35). All 46 panels remain supported on their original faces;
waterline/root deposits are translucent and feathered. Pump access plates keep
their explicit `baked:metal` normal. No new panel covers glass.

### Parallax Observatory (6 materials + preserved sea)

| Source | Physical uses / chosen appearance | Family / variant | Tint | Texture strength / normal | Variation |
|---|---|---|---|---|---|
| saltstone | Walls, piers, institute mass: warm neutral coastal concrete | pearl-ceramic / cast | bcb29d | .32 / .10 | organic .32 |
| cistern | Lower tidal district floor: quiet grey mineral with cool undertone | pearl-ceramic / cast | 808b88 | .28 / .10 | organic .32 |
| metal | Roofs, trusses, instrument shells: subdued grey metal | brushed-alloy / default | 747873 | .20 / .06 | manufactured .10 |
| mirror | Accepted opaque optical alloy; no glass conversion | brushed-alloy / default | afb2a9 | .12 / .035 | manufactured .10 |
| paving | Cut-stone/inlay/coastal strata: grounded neutral mineral grain | pearl-ceramic / worn | 999787 | .36 / .12 | organic .32 |
| ochre | Survey ticks/diamonds, cabinets and ribs: warm ochre coating shared across uses | pearl-ceramic / cast | aa925f | .18 / .06 | organic .32 |
| sea | Distant below-void water scenery | preserved source | source | source | none |

Density 1.2–1.5 tiles/m; gain 1.2–1.35; roughness .40–.92. Optical/metal stock
retains metallic .55/.42; mixed-use ochre is .03. Actual source `mirror` alpha is
OPAQUE. Diagnostic panels/sensors retain their existing imagery; cabinet inserts
become plain mineral finish. Salt, frost and pump deposits now have alpha/feather
instead of opaque rectangular films. All 52 panel mounts remain unchanged.

## Reproduction and dependencies

```sh
python3 port/map-finish/gravemill-foundry/author.py
python3 port/map-finish/helix-conservatory/finish.py --write --self-test
python3 port/map-finish/helix-conservatory/finish.py
python3 port/map-finish/parallax-observatory/author.py --write
PARALLAX_ASSET_ROOT=/home/mojo/.tmp-on-disk/cocs-map-finish-parallax-20261002 \
  python3 port/map-finish/parallax-observatory/validate.py --write-report
git diff --check
```

Parallax assets are absent from tracked base `068e3ce2`. The explicit external
root is read-only and used solely for accepted geometry/master/authority proof;
all profile/texture/schema checks still use this checkout. Once those production
assets are integrated, omit the environment variable and run against the local
accepted assets. Binary/master identities are pinned in the validator.

Fresh map-local source receipts include profile hashes, PNG identities and face
backing checks. Local validators understand the agreed BRIEF variation contract.
The unmodified shared validator at base rejects **only** `variation_mode`,
`variation_strength`, `variation_scale`, `variation_seed` (36/32/24 errors for
Helix/Foundry/Parallax). This is a recorded blocking dependency, not a waived gate.
After the rendering-owner commit is integrated, rerun that actual validator on
all three final profiles, then native parsing/captures under the integration grant.

No new native work was run. Source coverage does not establish better appearance.
See `capture-plan.json` for inherited exact eleven-district cameras and preserved
image hashes; `CAPTURE.md` describes the three-state review and Parallax queue.
