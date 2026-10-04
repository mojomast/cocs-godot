# V3 overhang correction and controls/reference-only admission

Source-only follow-up to `e16a5e1a`. No engine parsing, staging, imports,
rendering, servers or native jobs were performed. Historical v1/v2 receipts,
provenance and acceptance-plan bytes remain unchanged. This document supersedes
v2's executable grant schema for the **current phase only**.

## Overhang fixture correction

Only `overhang-forward` geometry changes: box centre `(0,1.83,.54)`, size
`(4,.1,.92)`. Its finite bounds are X[-2,2], Y[1.78,1.88], Z[.08,1]. The back,
height and width stay fixed; the front moves from .12 to .08. The permitted
rejection remains **exactly `raised_path_blocked`**. No controller, motion guard,
other fixture, route or rejection-reason relaxation accompanies this correction.

`test_overhang_v3.py` extracts the actual box dimensions from the GDScript source.
It calculates the continuous minimum distance between the finite capsule axial
segment and finite AABB. Breakpoints partition squared distance into quadratics;
endpoints and stationary points give the minimum without time sampling. Total
capsule height1.8 includes hemispheres: with actual shape offset.9, the axial
segment is footY+[radius,1.8-radius]. The collision envelope is radius+.02;
the margin is not added twice to capsule height.

Nominal source geometry, with settled footY .0166673660278, raised footY .1701
and unchanged starting Z `-.32-(radius-.35)*.6`:

| Radius | Settled clearance | Minimum UP clearance | Minimum raised-FORWARD clearance |
|---|---:|---:|---:|
| .35 | +.138111542m | +.060776056m | **−.030047047m** |
| .42 | +.145070857m | +.058214823m | **−.027910192m** |

Negative clearance denotes intersection of the capsule-plus-margin envelope.
The old finite box is retained as a regression input: its forward clearances
are +.005723m and +.005845m, reproducing the review's false-control diagnosis.

### Continuous uncertainty certificate

The certificate explicitly covers this proposed source-admission envelope:

- Settled footY in [0,.0201]; |X|≤.0001; nominal startZ±.0001.
- Raised footY in [.1700,.1902]: requested top+.02+.0001, coordinate rounding
  ±.0001 and permitted upward recovery [0,.0201].
- Forward travel .1±.0001, same upright capsule and shape offset.

For the whole UP path, the closest possible upper axial endpoint occurs at
maximum raisedY and maximum startZ. Both gaps to the finite box's lower/front
edge remain positive. This yields clearance lower bounds **+.053631975m** (.35)
and **+.049174458m** (.42), also covering the settled position.

At the forward endpoint, the farthest possible axial endpoint occurs at minimum
raisedY and minimum endZ. X stays within the finite box. This yields clearance
upper bounds **−.029823516m** (.35) and **−.027688419m** (.42). Hence every pose in
the stated continuous uncertainty set intersects during forward travel, with
more than25mm envelope penetration—not a .0001m tangency. These are monotonic
interval bounds, supplemented by continuous-sweep tests at envelope extremes.

This certifies intended fixture geometry, **not** native pose statistics or
Godot solver output. A native pose outside the stated envelope requires review;
it does not justify changing the expected rejection or accepting a later fault.

## First future grant is controls/reference only

Both the Python supervisor and native driver now require:

- `phase: "controls-reference-only-v3"`;
- explicit nonempty, duplicate-free `allowedGroups`, a subset of
  `["controls", "reference-accepted-civic-r035"]`;
- selected group present in that subset;
- no ambiguous legacy `groups` field;
- no continuation flag and no `continueAfterKnownBaselineFailure:true`.

Existing grant identity, SHA256, expiry and runner binary-identity checks remain.
Each command runs one manually selected group. Reference requires a passing,
source/grant-bound controls receipt. Its expected five uphill failures and five
downhill passes remain a **failed reference archive**, never a passing group.
Unknown phases or a receipt containing any candidate group fail admission even
when the selected group is `controls`. No receipt/CLI combination currently
unlocks candidate execution. Existing candidate group source stays dormant.

Future command shapes (not executed; all identity values authorizer supplied):

```sh
python3 -B tools/godot-multiplayer/new-maps/walker-step-up/run_group_v2.py \
  --fixture FRESH_PREPARED_PATH --engine REVIEWED_BINARY \
  --grant-id AUTHORIZED_ID --grant-sha256 EXACT_RECEIPT_SHA --group controls

python3 -B tools/godot-multiplayer/new-maps/walker-step-up/run_group_v2.py \
  --fixture FRESH_PREPARED_PATH --engine REVIEWED_BINARY \
  --grant-id AUTHORIZED_ID --grant-sha256 EXACT_RECEIPT_SHA \
  --group reference-accepted-civic-r035
```

No grant has been created. Independent review remains required before native
authorization, preparation/import work or either command.

## Later candidate admission remains blocked

Physical inclined-landing rejection and rotated positive-step admission controls
are **not added in this focused correction**. They must be implemented and
source-reviewed, then run under separate authorization, before candidate walks.
They must form a separately versioned `admission-controls` phase; the historical
34 rejection controls must not be silently reclassified. CLI plus a receipt is
not sufficient to skip that missing positive evidence. Production movement and
whole-frame velocity-reporting blockers remain unchanged, as do184 static failures.

**32 source tests pass**: prior24, five finite-box/capsule regressions and three
phase-admission tests. No new GDScript has been parsed or executed.
