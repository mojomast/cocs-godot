# Acceptance checkpoint — 2026-10-02

**READY FOR ENGINE.** Full **source-only mission victory** is now observed after
one diagnosed test-controller fix. Native controller behavior, rendered HUD
quality and human balance are not accepted yet. No heavy-slot work was launched.

Evidence root:
`/home/mojo/.tmp-on-disk/cocs-expansion-three-horde-evidence-20261002/`

## Actual source results

| Unique attempt | Result |
|---|---|
| `source-chain-lPeSlp/` | PASS: 23,971 ordinary source input steps, dt=1/60; 399.5167 source seconds in 9.981 wall seconds. Wave 7, stage C, four stations, three lives. |
| `source-boss-UXBKiC/` | FAILED full-victory criterion: 54,000 steps, 900 source seconds in 43.675 wall seconds. Warden defeated, then source timer loss with six enemies alive, 121 kills, zero player deaths, three lives. Retained. |
| `source-boss-6kDcvB/` | **PASS full source victory:** one authorized follow-up attempt; same seed/config, corrected controller target-range preference only. 48,207 steps, 803.45 source seconds / 20.13855 wall seconds, all stations/gates, Warden death and source `mission-won`, 91 kills, zero deaths, three lives. |
| `target-probe-4bdlC7/probe.json` | Focused old-input replay to 552.10s; zero position divergence. Demonstrates visible 294.65m target incorrectly displacing nearer 129.89m target. No completion claim. |
| `targeting-tests-qhqydq7t/` | Exact-geometry regression failed before fix; 3/3 tests pass afterward. |
| `trace-analysis-4ajx7S/`, `trace-analysis-w9unZA/` | Read-only before/after per-wave movement, fire, idle, target, shot, upgrade and summon accounting. |
| `wire-replay-AgNt8f/` | FAILED bounded contract probe: one stale-input reset despite 96.48ms largest arrival gap. An unbounded 16ms timer overproduced against 60Hz source steps. Retained. |
| `wire-replay-XkwcvJ/` | PASS after **fixture-only** ACK-bounded pacing: 600 replayed inputs + neutral cancellation, max ACK 601, 603 source steps / 600 applied, max gap 83.1191ms, no resets/errors. Ten-second Node transport probe, not mission or native acceptance. |
| `source-checks-eao5yg74/node-tests.log` | 27/27 existing Node tests passed: Blackwater source/map/director, upgrades, input FIFO/TTL and transport regressions. |

Each source run retains `result.json` and `inputs-events.jsonl` with keyboard
states, aim/fire, parsed source inputs and source event receipts. Wire probes
retain `result.json`. Prior 2026-10-01 losses were not touched.

Source chain receipt times (seconds): south feeder 24.3167, north feeder 48.7,
upgrade wave 3 index 3 Overshield accepted, stage B 149.35, pump 166.5,
stage C 387.1667, relief valve 399.5167. The extended run accepted the wave-7
Overshield choice at index 2. No source grant of extra health/ammo was scripted.

Actual wave-ten Warden actor **127**: arrival/phase 1 at 853.5; phase 2 at
895.4333; phase 3 at 897.0667; source `death` at 898.35, killer **0**, weapon
**0**, position **[166.4879, 1, 25.5219]** in the death receipt. Final boss HP
0/450. Source `lost` at 900 explicitly says “The clock ran out.” The runner
correctly exits 1 rather than presenting this kill as mission victory.

The one later source attempt **does** emit victory at 803.45s: Warden **91**
arrives/phase 1 at 691.85, phase 2 at 800.30, phase 3 at 802.1667, dies to player
0/pulse weapon 0 at 803.45, and source `mission-won` follows in the same step.
All four stations complete by 429.9833s; B/C arrivals at 137.6667/417.8333s.
Both original offered Overshield choices are accepted (waves 3/7, indices 3/2).
See **`TARGETING_FOLLOWUP.md`** for exact diagnostic coordinates, before/after
counts, limitations, and the preserved negative-before test. This supersedes
only the source full-victory gate, not native or human acceptance.

## Ready commands

Source-only, no engine required (completed; the additional full-run budget has
been consumed, so do not repeat without a new instruction):

```sh
node port/expansion-three/horde/source-journey.mjs chain
node port/expansion-three/horde/source-journey.mjs boss
node port/expansion-three/horde/wire-replay.mjs <source-attempt>/inputs-events.jsonl
```

**After explicit engine grant**, serialize with `LP_NUM_THREADS=1` and use the
pinned Godot 4.5.2 binary. First import/parse under the parent's slot, then:

```sh
LP_NUM_THREADS=1 "$GODOT_BIN" --headless --path godot --script res://tests/horde_expansion/guidance_test.gd
LP_NUM_THREADS=1 "$GODOT_BIN" --headless --path godot --script res://tests/horde/upgrade_selection_test.gd
node port/expansion-three/horde/native-journey.mjs chain
# Inspect the one bounded chain outcome before granting a boss attempt.
node port/expansion-three/horde/native-journey.mjs boss
```

The native runner uses the real local authority, debug disabled, normal wall
clock, unchanged 250ms TTL, source upgrade acknowledgements, input ACKs, all four
station and B/C arrival events, native signs/HUD/gate receipts. It requires a
maximum per-epoch wire gap <=250ms and no active-play stale reset. Chain wall
bound is 660s. Boss wall bound is 950s to allow the existing 900s source limit
to report an honest outcome; the fixture bound is 930s. Processes/listener are
torn down, including a force-kill deadline. No endless reruns.

Rendered journeys are also prepared, **not run**:

```sh
node port/expansion-three/horde/native-journey.mjs chain --rendered
node port/expansion-three/horde/native-journey.mjs chain --rendered --compact
```

These use the production pointer/focus path (headless focus seam disabled), a
focused 1280×800/UI100 or 760×520/UI150 viewport, real native event input and a
two-second readable upgrade-choice delay. Full viewport PNGs are captured on
mission/gate/wave/offer/boss changes. The first 60 wall seconds also capture at
up to 4fps; every frame records actual wall/source time, viewport, UI scale, HUD
text and mission/choice rectangles. `walkthrough.ffconcat` preserves measured
variable durations. Encode only in the granted slot, for example:

```sh
ffmpeg -n -safe 0 -i <attempt>/walkthrough.ffconcat -fps_mode vfr -c:v libx264 -pix_fmt yuv420p <attempt>/walkthrough.mp4
```

Inspect full PNGs at both sizes, not cropped panels. Inspect visible upgrade
descriptions, lock/available/restoring/completed signs, range ring, active progress,
source gate status, vitals/reload and comms. A video of the first minute must be
labeled first-minute automated gameplay, not full chain/boss footage. These
scripts do not establish human feel or hardware/GPU performance.

## Remaining gates

- Engine parse and guidance/upgrade tests; no GDScript runtime claims yet.
- Native chain, hotkey acknowledgement and full boss/victory outcome.
- Both rendered layouts and actual viewport/cadence inspection. Layout code has
  been prepared for compact UI150 but screenshots are still required.
- Parent package closure picks up two new runtime HUD helpers; tests stay excluded.
- Human playability/balance and representative GPU performance remain unmeasured.
