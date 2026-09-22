# Results and limits

Implementation commit: `2b3d758` (`Add native authoritative KOTH and Domination zone slice`).

## Final owned graphical runs

Exactly two controlled attempts per mode were used. Every attempt used a private
Xvfb (`-nolisten tcp -nolisten unix`), an ephemeral loopback authority, normal
source timing, no seed selection, legal `botCount:0,timeLimit:60`, the pinned
Godot 4.5.2 binary, and native key/mouse events through the shipped zone scene.

| Final run | Meridian / Domination | Verdant / KOTH |
|---|---|---|
| Evidence suffix | `157af36f-e73c-464c-86c6-ce6986024b81` | `c94c5077-9375-4d09-b949-d0645f38aee4` |
| Image dimensions | 960×640 | 1280×800 |
| Whole harness wall time (includes route preparation) | 68.800s | 76.977s |
| Actual initial position x/y/z | `(-36,0,-6)` | `(-42,0,34)` |
| Source zone reached | Bravo `(-14,0,-19), r3.5` | Alpha `(8,0,-4), r4` |
| Gameplay capture position x/y/z | `(-14.010,0,-19.223)` | `(8.187,0,-4.015)` |
| Gameplay capture source time | 10.567s | 16.533s |
| Source capture transition and actor capture stat | yes | yes |
| Source held-score increase while inside | yes | yes |
| Natural final team score | 50.5333 : 0 | 14.5167 : 0 |
| Natural result source time | 60.0167s | 60.0167s |
| Top-level winner | team 0 | team 0 |
| Recipient/round/sequence correlated rendered snapshots | 1,802 | 1,801 |
| Queued input records | 1,541 | 1,642 |
| Source-received inputs | 1,540 | 1,641 |
| ACK high-water | 1,537 | 1,639 |
| Results / authoritative starts | 1 / 2 | 1 / 2 |

Counts deliberately differ: queue, receipt, and snapshot ACK are distinct
observations. Objective success comes from actual source zone/score/actor-stat
transitions, not those counters. The KOTH source snapshot moved the active
marker from Alpha `(8,0,-4)` to Bravo `(-28,0,10)` after source rotation; the old
marker was removed. Its unmodified public snapshot contains no rotation timer.
The driver stopped following its initial route once that geometry/identity
ceased to be active. It did not claim a second capture or locally advance a hill.

Both live runs checked initial held-key capture refusal, fresh click capture,
Escape release, results control ineligibility/pointer release, an authoritative
restart, no carried pointer capture, held-key refusal after restart, and a fresh
post-release click. The scene used the actual shared session implementation.

### Images actually opened and reviewed

- [Meridian gameplay](evidence/meridian-exchange-157af36f-e73c-464c-86c6-ce6986024b81/gameplay.png)
- [Meridian natural results](evidence/meridian-exchange-157af36f-e73c-464c-86c6-ce6986024b81/results.png)
- [Verdant gameplay](evidence/verdant-reliquary-c94c5077-9375-4d09-b949-d0645f38aee4/gameplay.png)
- [Verdant natural results](evidence/verdant-reliquary-c94c5077-9375-4d09-b949-d0645f38aee4/results.png)

The zone panel, health/armor, weapon/ammo, controls, and world ring are visible
and fit at their actual capture resolutions. Results collapse the zone panel
to a compact winner/score header so it does not overlap the inherited scoreboard.
The inherited close-range pickup label can become very large behind the results
overlays at these capture positions; the overlays remain readable. This is
visible in the retained images, not a new zone-state rendering claim.

## Retained earlier attempts

- Meridian `139869cb-44c0-4b5d-97a9-36922b4a9711`: pass, 68.934s wall,
  start `(-44,0,-34)`, Bravo capture, final source score 49.7833 : 0. Reviewed
  960×640 images exposed a small results-panel/scoreboard overlap. The owned HUD
  now collapses to the results header; the second attempt above verified it.
- Verdant `94023a32-071f-4f51-afd1-3c150a586aba`: **failed acceptance**, 78.696s
  wall. At source time 24.067 actor remained exactly `(-28,0,30)`, waypoint 0.
  Route was `[(-14,19),(-14,-2),(8,-4)]`; template zone ID was `hill`, live
  source ID was `alpha` at the same coordinates/radius. Driver correctly refused
  to follow an identity-mismatched route, and validation rejected the absence of
  queued movement. Native scene rendering, source hill rotation, natural draw
  results and restart occurred, but this was **not capture evidence**. Raw logs,
  images, failure stack, code hashes, and exact coordinates are retained.
  The helper fix binds cached geometry only to an exact received source zone
  match (x/y/z/radius), using the received ID. Regression coverage rejects
  changed position, height, or radius. No source/native gameplay rule changed.

All four run summaries report native/display PIDs reaped and absent, authority
closed, zero sockets, and isolated runtime trees removed. No shared service was
used or stopped. The checked-out worktree and its local ignored imported assets
remain available for integration. Primary node_modules was used through a
read-only-in-practice symlink; no dependency install or modification occurred.

## Focused checks

Outputs retained in `evidence/safety/`; each was checked for exit status and
Godot errors/leak warnings:

- zone adapter/renderer/matrix: **42 checks**, integral JSON float team IDs,
  missing/null/type distinctions, stale-state clearing, identity validation,
  contested display, actual radius/height, source-ID rotation, timed winner,
  all-nine locked catalog and supported mode-map matrix.
- route tests: **3 passed**, both maps' ten authored spawns, source-supported
  edges and endpoints inside the true radius, plus KOTH ID-binding regression.
- original `control_safety.gd`: **2,497 checks**.
- original `stall_controls.gd`: **12 checks**.
- original `round_boundaries.gd`: **34 checks**.
- original `local_lifecycle.gd`: **15 checks**.
- source-lock verification executes before each graphical run; per-run summaries
  retain SHA-256 of source and native/helper runtime code.
- `evidence/safety/archive-audit.json` confirms all archived log checksums/byte
  counts and that both final run runtime hashes match the delivered files.
- proposed common-launcher/package table patch: `git apply --check` passed;
  **unapplied**. No package build or common verifier change in this branch.

## Bounded acceptance claims

Proven: playable native approach, capture, held score, source-following KOTH
rotation, natural timed results, restart capture safety, compact graphical HUD,
source geometry markers, and recipient-correlated state for the two runs above.

Not exercised live: enemy contest/neutralization/recapture, combat/death while
capturing, multi-human play, bot opposition, routes to the rotated hill, full
three-zone Domination control, the other legal map/mode pairs, or packaged launch.
Contested/ownership/missing-state presentation is covered by explicit synthetic
tests, not claimed as live contested play. The nine-map project scope is retained;
these focused runs are not all-nine gameplay or full recording acceptance.

No further attempts were made after the second per-mode runs. Common launcher
and package hooks are proposals for the integration owner in
`integration.UNAPPLIED.patch` and the README.
