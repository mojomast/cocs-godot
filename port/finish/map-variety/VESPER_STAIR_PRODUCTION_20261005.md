# Vesper stair traversal — production fix and native acceptance (2026-10-05)

**Status: production change accepted on the shipping map.** `game/*.mjs` is
untouched.

## The change

- `godot/exploration/walker.gd` sets `floor_block_on_wall = false` (with the
  rationale comment). Commit `778645bf`.
- No production receipt binds `godot/exploration/walker.gd`: checked all seven
  receipts (`packageInputs`, `sourceHashes`, `movementAdvance.changed`) and
  every `port/contracts/*.json` — none reference it, so **no advance layer was
  required**. The walker's fixture pins were updated instead:
  `prepare_native.py`, `source-provenance.json`,
  `binding-followup-provenance.json` (old `3015de90…` → new `99185806…`).
- Why: Godot's grounded wall-blocking path cancels forward motion on walkable
  apron contacts; disabling it removes the cancellation. See
  `VESPER_STAIR_TRAVERSAL_RESEARCH_20261005.md` (minimal repro + one-variable
  sweep) and `VESPER_STAIR_FIX_EXPERIMENT_20261005.md` (test-only run).

## Acceptance run `vesper-binding-04` (production pins, fresh attempt)

| case | reached | result |
|---|---|---|
| accepted-civic-r035 | **10/10** | clean (calibration gate passed) |
| accepted-civic-r042 | **10/10** | clean |
| candidate-civic-r042 | **10/10** | clean |
| candidate-roof-r042 | **10/10** | clean |
| candidate-civic-r035 | 5/10 | frozen pre-apron control: 47.4–50.9° `civic-stair-*` edges (original failure mode) |
| candidate-roof-r035 | 9/10 | frozen pre-apron control: one stall at 45.7° `roof-ramp-step-11` |

`bindingReady` and `bothVariantsRuntimeVerified` are true in all six group
receipts. The candidate pair is the frozen pre-apron control (external X art is
immutable, 90° steps) and is not shipping art; its r.35 residuals are recorded
unwaived, not papered over.

## Verification

- Package suite **315 pass / 0 fail** (canonical,
  `COCS_SOURCE_DERIVATIVE=port/contracts/racing-candidate-derivative.json`).
- Post-X Python suite **91 pass / 0 fail** (with
  `COCS_BOTANICAL_X_FIXTURE_ROOT`).
- `git diff` shows no `game/*.mjs` change.
- Draw-down note: `tools/godot-multiplayer/new-maps/walker-baseline-characterization-run`
  pins the pre-change walker (`review-pins.json`) and its `policy.py` requires
  `floorBlockOnWall is True`; its two source-manifest tests are red as the
  frozen pre-change baseline record. A lane rebase or re-characterization is a
  deliberate follow-up, not done here.

## Evidence

- Attempt: `godot/tests/new_maps/botanical_post_x/vesper-binding-04/` (116
  binding/journey/trial receipts plus imported variant artifacts).
- Experiment branch `spacebunny/vesper-floor-block-experiment-20261005`
  (test-only candidate and `vesper-binding-03`).
- Research raw evidence: `/tmp/opencode/stair-repro/` and
  `VESPER_STAIR_TRAVERSAL_RESEARCH_20261005.md`.

## State after this

Vesper's shipping stairs are natively clean at both envelopes with the
production walker. Preview builds and the remaining release work are unblocked
on the Vesper front; native acceptance of the preview packages themselves is
still a separate gate.
