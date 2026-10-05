# Vesper stair fix experiment — `floor_block_on_wall=false` (2026-10-05)

**Status: test-only native experiment, successful on the shipping map.** Not a
production change; `game/*.mjs` untouched; the production exploration walker
remains `3015de90…`.

## What was tested

- Branch `spacebunny/vesper-floor-block-experiment-20261005` (pushed; worktree
  `cocs-vesper-fix-T-20261005`), one test-only change in
  `godot/exploration/walker.gd`: `floor_block_on_wall = false`, with a
  test-only walker pin `407be806…` in `prepare_native.py` (production pin
  `3015de90…` unchanged).
- Fresh attempt `vesper-binding-03` in that worktree on the aproned accepted
  world; setup, both import passes, import pinning and the binding preflight
  all pass (`bindingReady` + `bothVariantsRuntimeVerified` true).

## Results (six groups, ten walks each)

| case | reached | result |
|---|---|---|
| accepted-civic-r035 | **10/10** | clean — the calibration group that failed 5/10 in `vesper-binding-02` |
| accepted-civic-r042 | **10/10** | clean |
| candidate-civic-r042 | **10/10** | clean |
| candidate-roof-r042 | **10/10** | clean |
| candidate-civic-r035 | 5/10 | frozen pre-apron control: stalls on 47.4–50.9° `civic-stair-*` edges (the original 90° failure mode) |
| candidate-roof-r035 | 9/10 | frozen pre-apron control: one stall at 45.7° `roof-ramp-step-11` |

## Interpretation

- The accepted shipping world (apron + this setting) clears the ascent gate at
  both envelopes — the first fully clean native ascent result of the campaign.
- The candidate pair is the frozen pre-apron control (external X art is
  immutable and its stairs are 90° edges). Its r.35 residuals are the original
  failure mode, unchanged; the setting does not paper over true 90° steps, and
  the r.42 envelope clears. The candidate is a comparison archive, not shipping
  art.
- Root cause is confirmed against the Sol research:
  `VESPER_STAIR_TRAVERSAL_RESEARCH_20261005.md` — Godot's grounded
  wall-blocking path cancels forward motion on the apron contact; disabling
  `floor_block_on_wall` removes the cancellation (all five sampled approach
  phases climbed in the minimal repro, both capsules; `floor_stop_on_slope`
  and snap-length changes did not).

## Production path (not started; needs authorization)

1. Move the one-line setting into the explored walker via the movement lane's
   advance discipline (verifier + reversible layer chained above the apron
   lane), keeping `game/*.mjs` byte-identical.
2. Regression package before native: wall/corner sliding, ledges, descents,
   jumps, platforms, and the other maps' walk routes (the setting changes how
   grounded bodies behave when blocked by walls).
3. Native acceptance re-run on production pins (fresh attempt) with the
   accepted groups 10/10 at both envelopes as the gate; candidate controls
   documented, never waived.

## Evidence

- Experiment branch `spacebunny/vesper-floor-block-experiment-20261005`
  (commit with the test-only change, attempt, and `TEST_ONLY_VESPER_EXPERIMENT.md`).
- Attempt `godot/tests/new_maps/botanical_post_x/vesper-binding-03/` in this
  repo: binding + journey receipts for all six groups, 60 trial parameter
  receipts, imported variant artifacts.
- Research: `VESPER_STAIR_TRAVERSAL_RESEARCH_20261005.md` (minimal repro,
  permutations, raw logs under `/tmp/opencode/stair-repro/`).
