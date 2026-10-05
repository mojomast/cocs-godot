# Blocker resolution and efficiency plan — 2026-10-05

Scope: the six-map population program's open blockers (Vesper stairs, Parallax
tangents, motion accounting) and the process that makes them expensive. This is
research/synthesis, not a native claim and not a replacement for any review.

## TL;DR

1. **Vesper is blocked by process, not by proved physics.** The prepared
   six-group × ten-walk native batch (60 `Walker.step` journeys) has never run;
   the 184 "contacts" are static finite-capsule placements, not movement
   results. Run the prepared batch once, unattended, with continue-and-triage
   instead of stop-on-first-failure. If real stalls appear, fix the authority
   collision with the industry-standard ramp/bevel, not by re-tuning guards.
   Retire the synthetic AA→AM admission campaigns as an acceptance path.
2. **Parallax's "4,729 nonorthogonal" figure is a raw UV-derivative census, not
   a glTF spec violation.** The spec-invalid subset was the 16 singular glyph
   records already closed by AC. Replace the orthogonality gate with a record
   classifier plus a bounded appearance-preservation contract; do not attempt a
   global W/green flip.
3. **Motion accounting:** define one canonical per-frame ledger (pre-lift,
   `move_and_slide`, snap, collision response, totals) emitted by every runner,
   and reconcile with tolerance. This ends the planner/parent disputes.
4. **Process:** acceptance should be unattended batches with automatic receipts
   and triage summaries — one grant per matrix, not one grant per micro-check.

## 1. Vesper stairs / step-up

### Root cause (proved)

- `godot/exploration/walker.gd`: capsule radius 0.35, `floor_max_angle = 46°`
  (`deg_to_rad(46.0)`), `floor_snap_length = 0.3`, `safe_margin = 0.02`, and
  **no step logic at all** — `step()` does `move_and_slide()` only.
- Godot 4's `CharacterBody3D` has no built-in step climbing; 90° step faces are
  walls, and capsule contact normals at a tread edge exceed 46°. This is why
  the guard's final-support test reports ~47.5–51.3°.
- The 184 failed records are **static finite-capsule placements** along the
  route (170 civic, 14 roof), reproduced analytically — they are not movement
  outcomes. The post-X source review already recommended running the prepared
  native movement journeys before changing geometry.
- The guard (`response_guard.gd`) requires final support normal within 46° and
  zero collider velocity; the calibrated synthetic campaign failed by 1.48° on
  a test fixture after an UP sweep (`invalid_final_support_normal_or_velocity`).

### Best practice (external)

- **Ramp collision over visual steps is the industry standard**: let the visual
  mesh keep detailed stairs and give physics a single angled collider; the
  step-climbing code becomes unnecessary (Bugnet, "Fix: CharacterBody3D getting
  stuck on stairs"; same guidance across commercial practice).
- **Bevel step edges** (~0.02 m) so a capsule slides up cleanly; keep step
  heights consistent.
- If code is needed: ray-cast or `ShapeCast3D` step-up before `move_and_slide`
  (Godot proposal #2751 tracks built-in support; not available in 4.5).
  Capsules handle steps better than boxes; smooth camera Y separately.
- Godot physics interpolation and fixed tick settings handle *visual* jitter;
  they do not grant step climbing.

### Recommended resolution (in order)

1. **Run the prepared batch first.** After the Vesper binding review lands
   (branch `astra/botanical-post-x-source` @ `525b9fbe`, focused re-review in
   flight), execute the six prepared groups once each:
   `accepted-civic-r035`, `accepted-civic-r042`, `candidate-civic-r035`,
   `candidate-civic-r042`, `candidate-roof-r035`, `candidate-roof-r042` via
   `controller_journey.gd` (commands in
   `tools/godot-multiplayer/new-maps/botanical-post-x/NATIVE_BINDING_FOLLOWUP.md`).
   Add a **continue-and-triage wrapper**: run every case, preserve every
   receipt, classify failures by predicate (grounding, stall, reset, endpoint,
   guard), and only then decide. A diagnostic batch is not an admission claim.
2. **If specific real stairs stall:** add reviewed **collision ramps or edge
   bevels** for those stair runs in the Vesper authority recipe, keeping the
   rendered geometry untouched. Re-run the static contact census
   (`botanical-post-x/contacts-evidence.json` tooling) and the native batch.
   Preserve authority support heights — the nav490 example shows a naive
   continuous civic ramp changes Y13.8 to Y13.7727; use thin bevels or
   height-matched ramps so route support is unchanged.
3. **Do not change the exploration controller profile (46°/0.3/0.02) for
   acceptance.** If a step-up routine is ever added, it is a separate reviewed
   movement change with its own tests and guard review.
4. **Retire the synthetic AA→AM campaigns as an acceptance path.** Keep the
   fixture harness for root-cause diagnostics. The synthetic fixture was never
   the production question; the real-map batch is.

### Why this is more efficient

- One supervised batch replaces a chain of ~30 sealed single-invocation
  campaigns that could not reach positive admission on a synthetic fixture.
- It tests the actual acceptance question (does the controller traverse
  Vesper's stairs) on the actual map with the actual art binding.
- The ramp/bevel fallback is a bounded, reviewable collision change rather than
  another engine-profile negotiation.

## 2. Parallax tangents (4,729 "nonorthogonal" records)

### Root cause (proved source-only)

- `parallax-tangent-provenance/README.md`: the near-global raw UV-derivative
  disagreement (452,050 stored W signs vs the exported-V basis) is **already in
  X** and mostly preserved by Godot; it follows from Blender's
  `v_glTF = 1 - v_Blender` plus bottom-up image addressing with the retained
  authored `bitangent_sign`. It does not prove wrong authored appearance.
- glTF 2.0 §3.7.2.1 requires only: `TANGENT` XYZ **normalized**, W a **sign
  value (±1)** indicating handedness. MikkTSpace is recommended for
  *generated* tangents; the spec does not state a per-record
  `dot(N,T) = 0` validity requirement, and mirroring legitimately produces
  opposite-handed bases.
- The actual native-invalid set was **16 singular records (N ∥ T)** on
  wayfinding glyphs, which AC repaired with a scoped fallback. The 4,729/4,745
  census records are a different, mostly cosmetic class.

### Best practice (external)

- Validate at spec level, glTF-Validator style: unit tangents, W ∈ {±1}, normal
  present, indices/accessors sound. Do not fail a pipeline for derivative-sign
  disagreement.
- Where appearance matters, compare **decoded sample perturbations** against
  the supplied basis and image addressing (the README's proposed appearance
  contract), optionally with one controlled render — not raw derivative signs.
- Repair only genuinely degenerate records; never apply a global flip
  (a uniform W flip cannot make a malformed field valid).

### Recommended resolution

1. Add a small **record classifier** over the existing census output:
   - spec-invalid: non-unit T, W ∉ {±1}, degenerate/parallel N·T, UV rank
     failure → must repair (AC already closed the 16);
   - spec-valid but derivative-disagreeing → appearance-contract scope only.
   Publish the two counts so the program stops treating 4,729 as a gate.
2. Implement the bounded **appearance-preservation contract** for the visible
   flagged records (including saltstone face 11823 and the five reversed-U
   corners) per the README's "preferred next scope"; one controlled render if
   practical.
3. Update the review qualifications accordingly ("N derivative-disagreements
   qualified by appearance contract; 0 spec-invalid remain") and move Parallax
   to promotion readiness.

### Why this is more efficient

- Converts an open-ended "fix 4,729 records" blocker into a bounded
  classification plus a small appearance fixture, and stops re-litigating
  conventions per grant.

## 3. Production motion accounting

### Root cause

- Whole-frame displacement versus `move_and_slide` position accounting diverge:
  a pre-lift can occur outside the parent's accounting, and planner/parent
  models of recovery restart differ (walker-step-up README; AM diagnosis).

### Fix

- One canonical ledger per frame, emitted by every runner:
  `{pose_before, pose_after, velocity, pre_lift_delta, slide_delta,
  snap_delta, collision_response_delta, total_delta, horizontal_budget,
  contacts[], guard_result}`.
- A single reconciler asserts `total_delta = slide + snap + response` within
  tolerance and labels pre-lift explicitly; guard checks read the same ledger.
- Document the semantics once (physics tick, fixed dt = 1/60, grounded rules);
  runners stop inventing local accounting.

## 4. Process efficiency (the actual root cause of slow progress)

- **Batch by matrix, not by micro-claim.** A grant should run an entire case
  matrix unattended: fixed order, per-case isolation, write-once receipts,
  automatic triage histogram, fail-and-continue for diagnostics,
  stop-on-first-failure only for admission runs.
- **Acceptance on the real map, with the production controller.** Synthetic
  fixtures are for root-cause diagnosis; do not gate a map on a synthetic
  capsule landing on a test tread.
- **One gate matrix per map** (static contacts, movement journeys, binding,
  materials, weather) with statuses recorded once — avoids re-deriving scope
  every campaign.
- **Precompute promotion transactions**: exact exclusion filters, accepted
  selection diff, and one promotion commit per map once gates pass.

## 5. Ordered next actions

1. **Vesper:** land the `525b9fbe` review, then one grant runs all six prepared
   journey groups with continue-and-triage; preserve every receipt.
2. **Vesper fallback (source-only, parallel):** prepare the ramp/bevel authority
   proposal for the failing stair runs (height-preserving), plus the static
   census re-run command.
3. **Parallax:** implement the classifier + appearance contract and update the
   qualification record.
4. **Shared:** add the motion ledger/reconciler to the walker harness.
5. **Promotion:** with 1–3 closed, run one promotion transaction per map using
   the precomputed exclusions; then the preview/CI batch.

## References

- Bugnet: <https://bugnet.io/blog/fix-godot-characterbody3d-stairs-climbing-stuck>
  (raycast/ShapeCast step-up; margin/snap/angle limits; ramp collider is the
  industry standard).
- Godot proposal #2751 (built-in stair step-up for CharacterBody3D):
  <https://github.com/godotengine/godot-proposals/issues/2751>
- MikkTSpace: <http://www.mikktspace.com/> (tangent space generation).
- glTF 2.0 spec §3.7.2.1 `TANGENT`: normalized XYZ, W = handedness sign.
- Khronos glTF-Validator: <https://github.com/KhronosGroup/glTF-Validator>
- Repo evidence: `port/finish/map-variety/POST_X_SOURCE_REVIEW.md`,
  `WALKER_AM_REVIEW.md`, `WALKER_SUPPORT_QUERY_DESIGN_REVIEW.md`,
  `parallax-tangent-provenance/README.md`, `PARALLAX_AC_REVIEW.md`,
  `tools/godot-multiplayer/new-maps/botanical-post-x/NATIVE_BINDING_FOLLOWUP.md`,
  `tools/godot-multiplayer/new-maps/walker-step-up/README.md`.
