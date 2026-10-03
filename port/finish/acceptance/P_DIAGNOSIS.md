# P completed-failure diagnosis — isolated source branch

Frozen runtime remains `3e97453a`; diagnosis branch `finish/P-diagnosis` is a
sparse worktree at `/home/mojo/.tmp-on-disk/cocs-P-diagnosis-20261003`.
No native process, import, cache mutation or authority was launched here.
The canonical runner continues independently in the original worktree.

Read-only artifact: `/home/mojo/.tmp-on-disk/cocs-release-matrix-P-20261003/diagnosis/completed-11.json`.
It records the exact canonical input identity, immutable completed attempt paths,
evidence SHA256s and extracted witnesses for all 11 requested failures.
Reproduce using `python3 tools/godot-dev/p_failure_diagnosis.py REPORT OUTPUT`.
The analyzer refuses running/passed/unrun attempts and joins campaign application
by **round + epoch + sequence**, never sequence alone.

## Eight spectator failures: two boundaries, not eight distinct runtime bugs

Six runs (all wide plus sports/combined compact) successfully admitted the late
spectator and verified public state, then emitted exactly:
`SPECTATOR_JOURNEY_FAIL ordinary keyboard target cycle`.
Their last successful reports contain a ready spectator, target 0, and multiple
living targets. For sports-wide, all three targets have positive health
(100, 100, 110). This excludes an empty/one-target roster explanation.
No missing method, parse error or viewport assertion is recorded before failure.

The retained report precedes the key; the parent aborts immediately on the first
failure line. It does **not** record input-dispatch availability, focus, stale
state or the after-key target. Consequently the evidence does not distinguish
buffered dispatch from a lifecycle gate clearing the selection. Do not claim a
proven production cycling bug or a native repair from source inspection alone.
The isolated fixture patch flushes dispatched key events before its existing
assertions and records before-dispatch/after-dispatch/after-frame observations,
including available/blocked/stale/focus/role and public target list. It preserves
the exact cycle/reverse-cycle checks and does not call `model.cycle` directly.

Mode-compact and world-compact fail earlier at the parent wire assertion:
`ordinary native actor action reached wire`. They never launch a spectator.
Their player-input reports show pointer 0 (released), despite the command
reporting no fixture failure. The helper clicks logical `(0.5,0.65)`; O already
demonstrated ordinary readout ownership can consume central clicks. The patch
uses logical `(0.85,0.5)` with the existing scale-to-window transform, preserving
real GUI routing. This is an evidence-backed fixture correction, **not yet a
native pass** or proof that this alone closes both compact runs.

### Latent Home contract mismatch exposed by source inspection

The spectator supervisor still expected Settings Leave to exit and then launched
a new Home process. O's production button now defers an in-process Home transition.
The patch presses the real focused button, waits for actual Home in that process,
and keeps existing clean-state assertions. It removes the obsolete exit/relaunch
substitute. No production setting or package pin changes are needed.

## Seven operators: canonical failure is Gemini, not Mistral

`results.json` now retains all seven outcomes: **six passed; Gemini failed**.
Mistral passed on this candidate. The earlier Mistral failure belongs to the
preclosure receipt and must not be copied into canonical-02's diagnosis.

Gemini expected `move-start/reason=double-jump`. None was received. Source events
instead show `move-blocked/grounded` at 3.483 s and 4.250 s. Its two positive jump
edges (seq 10 and 14) are first acknowledged at 3.500 s and 4.267 s: **767 ms
apart**, versus the fixture's intended 280 ms. Intermediate release seq 12 is
acknowledged at 3.967 s. Poses rise only to 1.407; the second press arrived after
the first jump had landed. Early `move-blocked/firing` belongs to the capture
click before the power/input sequence, not a fabricated movement success.

This is a wall-time/input-delivery limitation in this rendered attempt. No
double-jump tolerance, source clock, contact window, actor state or expected
event was changed. A follow-up needs actual dispatch/frame timing around the
unchanged input schedule; arbitrary sleeps or relaxed checks would not repair it.

## Campaign: capture succeeds, then input epoch cancels movement

Before W: pointer 2, focused, eligible, alive, fresh, no GUI focus or overlay;
epoch 3, seq 13. Thus the O obstructed-click explanation does not fit this attempt.
W reaches `_input` with capture still held. Nonzero x/z seq 14 arrives at
16637.839519 ms, **805.846076 ms** after seq 13. No applied entry matches round 1,
epoch 3, seq 14. Seq 15 arrives as cancellation in epoch 4. Subsequent trace shows
pointer 0 and W blocked; final source position remains `(-152,18,-104)`.
The previous view-warmup fixture change has not made this rendered path reliable.
Preserve the actual failed movement gate; do not bypass epoch cancellation.

## Rendered Horde wide: valid loss with repeated stale-input boundaries

The completed wide attempt has no engine errors, but genuinely loses in wave 1
at 223.560053 wall seconds: no stations, no gate/stage arrivals, no upgrades.
Max input gap is **1499.906199 ms** and it records **419 reset receipts**.
Its 160 captured images span 58.803107 wall seconds (~2.70 capture intervals/s;
this is capture cadence, not an asserted renderer frame-rate measurement).

For comparison, the completed headless registered chain on the same candidate
passed all four stations and stages B/C in 517.978477 seconds, with a maximum
130.578892 ms input gap and eight rewards. That is chain evidence, not rendered
acceptance or final ten-wave victory. Wide was not killed as a hang. Compact and
the later registered boss stage remain owned by the existing supervisor; this
diagnosis does not poll or interfere with them.

## Verification and incident

- Seven existing spectator source/process/privacy tests pass (log in diagnosis
  evidence directory). They run synthetic subprocess cleanup checks, no engines.
- Three diagnosis tests pass: round/epoch sequence reuse is rejected, input gaps
  do not cross rounds, and active/nonfailed attempts cannot become failure proof.
- Native verification of the isolated patch is **unrun**, pending a safe stage
  boundary and fresh candidate identity. No failure is relabelled passed.
- Initial full worktree checkout hit ENOSPC and Git removed the incomplete tree.
  The sparse replacement avoids asset duplication. This short disk-pressure
  incident must be considered for contemporaneous active-attempt output failures;
  it does not explain these 11 already completed attempts. Frozen files/cache
  were not edited. No unrelated worktree/evidence was deleted.
