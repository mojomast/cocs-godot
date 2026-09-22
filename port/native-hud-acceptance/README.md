# Live compact-HUD health and pickup acceptance

**PASS:** the default GameHUD displays authoritative health/armor integers and
gauges, the existing combat overlay renders its hurt pulse, and the native guest
collects the authored health pickup and observes its normal 12-second return.
The successful run took **22.226 seconds** of gameplay wall time. **20 focused
Node tests pass.**

Runtime baseline: `fe29ac3a1a5d64c9d622286bf379fae7f3d6a32f`, pinned Godot
`4.5.2.stable.official.6ce3de25a`. Worktree:
`/tmp/opencode/live-hud-acceptance`, branch `feat/live-hud-acceptance`.

## Acceptance integration

`port/tools/native_health_damage/observe.gd` keeps `HEALTH_CORRELATE` immediately
adjacent to the synchronous `PORT_NATIVE_TRACE` snapshot. It only retains a
pending snapshot sequence, native trace sequence, time, and projected actor there.
It reads actual GameHUD controls in `RenderingServer.frame_post_draw`, after the
HUD's deferred-bound snapshot handler and rendering. When several snapshots
arrive between rendered samples, only the latest is observed; skipped snapshots
are never represented as rendered. Sampling is bounded to roughly 10 Hz, with
new damage events observed immediately on a rendered frame.

The separate `HEALTH_OBSERVE` / `hud_render` record establishes:

- The latest preceding synchronous snapshot and native trace sequence, exact
  independently retained authority actor/time, and strictly increasing rendered
  frame ID. Damage event ID must match the latest native positive damage event.
- Visible GameHUD CanvasLayer, root, vitals, health/armor labels and bars; positive
  widget geometry wholly inside the viewport. Both legacy labels are hidden.
- Exact `HEALTH  <integer>` / `ARMOR  <integer>` texts. Health uses maxHealth;
  armor uses the 100-point reference gauge.
- Gauge values equal clamped authority within Godot Range's **0.01 step** rounding
  (at most 0.005 + 0.00001 floating tolerance). Only step 0 or 0.01 is accepted;
  evidence cannot widen this bound. The first live attempt exposed this widget
  rounding on fractional HP. Full actor/authority comparisons remain exact.
- Actual combat overlay visibility, positive hurt strength and remaining time,
  and the overlay's `draw` signal in the **same** frame as post-draw capture. The
  drawn hurt strength matches the observed overlay strength. The PNG save must
  succeed; image bytes and hashes are retained by the runner.
- Rendered HUD samples in baseline, injured, collected, and returned windows.

All existing normal-source/config/modifier checks, positive nonlethal damage
accounting, strict received-input comparisons, physical native movement, +35 HP,
same pickup/marker identity, exclusive proximity, leaving the pickup radius, and
12-simulation-second return checks remain in force.

## Passing live evidence

[Summary and hashes](evidence/3f0691a0-fe42-4254-a6da-1aa6d07cfcd7/summary.json)
and compressed native/wire streams are in the same directory.

| Witness | Snapshot / render frame | Authoritative HP / armor | Visible result |
|---|---|---|---|
| [Baseline PNG](evidence/3f0691a0-fe42-4254-a6da-1aa6d07cfcd7/baseline.png) | 1 / 19 | 100 / 5 | HEALTH 100, ARMOR 5; gauges 100 / 5 |
| [Hurt PNG](evidence/3f0691a0-fe42-4254-a6da-1aa6d07cfcd7/hurt.png) | 167 / 248 | 100 / 5 | Red edge pulse, strength 0.936508; same-frame draw |
| Injured rendered record | 185 / 261 | 50 / 0 | HEALTH 50, ARMOR 0; gauges 50 / 0; hurt strength 0.605302 |
| [Collected PNG](evidence/3f0691a0-fe42-4254-a6da-1aa6d07cfcd7/collected.png) | 286 / 425 | 85 / 0 | HEALTH 85, ARMOR 0; gauges 85 / 0 |
| Returned rendered record | 649 / 1128 | 85 / 0 | HEALTH 85, ARMOR 0; gauges 85 / 0 |

The first hurt event (ID 4, simulation time 5.583) arrived after the latest
snapshot 167 (time 5.567). Accordingly, the hurt PNG correctly retains that
snapshot's **100/5** HUD while showing the event-driven pulse. It is not relabeled
as a later injured snapshot. Snapshot 185 separately proves simultaneous rendered
**50/0** and positive hurt. All three passing PNGs and the first attempt's hurt
PNG were opened and visually inspected at 1280×800.

Run totals: **669** correlated snapshots, **199** rendered HUD observations,
**1,140** exactly receipt-matched native inputs, five damage events totaling
**55 = 50 HP + 5 armor**, and **122** movement inputs before collection. Health
pickup ID 6 collected at snapshot 286 (time 9.533), raised HP **50 → 85**, hid
the same marker for 360 snapshots, and returned at snapshot 646 (time 21.533).
The pickup event was at 9.517: observed return interval **12.016 seconds**. There
were 340 outside-radius snapshots through return. ACK high-water was 1138.

## Preserved inconclusive attempt and history

The first new attempt is retained **unchanged** at
[2df9b589…](evidence/2df9b589-642a-4a47-8898-1fa7a4cc6a65/summary.json).
It obtained genuine visible fractional-HP and hurt evidence, but the existing
route from spawn `(4,-34)` stalled at `(8,-5.02)` toward waypoint `(8,6)`. It reached
the 8 MB native output cap after 68.683 seconds and remains **INCONCLUSIVE**.
Initial executed observer/analyzer/runner sources are retained in commit
`60880a9`; artifact hashes are checked by the new tests. The subsequent attempt
used a naturally selected spawn `(8,34)` and passed with the existing route
planner. No spawn selection, route-planner fix, actor mutation, or server timing
change was introduced. The only observer adjustment was sampled UI output and
recording the actual gauge step; the analyzer accounts for that bounded rounding.

The original passing health evidence under
`port/native-health-damage/evidence/d06d6f7a-cacd-43a4-8910-97007273dc21/`
and all earlier evidence/docs remain untouched. Reanalysis requires explicit
`--legacy-hud` (API `{hudMode:'legacy'}`), returns
`historical-legacy-text-only`, and sets both `currentHUDProven` and
`legacyVisibilityProven` false. Its strings are real historical text evidence;
the old observer did not record visibility or overlay draw frames. Current
evidence cannot be downgraded to legacy. Default analysis rejects evidence
without current rendered-HUD observations.

`native_pickup_acceptance/audit.mjs` checks actor/pickup/marker authority and does
not claim legacy label visibility; no analogous pickup-analyzer change was needed.

## Commands and integration note

```sh
node --test port/tools/native_health_damage/analyze.test.mjs
node port/tools/native_health_damage/analyze.mjs port/native-hud-acceptance/evidence/3f0691a0-fe42-4254-a6da-1aa6d07cfcd7
node port/tools/native_health_damage/analyze.mjs port/native-health-damage/evidence/d06d6f7a-cacd-43a4-8910-97007273dc21 --legacy-hud

GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules \
node port/tools/native_health_damage/run.mjs
```

[Focused test transcript](offline-tests.tap). Tests include corrupted visibility,
integer values, gauge values/maxima/precision, geometry, missing or misassociated
observations, missing draw/pulse/image, authority accounting, marker replacement,
receipt tails, ongoing attacker fire, preserved failure hashes, and credential
exclusion. Historical source hashes are checked against immutable `fe29ac3`
contents; current executed observer/runner/analyzer hashes match the final files.
Runtime hashes are checked against `fe29ac3`, rather than requiring future runtime
edits to match an old capture.

**Lead integration:** the shared verifier now runs `analyze.test.mjs` and the
original `test.mjs`. The latter explicitly selects legacy text-only analysis;
both suites verify historical source hashes against immutable commits rather
than mutable working files. Current captured harness sources are pinned to
`9a8d59e` (the integrated copy of `1823029`), original harness sources/runtime to `fe29ac3`. This preserves old
commands without treating old hidden-label evidence as current visual acceptance.

## Bounds and limitations

Both runs used a private Xvfb, llvmpipe, dummy audio, isolated project/import and
HOME/XDG data, normal-rate loopback server on port 0, and supported protocol/input
stimulus. Credentials/welcome bodies are excluded by projection and tests. Each
run reaped its native/import/Xvfb children, closed the owned server with zero
sockets, and removed its private temporary directory. The successful native
stderr contained only the unsupported-VSync warning.

This is a focused default-HUD live acceptance on `fe29ac3`, not the full merged
gate, a desktop focus-transition test, or release/export acceptance. The normal
RNG/geometry route can still stall as the retained first attempt demonstrates.
The +35 pickup was below cap; no separate heal-to-cap case was executed.
`completionProven=false` and receipt-not-individual-application remain explicit.
