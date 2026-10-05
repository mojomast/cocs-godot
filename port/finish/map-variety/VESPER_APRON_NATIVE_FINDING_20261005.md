# Vesper apron native finding (2026-10-05)

Attempt `vesper-binding-02` (fresh namespace, aproned accepted world, re-pinned
fixture). Setup, both import passes, import pinning and the binding preflight
all pass (`bindingReady` + `bothVariantsRuntimeVerified` true). The
calibration group `accepted-civic-r035` **fails 5/10**, the same count as the
pre-apron baseline, so the run stopped fail-closed and the remaining groups
were not started.

## What changed in-engine

The stalls are no longer on 51.3° tread edges. Every failed ascent now stops
against a **40.03° apron face** (`normal.y = 0.7657`, well inside the 46°
`floor_max_angle` guard):

- trials 1/3/5: frozen at the first ramp (`civic-stair-0-apron`), grounded on
  the flat ground, `velocity` zeroed on contact, position unchanged for 120
  frames;
- trial 7: climbs 14 steps, then freezes on `civic-stair-14-apron`;
- trial 9: climbs 3 steps, then freezes on `civic-stair-3-apron`;
- all five descents reach quickly (404 frames); the other five ascents reach in
  the same 404 frames, so the ramp *is* climbable — the failures are phase
  jams, not a hard block.

## Geometry verified clean

The apron is a clean ramp, not an overhang: `civic-stair-0-apron` spans
z 24.8214→25.0 rising y 12.0→12.15 and meets the authored tread edge
(`civic-stair-0`, z 25.0, y 12.15) exactly. There is no sheet above the ramp.

## Interpretation

Three geometry-only attempts have now been measured natively: the 90° authored
edge (51.3° contacts, 5/10), the 45° chamfer (45.76° contacts at the pinned
feet, 5/10, and invisible to the source support query), and this 40° apron
(support-visible, census-clean, yet the engine still jams 5/10). The source
mover/census battery does not model the jam: it reported 60/60 clean trials on
this exact world. The blocking mechanism is in the native movement response
(grounded-slope handling, `floor_stop_on_slope`/`floor_snap_length`, or a
capsule-edge phase catch), not in the contact normal.

## Known prior art

A guarded exploration step-up WIP already exists in the repo:
`436e4b43` ("Integrate guarded step-up WIP"), `e8f0a16b` (bounded
physics-swept step-up experiment proposal), `godot/tests/walker_step_up`, and
`tools/godot-multiplayer/new-maps/walker-step-up`. A movement-lane continuation
of that WIP is the natural next step; it touches `godot/exploration/walker.gd`
and therefore needs the movement contract's advance discipline.

## Status

The apron promotion stays in `feature/relay-campaign` with
`nativeChecks: pending`; no preview build may ship it until an ascent gate
passes. Attempt evidence: `godot/tests/new_maps/botanical_post_x/vesper-binding-02/`
(116 files: binding + journey receipt for the calibration group, 10 trial
parameter receipts, imported variant artifacts). No waiver of any kind.
