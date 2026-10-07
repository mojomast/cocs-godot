# Godot 4.7.2 engine trial — aggregate report (2026-10-06/07)

**Verdict: do not adopt this 4.7.2 build.** The trial harness itself is sound and
the result is dominated by one engine-level defect, not by 282 independent
regressions.

## Candidate and engines

- Candidate: `audit/2026-10-06-engine-trial2`, based on merged `main`
  `02975878`; the only source change is the candidate-bound toolchain
  expectation (`be75e303`) that lets the aggregate run a non-lock engine.
- Shipped engine: Godot 4.5.2 (`5803746bbe055bee…`,
  `4.5.2.stable.official.6ce3de25a`).
- Trial engine: Godot 4.7.2 (`8d106cbe6144c2dc…`,
  `4.7.2.stable.official.ed1daf0bf`), official Linux binary.
- Both passes: full aggregate with `COCS_VERIFY_KEEP_GOING=1`, candidate-bound
  report fields, separate report and gate logs per engine.

## Results (all 386 registered gates executed in both passes)

| Engine | Executed | Passed | Failed | Regressions | Improvements |
|---|---|---|---|---|---|
| 4.5.2 baseline | 386 | 355 | 31 | — | — |
| 4.7.2 trial | 386 | 104 | 282 | **251** | 0 |

No gate appeared or disappeared; every registered gate ran in both passes.
4.7.2 failure reasons: `engine-error` 196, `nonzero-exit` 75, `timeout` 11.

## Root cause: engine-side accessibility type relocation

The dominant signature (690 occurrences across logs) is a parse-time type
mismatch inside the engine's own dependency chain:

```
Parse Error: Value of type "DisplayServer.AccessibilityLiveMode" cannot be
assigned to a variable of type "AccessibilityServer.AccessibilityLiveMode".
Parse Error: Cannot assign a value of type "DisplayServer.AccessibilityLiveMode"
as "AccessibilityServer.AccessibilityLiveMode".
```

Cascade: 233 `Failed to compile depended scripts`, 228 `Nonexistent function
'new' in base 'GDScript'`, and 231 gate logs containing the chain. The first
visible project casualty is `godot/ui/local_settings.gd`, which fails to load at
startup; because that panel is a dependency of most scenes and drivers, gates
that passed under 4.5.2 now fail before executing their own assertions.

A tree-wide search found **no project reference** to
`AccessibilityLiveMode`/`AccessibilityServer` in `godot/`, `game/`, `port/` or
`tools/` — the break originates in this 4.7.2 build, not in our sources, so
there is no project-side compat shim to apply.

## Scan-level vs assertion-level failures

Not every one of the 282 is an assertion failure. Example: `audio-feedback`
prints its full `PORT_AUDIO_FEEDBACK_OK checks=416` success marker and is still
recorded as failed because the log carries the engine parse errors (196 of the
failures are scan-level `engine-error`). The report does not claim a precise
assertion-level pass rate for that subset; it is characterised by the dominant
root cause above.

## Decision gate (from `ENGINE_TRIAL_PLAN.md`)

- No new deterministic failures: **no** — 251 regressed gates.
- Noise delta documented: yes (this report).
- No package/receipt changes: yes — none were needed.
- Owner visual/audio sign-off: not attempted (no visual or human claim).

**Decision: rejected for adoption.** Re-run the same two-pass harness against a
later 4.7.x build (or the engine revision that fixes the accessibility enum
relocation). The harness is committed here and the comparator is reusable.

## Evidence

`/tmp/opencode/engine-trial/runs/`: `aggregate-452b.log`,
`verification-452b.json`, `reports-452b.tgz`, `aggregate-472c.log`,
`verification-472c.json`, `reports-472c.tgz`, `run472.sh`, `compare.py`.

First-attempt evidence (`aggregate-452.log`, `verification-452.json`, …) is the
fail-fast run that surfaced the pre-trial verifier regressions now fixed on
`main` via #4.

## Not established

Visual rendering, audio quality, packaging behaviour under 4.7.2 beyond these
gates, and per-gate assertion-level status for the scan-failed subset. The 11
4.7.2 timeouts overlap the environment-sensitive journey family already
documented at baseline; they were not individually re-run.
