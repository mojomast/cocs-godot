# Abyssal V — qualified staged artifact approval

Independent Astra `ses_efd0e4deaffeke8j2rdXdxtbbn` approved worker `03b3db50`,
integrated as **`873ad2ac`**, for candidate `revision2-corrective-v`:
`b010a0764e3754b9d1e6ff3839e7c319d871336cf5b242a36cd512dd9ee3aa86`.
This closes the demonstrated T **interior terrace-contact P1** for this successor,
not the original `ee979520…` attempts. Public promotion remains pending.

## Independent artifact and source evidence

- Strict scene/accessor-backed export: **229,620 triangles / 47 primitives**.
- Fresh reopened-master export is byte-identical to the actual GLB.
- All three old P1 spans now agree at clear / floor Y6 / floor Y0.
- Actual contacts for all fourteen cave solids; outward contact-face normal dot
  products have minimum 1.0. Eleven mapped materials' color/normal/roughness
  pixel checks reproduce.
- Oriented world-triangle comparison shows only the two cave batches and two
  extended retaining-wall triangles changed from T. All other batches, including
  **24,152 reef triangles**, retain geometry despite reordered raw streams.
- The SW route goal moves from `(-76,-96)` to `(-77.5,-96)`, resampling six nav
  entries. Terrain/walls/blocks/spawns/objectives are unchanged. The old goal is
  inside a wall; the new goal is clear. **222 static samples at ≤0.25 m spacing**
  verify the changed route with radius 0.52 m. All 973 graph nodes connect.
- Generated candidate/arena/probes match committed bytes. The serialized nav
  list has 501 points; that is distinct from the constructed graph's 973 nodes.
- Final seven native stages exit successfully. The capture log retains an ALSA
  device initialization error; audio acceptance was not part of this result.

Master: `16e244942c84c810802fa56ec37efca5b39b95f2872d373175d68cc94e48d93f`.
GLB: `770c8622f6e9dc401fb6dc5cce4225efc5b930c1a88f29f9f0c324170db07f87`.
Frozen T GLB stays `925883eff465b7d470a36e215107420228ca8f537a08f2e3a7a879231668bfe7`.

## Native scope and qualifications

Native evidence contains 78 wall-band rays, four beyond-end clear rays and
**518 static capsule placements**, including nine ramp-only accommodations.
Only samples initially overlapping exclusively named ramp colliders get a retry;
all raised queries must be clear. Source slopes 0.625 and 2/3 require roughly
0.0432/0.0550 m extra lift above the initial 0.05 m bottom gap for radius 0.52 m.
The successful 0.15 m lift is plausible and conservative. This is clearance
evidence, not exact grounded-controller poses or continuous traversal.

The finite walls block demonstrated interior approaches. Sampled exterior
positions beyond their ends/beside the fins have no authority support; no ordinary
supported walking counterexample was found. Airborne approaches, falls, special
traversal and swept cameras remain pending.

All sixteen images were reviewed. Interior eyes are 2 m above valid support,
versus `MOVE.eyeStanding` 1.45 m: near-player architectural views, not exact
gameplay-eye proof. Exterior views are correctly disclosed unsupported inspections.
The baseline loads accepted WorldMap/art but its Binder reports `identity_mismatch`;
the candidate uses a copy-local preserve-PBR profile. Repetitive finishes and
readability still need manual visual acceptance.

## WeatherService correction and immutable evidence

**WeatherService exists in the parent but is excluded from this isolated stage.**
It exists in both `a8b3fe6b` and the delivery. The stage allowlist excludes
`godot/ambience/` and does not install production autoloads. The producer README
and original capture reports incorrectly attribute absence to the parent snapshot.

Original hash-pinned evidence, including that README, stays unchanged. An adjacent
`native-V-20261003/abyssal-pressureworks/REVIEW_SCOPE_CORRECTION.md` annotates it.
Both capture-source `finishScope` strings and the integration handoff now state
the correct scope; that text-only correction is not a new native run or receipt.

## Parent integration checks

On the merged parent: **19 successor Python + nine source Node + one strict
committed-Git shipping test pass (29 total)**. Generator `--check` matches the
successor hash. All **110 original evidence files** retain their hash/size,
including after adding the separate scope annotation. No engine rerun occurred.

Remaining acceptance: hosted modes, controller journeys, swept cameras, exterior/
special traversal, production-weather finish, gameplay performance and manual
visual approval. W retains the sole heavy slot for Foundry R6.

Gallery: <http://100.125.104.79:8796/abyssal-v/>.
