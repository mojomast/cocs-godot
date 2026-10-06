# Godot 4.7.2 engine trial — scheduled phase plan (2026-10-06)

**Status:** scheduled as its own gated phase and PR. Not started in the audit
implementation pass. Prerequisites: the F08 promotion PR has merged and the
aggregate at that candidate is recorded (candidate-bound per F15).

## Scope (trial only — no in-place upgrade)

1. Pin the trial engine alongside the shipped `4.5.2` and keep the shipped pin
   for the main gate record until the trial is accepted.
2. Run the full 386-gate aggregate under the trial binary on an otherwise idle
   machine, with the candidate-bound report (`port_commit`, `port_tree`,
   `port_diff_sha256`, per-gate candidate headers).
3. Compare against the `4.5.2` record: aggregate failures, Godot deprecation and
   warning lines, package suite, dev-launcher journeys, and the presentation
   gates (`first_person/*`, `weapon_effects/*`, `player_fx/*` under xvfb).
4. Produce a delta report (`docs/audit-2026-10-06/ENGINE_TRIAL_REPORT.md`) with
   every status change and the trial binary hash.

## Decision gate

The upgrade PR may proceed only when: (a) no new deterministic failures beyond
the recorded pre-existing set, (b) the engine-noise delta is documented per
gate, (c) no package/receipt changes beyond the engine pin and the reviewed
trial evidence, and (d) visual/audio/human claims are owner-reviewed — never
claimed from headless runs.

## Explicitly out of scope

Rendering feature adoption, shader or material-role changes, and any source
extension. The F08 derivative chain and the receipt advance stay frozen at the
promotion candidate.
