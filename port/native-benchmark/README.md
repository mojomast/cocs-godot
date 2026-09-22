# Native Deathmatch benchmark — owner run sheet and evidence

A bounded, scripted, in-match benchmark for the native Deathmatch route. It plays
a fixed 33-second sequence through the same input path a human uses (warm-up,
steady combat, a grenade/launcher burst, then sustained fire and movement),
measures the real render cadence, and prints one greppable result line.

**Every performance number already in this repository was measured on the Linux
software rasterizer `llvmpipe`. Those are not hardware figures.** They prove the
code paths run and that Low/High/Extreme change the load, not what the game costs
on a GPU. Only a run on the owner's machine says anything about the owner's machine.

## Windows: measure the extracted build

Open a Command Prompt **in the extracted folder** (the one containing `Play.cmd`)
and run:

```bat
set COCS_BENCHMARK=1
set COCS_BENCHMARK_LEVEL=high
Play.cmd --experience=native-dm --map=prism-foundry --bots=4 --round-seconds=180
```

* `set COCS_BENCHMARK=1` arms the benchmark for this console only. Clear it with
  `set COCS_BENCHMARK=` when you are done.
* `set COCS_BENCHMARK_LEVEL=low|high|extreme` is optional and picks the effects
  level that gets measured (default `high`). Measure each level you care about by
  re-running with a different value; keep everything else identical.
* `Play.cmd` starts its own **local loopback authority** (the bundled Node) and
  cleans it up on exit. No internet, account, editor or Node install is needed.
* The benchmark starts the Deathmatch match itself, waits for the round to go
  live, then runs. **Do not click or press keys during the run** — the scripted
  sequence is driving the player. The window only has to stay focused. If focus is
  lost the actor stops being controlled and the result is marked
  `partial`/`unusable` instead of pretending to be a benchmark.

After roughly 40 seconds the game prints the result and closes:

```
BENCHMARK_RESULT {"schema":1,"tool":"cocs-native-benchmark", ... }
BENCHMARK_ARTIFACTS {"json":"...","written":true,"captures":["..."]}
```

It also writes, next to the build:

```
benchmark-results\benchmark-<timestamp>.json     full result (same data as the printed line)
benchmark-results\benchmark-<timestamp>-combat.png
benchmark-results\benchmark-<timestamp>-burst.png
benchmark-results\benchmark-<timestamp>-sustained.png
```

### Variants worth measuring

```bat
:: heavier combat: more bots, same everything else
Play.cmd --experience=native-dm --map=prism-foundry --bots=6 --round-seconds=180

:: a second map, for map-to-map differences
Play.cmd --experience=native-dm --map=aurora-basin --bots=4 --round-seconds=180

:: the level you actually play at
set COCS_BENCHMARK_LEVEL=extreme
Play.cmd --experience=native-dm --map=prism-foundry --bots=4 --round-seconds=180
```

In-game alternatives, once a match is running: **F7** starts the same 33-second
benchmark without leaving the session (results are printed and saved; the session
stays open, unlike the environment-variable run which exits when finished), and
**F9** cycles Low → High → Extreme. Extreme is never hidden or capped: a fast
machine is expected to select it.

## What to paste back to the lead

1. The **complete `BENCHMARK_RESULT` line** (one line, exactly as printed). That
   is the measurement.
2. Which level it was (`quality.name` is inside the line) and anything unusual
   you saw during the run (a stall, a window popping up, focus loss).
3. If convenient: `benchmark-results\benchmark-<timestamp>.json` and the three
   PNGs from the same run.

If the line says `"verdict":"partial"` or `"unusable"`, paste it anyway — the
`verdict_reasons` field says what invalidated the run, and re-running is usually
enough.

## What each number means

| Field | Meaning |
|---|---|
| `aggregate.median_ms` / `p95_ms` / `max_ms` | Wall-clock frame time over the three measured phases. Intervals are taken between real `RenderingServer.frame_post_draw` events, so display buffering is included. p95 = 95th percentile: one frame in twenty is worse than this. |
| `aggregate.samples`, `engine.render_frames` | How many frame intervals the numbers are built from. A handful of samples (a very slow level) makes median/p95 coarse but still honest. |
| `phases[]` | The same statistics per phase. `warmup` is measured but excluded from `aggregate` (it contains shader compilation and pool allocation). |
| `controls_seconds` / `measured_seconds` | How much of the measured window the scripted input was actually in control of the actor. Less than 95% means deaths or lost focus lowered the effect load. |
| `quality.name`, `quality.levels_seen`, `quality.per_phase` | The effects level that was measured. More than one entry in `levels_seen` means someone pressed F9 during the run. |
| `engine.draw_calls_mean` / `draw_calls_max` | Engine draw calls and primitives for the visible pass, from the viewport render info (the GL compatibility renderer does not fill the `Performance` monitors; a `0` means the engine did not report it). |
| `particles.allocated_slots` / `draw_slots` / `active_emitters` | Submitted particle capacity and how much of it was live, not a count of visible pixels. High allocates 131,072 slots on native arenas, Extreme raises the pool to 1,000,000. |
| `scene.actor_count`, `scene.bots`, `scene.map` | The load composition: total actors (you plus bots) and the map. |
| `combat.*` | Real activity observed during the run: shots, explosions, launches, damage taken/given, local deaths, and the weapon/ammo actually held at the end. |
| `window.size`, `window.viewport_size`, `window.scaling_3d` | The resolution actually rendered. Compare only equal resolutions. |
| `environment.adapter`, `renderer_method`, `renderer_driver`, `os`, `cpu`, `max_fps`, `vsync_*` | What rendered the frames. The benchmark disables vsync while measuring and restores the previous mode afterwards, so frame times are not silently clamped to the display refresh. |
| `verdict` / `verdict_reasons` | `usable` = complete, controlled and uncapped; `partial` = complete but capped or partly uncontrolled (deaths/respawn/lost focus — still the measurement you asked for); `unusable` = the sequence did not finish or the window had neither input control nor combat activity. |
| `honesty.software_renderer` | `true` on `llvmpipe`/`lavapipe`/SwiftShader and friends: the numbers came from a CPU rasterizer and are not hardware figures. |
| `recommendation.*` | The preset the measured p95 supports, the level it was measured at, and the thresholds used. `applied_level` records what the benchmark set after it stopped measuring; the printed numbers are always measured **before** that. |

## Choosing the effects preset from a measurement

`godot/world/combat_quality.gd` maps a measured p95 frame time to a level:

| Measured p95 | Preset | Why |
|---|---|---|
| ≤ 8.3 ms | **Extreme** | Inside a 120 Hz budget even with the million-slot pool. |
| ≤ 16.7 ms | **High** | Holds a 60 Hz budget. |
| > 16.7 ms | **Low** | The measured load already misses 60 Hz. |

The mapping is only a starting point: it is derived from the frame time at the
level that was measured, so re-run the benchmark at the recommended level to
confirm it. `apply_recommended(frame_ms)` applies it programmatically,
`Quality.recommended_level(frame_ms)` returns the index, and F9 still cycles
every level by hand.

### API for the HUD / UI lane

`godot/world/combat_quality.gd` owns the in-match surface; the HUD only has to
display it. Nothing in `godot/ui/` is required for the benchmark to work.

```gdscript
quality.request_benchmark(false)      # -> bool; false when one is already running
quality.benchmark_active()            # -> bool
quality.benchmark_summary             # last run: p95_ms, median_ms, samples,
                                      #   measured_level, recommended, complete, verdict
quality.benchmark_finished            # signal(summary)
quality.recommended_level(frame_ms)   # -> 0 Low | 1 High | 2 Extreme
quality.recommendation_for(p95_ms, measured_level)   # -> Dictionary for display
quality.apply_recommended(frame_ms)   # -> applied level index
```

Suggested keybind: **F7** (already handled by `combat_quality._unhandled_input`
during a live match and listed in its own hint line). A HUD hint such as
`F7 benchmark · F9 quality · F10 metrics` is welcome but optional, and F7 must not
be claimed by another action.

## If something goes wrong

| Symptom | Cause and fix |
|---|---|
| No `BENCHMARK_RESULT` line at all | `set COCS_BENCHMARK=1` must be set in the **same** console that launches `Play.cmd`. Look for `BENCHMARK_REFUSED` or `BENCHMARK_WAITING` in the output — they name the reason. |
| `BENCHMARK_REFUSED ... the window never became focused` | The game window must have keyboard focus. Click it, do not minimize it, and rerun. |
| `verdict":"partial"` / `"unusable"` | Read `verdict_reasons`: vsync could not be disabled, the round ended early (rerun with the default `--round-seconds=180`), the window lost focus, or too many deaths interrupted the scripted input. Re-running is usually enough. |
| `Unknown launcher option: --benchmark` | Only the environment variable arms the packaged launcher. Do not add `--benchmark` to `Play.cmd`; pass it only when launching the Godot executable directly (the Linux runner does). |
| Left armed by accident | `set COCS_BENCHMARK=` (empty) in that console, or open a new one. |
| Level does not match what was requested | `quality.name` in the result is the level that was actually measured; `quality.levels_seen` lists every level seen, so an accidental F9 press is visible. |

The printed line is long on purpose: it is the whole result, one line, so it can
be pasted without losing fields. In-game the benchmark shows one overlay label
below the effects hint: the phase, the seconds left in the 33-second plan and the
effects level being measured.

## Linux / CI: reproduce and verify

```sh
export GODOT_BIN=/path/to/Godot_v4.5.2-stable_linux.x86_64
node port/native-benchmark/run_benchmark.mjs --level=all --resolution=1280x800
node port/native-benchmark/run_benchmark.mjs --level=all --resolution=960x640
```

The runner owns a loopback authority on an ephemeral port, runs the pinned Godot
client under a private Xvfb display (`tools/godot-dev/xvfb_run.py`), and writes
per-run evidence into `port/native-benchmark/evidence/`:

```
<stamp>-<resolution>-<level>/result.json             the parsed result
<stamp>-<resolution>-<level>/BENCHMARK_RESULT.txt    the printed line, verbatim
<stamp>-<resolution>-<level>/run.log                 the full console output
<stamp>-<resolution>-<level>/benchmark-*.json|png    the game's own artifacts
matrix-<resolution>-<stamp>.json                     all runs plus the level comparisons
```

Gates:

```sh
$GODOT_BIN --headless --path godot --script res://tests/benchmark/contracts.gd
node --test port/native-benchmark/test.mjs
```

`contracts.gd` covers the plan's bounds and purity, the frame statistics, the
honesty classification, the preset API and the unchanged F7/F9/F10 keys.
`test.mjs` covers the result parser, the "software is not hardware" caveat and
the level comparison. `verify_evidence.mjs --require-slower` re-checks the
committed matrices; see [evidence/README.md](evidence/README.md) for the verified
llvmpipe numbers and what was inspected by hand.

## Honest limits

* The measured cadence includes the platform's display path, so it is what the
  player sees, not a GPU timestamp or a pure compute profile.
* `draw_calls`/`primitives` are engine counters, not vendor profiling data.
* Particle numbers are submitted capacity; a faded or occluded particle still
  costs simulation even when no pixel changes.
* The scripted sequence covers movement, sustained fire, grenades, bot combat and
  the world-particle load. It does not cover audio load, input latency, alt-tab
  behaviour, long-session thermals or every map.
* Inputs are scripted but combat is not: bots, spawns, deaths and pickup luck vary
  between runs, so compare the *levels* rather than two single runs. The `combat`
  block reports the activity that actually happened, so a reader can see whether
  two runs were comparable.
* `verdict` is derived, not asserted: a run that lost input control for part of
  its window is reported as `partial`, and one that never had control or activity
  at all as `unusable`, even when the JSON looks complete.
* Software-renderer runs (`llvmpipe`) in this repository are load-change proof and
  regression evidence only. Never quote them as the owner's performance.

## Lead verification (post-lane)

- `res://tests/benchmark/contracts.gd` — **158 checks, 0 failures** (re-run by lead).
- `node --test port/native-benchmark/test.mjs` — pass (re-run by lead).
- Both are now registered in `tools/godot-dev/verify.py` as `benchmark-contracts` and
  `benchmark-tools`, so they run in the aggregate sweep.
- Reported llvmpipe separation is real and monotonic: Low 221.9 ms / High 304.1 ms /
  Extreme 499.2 ms at 1280x800 (x2.25), and 154.4 / 244.1 / 575.4 ms at 960x640 (x3.73).
  Those are software-renderer figures and are not hardware claims.
- F7 is claimed by the benchmark; the UI lane was told so it does not bind it.
- Adding `--benchmark` to the packaged launchers remains lead-owned routing.
