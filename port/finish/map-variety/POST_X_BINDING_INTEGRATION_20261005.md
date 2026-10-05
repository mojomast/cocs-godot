# Post-X binding review — parent integration note (2026-10-05)

**Review:** `30dbdc0f` on `review/post-x-binding-20261005`
(worktree `/home/mojo/.tmp-on-disk/cocs-botanical-post-x-source`), reviewing the
Vesper native-binding correction `902c3bbb` + `525b9fbe`.
Verdict: **APPROVE for selective source integration; native journey readiness
withheld** with four pre-grant conditions recorded in the review doc.

## Parent integration check

- The reviewed content is **already present on `feature/relay-campaign`** as the
  equivalent commits `8b80875b` (source `902c3bbb`) and `33afe0ec` (source
  `525b9fbe`), integrated earlier through the X selective-artifact transaction.
  No cherry-pick and no `171ffddb` ancestry merge was performed; no artifact,
  capture or master was added by this step.
- HEAD additionally carries the independently reviewed Z instrumentation
  `f108afd4` / `bb9ececa`, strictly additive over the reviewed delivery:
  write-once trial/binding receipts, physics-clock fields, `time_scale` and
  `physics_ticks_per_second` assertions, collider capture, and the
  `vesper-Z-NN` attempt namespace in `prepare_native.py`.
  `controller_journey.gd` (+41/−6) and `prepare_native.py` (4 lines) are the
  only files that differ from the reviewed commits.
- Parent re-ran the portable suites **on HEAD**: 13/13 Python tests pass, and
  12/12 Node movement tests (`movement.test.mjs`, `game/arena-movement.test.mjs`)
  pass. The Godot binary prerequisite is satisfied:
  `4.5.2.stable.official.6ce3de25a` (asserts-enabled editor build).

## Pre-grant conditions (verbatim scope from the review)

1. The granted `$GODOT` must be an asserts-enabled 4.5.2 build, and the receipt
   must record that fact; otherwise the binding gate is decorative.
2. Treat the first group's outcome as a **binding-calibration** run (imported
   census 54804/11/11/11 and 64311/29/29/17, `material.resource_name`,
   `ARRAY_FLAG_COMPRESS_ATTRIBUTES`, retained UID); a failure there is a
   gate-calibration failure, not a movement result.
3. Keep the existing fail-closed discipline: a failed group stops the sequence,
   failed receipts are retained, retries need a fresh namespace, and the
   two-pass import/pin/reimport order is preserved.
4. Native success, even with all 60 walks, is a movement-API diagnostic only —
   not map acceptance, Binder/Weather lifecycle, or a waiver of the 184 static
   contacts.

## Efficiency note

`BLOCKERS_EFFICIENCY_20261005.md` proposes batch continue-and-triage for
diagnostics. Reconciled here: the **first** Vesper run stays fail-closed per
condition 3; a continue-and-triage wrapper is a later, separately reviewed
diagnostic tool to be introduced only after binding calibration has actually
been observed.

## Scope unchanged

184 static contacts remain failed and unwaived; the 60 native journeys, the
`.18` candidate, production accounting, the `.42` Walker positive (AM failed),
the Parallax three-corner repair and any `urban-v4` successor remain open. No
Vesper map acceptance and no promotion follows from this integration.
