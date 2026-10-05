# Quiet Relay maps preview — 2026-10-05

A fresh matching Windows/Linux test preview of the map, dressing and traversal
work landed today. Non-final: this is an explicit test build, not release
acceptance.

## What changed

- **Foundry R7 art promoted** into the runtime (tangent-corrected materials and
  finishes; geometry hash unchanged).
- **Runtime Moth dressing, richer pass:** Vesper 130 placements, Abyssal 129,
  Stormglass 131; Foundry's new R7 materials fully covered (17/17, `ready`) and
  two inverted plate families fixed. All six maps report zero validation
  failures.
- **Vesper Viaduct stairs fixed and natively accepted:** the walkable stair
  apron plus the exploration-walker `floor_block_on_wall=false` change gives
  10/10 clean ascents at both capsule envelopes on the shipping map — the first
  natively clean stair traversal of the campaign.
- **Parallax saltstone face 11823** accepted with a recorded qualification
  (measured, bounded, below a third of a pixel from every committed camera).
- **Stormglass flat road** retained by decision with the reviewed grade plan on
  record.

## How to help

Play the maps (Vesper stairs especially), and report observations with the map,
mode and reproduction steps. Camera, dressing placement, stair traversal and any
launch issues are the most useful notes.

## Known limitations

- Non-final preview: campaign, audio, accessibility, GPU/performance and human
  acceptance are not implied.
- The frozen pre-apron candidate comparison archive still stalls at the .35
  envelope (the original 90° step failure mode); that archive is a control, not
  shipping art.
- Production motion accounting and the remaining map/manual checks are
  unchanged.
