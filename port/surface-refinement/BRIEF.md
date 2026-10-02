# Astra surface refinement — owner visual feedback

The owner rejects the pale-purple cast and obvious repetition in the current
Moth improvement pass. Make surfaces more natural, less repetitive and appropriate
to their material/use. This is required visual correction before release.

## Actual reference evidence

Native comparison gallery: `http://100.125.104.79:8796/native-moth-review/`.
Original captures: `/home/mojo/.tmp-on-disk/cocs-finish-integration-evidence-20261002/`
under `moth-districts-final/` and `operator-captures-refined/`.
Foundry cooling Full clearly shows lavender patterned machine cladding, repeated
floor motifs and overly uniform surface treatment. Helix archive Full shows
regular large-area tiling. Review all captured districts, not only these examples.

Do not assume the cause is normal-map leakage: inspect actual albedo/normal/data
bindings, PNG color spaces, source pixels, shader math, default textures, tint and
lighting before diagnosing it. Native sign orientation is separately being fixed
by the integration owner; preserve that work.

## Three independent Astra owners

1. **Rendering and anti-repetition:** own dressing `surface.gd`, new private shader
   helpers, `profile.gd`, shared validator/tests and refinement rendering docs.
   Preserve common Moth library/families/shader for other consumers. Work from
   actual immutable baked pixels; private replacement shader/derived data is
   acceptable with explicit provenance. No map profile/generator edits.
2. **Map art direction:** own all three dressing profiles, their map-local authoring
   scripts and receipts, plus map-specific surface-reference documentation. Choose
   appropriate existing texture families, scale, saturation, strength, response,
   deposition and local wear. No shared runtime/shader edits.
3. **Operators and queued assets:** own operator finish pixel generator/profiles/
   derived assets/provenance and `tools/asset-production/moth_finish.py` plus
   associated source checks. Review native operator comparisons before changing
   good surfaces. No body/rig/animation/authority edits or map-profile edits.

## Common art requirements

- Stone, concrete, soil, plaster and plants should have restrained organic grain
  and spatial variation, not repeated armor/hex/checker patterns.
- Painted housings and enamel should read primarily as their authored finish,
  with subtle roughness/grain and localized wear. Plate/grating/rivets belong only
  where their physical construction makes sense, not every wall or pillar.
- Remove accidental violet/lavender cast from neutral construction materials.
  Retain intentional operator identity colors and justified small accent areas.
- Balance fine detail with broad quiet areas; no uniform grime filter, giant
  stretched tiles, random hue noise, blur-only fix or increased fog hiding repeats.
- Break organic repetition with stable multiscale variation and bounded sampling;
  never randomly rotate directional metal brushing, labels, masonry courses or
  manufactured panel boundaries. Normal/data sampling must follow albedo mapping.
- Preserve collision, architecture, team readability, glow exclusions, UV-stable
  animated surfaces, material-instance isolation and bounded cost.

## Additive shared surface options

Rendering owner implements and validates these optional material `options` fields:

- `variation_mode`: `none` (default), `organic`, or `manufactured`.
- `variation_strength`: finite 0..1; default 0.
- `variation_scale`: finite 0.01..1.0 per metre; default 0.08.
- `variation_seed`: integer 0..2147483647; default 0.

Use existing `texture_saturation`, `texture_strength`, `albedo_gain`, normal and
roughness fields for tonal correction. No new fields without a documented shared
contract. Organic variation may decorrelate samples; manufactured variation must
preserve directional/structural features. Keep inactive defaults compatible.
Map art owner authors the fields explicitly and updates generator/receipts
together. Source validators may initially report unsupported fields until the
rendering owner's dependency is integrated; do not mark that as native success.

## Acceptance and tools

Begin from current parent in separate worktrees, source-only. Current exclusive
heavy grant remains `FINISH-COMBINED-NATIVE-20261002-A` with integration Astra
`ses_f0294303bffed6Fb8UJLKe4ZDz`; no new Godot/Blender/import/render/export/audio
grant is implied. Lightweight pixel inspection/derivation and source checks are
allowed. No nested agents, active-worker polling or unrelated file changes.

After an explicit serial grant, compare original flat, rejected Moth and refined
Moth at identical production camera/light settings. Include close and gameplay
distance, grazing light, moving camera for shimmer, all distinct districts, and
operator team/motion views. Review actual images; passing coverage is insufficient.
Retain rejected images and do not overwrite the existing gallery. Report shader
sampling/draw costs honestly; native capture cadence is not production GPU FPS.
