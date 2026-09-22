# Verification evidence — llvmpipe, not hardware

Six benchmark runs: three effects levels × two window sizes, all on the pinned
Godot 4.5.2 Linux binary, native Deathmatch on Prism Foundry with 4 bots, under a
private Xvfb display (`tools/godot-dev/xvfb_run.py`), rendered by the Mesa
**software rasterizer `llvmpipe`**.

These runs exist to prove the benchmark is real and that the quality levels change
the load. **They say nothing about any GPU, including the owner's.** A GPU is
typically one to two orders of magnitude faster; that is precisely why the owner
must run the Windows build.

Reproduce with:

```sh
export GODOT_BIN=/path/to/Godot_v4.5.2-stable_linux.x86_64
node port/native-benchmark/run_benchmark.mjs --level=all --resolution=1280x800 --label=llvmpipe-verified
node port/native-benchmark/run_benchmark.mjs --level=all --resolution=960x640 --label=llvmpipe-verified
node port/native-benchmark/verify_evidence.mjs --require-slower
```

## Results (median / p95 frame time, measured phases only)

| Resolution | Level | median | p95 | frames | draw calls (mean) | particle slots (allocated / drawn) | verdict |
|---|---|---|---|---|---|---|---|
| 1280×800 | Low | 221.9 ms | 420.7 ms | 119 | 1099 | 8,192 / 7,936 | partial (55% control) |
| 1280×800 | High | 304.1 ms | 470.1 ms | 88 | 1206 | 131,072 / 114,688 | partial (43% control) |
| 1280×800 | Extreme | 499.2 ms | 758.2 ms | 55 | 1225 | 1,000,000 / 125,000 | partial (28% control) |
| 960×640 | Low | 154.4 ms | 192.8 ms | 172 | 909 | 8,192 / 5,632 | partial (84% control) |
| 960×640 | High | 244.1 ms | 415.6 ms | 108 | 822 | 131,072 / 86,016 | partial (53% control) |
| 960×640 | Extreme | 575.4 ms | 871.3 ms | 49 | 1184 | 1,000,000 / 593,750 | partial (25% control) |

Comparisons (median frame time, same map / bots / resolution):

| Comparison | 1280×800 | 960×640 |
|---|---|---|
| Low → High | ×1.37 | ×1.58 |
| Low → **Extreme** | **×2.25** (p95 ×1.80) | **×3.73** (p95 ×4.52) |
| High → Extreme | ×1.64 | ×2.36 |

Every run was `complete: true` and passed `validateResult`. The Low → Extreme
comparison is the asserted one (`verify_evidence.mjs --require-slower`): raising
the shared particle pool from 8,192 to 1,000,000 slots costs more than twice the
frame time even on a CPU rasterizer. The measured slowdown is conservative — the
Extreme runs lost input control more often (see below), so they spent *less* time
under particle load than the Low runs.

## Why every run is `partial`, not `usable`

At 2–7 fps the client's own safety rules do real work: a respawn, or a snapshot
gap that trips the staleness watchdog, temporarily withdraws the actor from
control (`controls_seconds` 6.9–23.5 s of the 28 s window). The benchmark reports
that honestly instead of hiding it, which is exactly why `controls_seconds`,
`verdict` and `verdict_reasons` exist. On the owner's GPU at 60+ fps this path is
not expected to trigger, so a hardware run should classify as `usable`; if it does
not, the reasons say why.

## Captures inspected (three per run, all present)

* `*-combat.png` / `*-burst.png` / `*-sustained.png` show the live game with the
  benchmark overlay naming the phase, the seconds left and the effects level, and
  the game HUD matching the JSON (`DEATHS`, health, armour, held weapon, ammo).
* `2026-09-22T17-52-18-837Z-960x640-extreme/…-sustained.png` shows the game's own
  **"CLICK TO PLAY"** pause prompt: at 25% control the actor had just died at
  ~2 fps, and the capture caught the paused state instead of pretending otherwise.
* `2026-09-22T17-49-47-908Z-1280x800-high/…-burst.png` shows a Rail Lance reload
  in progress (`RELOADING 0.2s`) mid-burst, matching `local_weapon_name`.

The captures were taken with the overlay label at the top of the window; the
benchmark logic and every number are unchanged by that presentation-only move.

## Files

```
<stamp>-<resolution>-<level>/result.json            parsed result (authoritative)
<stamp>-<resolution>-<level>/BENCHMARK_RESULT.txt   the printed line, verbatim
<stamp>-<resolution>-<level>/benchmark-*.json|png   the game's own artifacts
<stamp>-<resolution>-<level>/run.log                full console output
matrix-<resolution>-<stamp>.json                    all runs + comparisons
```

`llvmpipe (LLVM 20.1.8, 256 bits)` is recorded in every result's
`environment.adapter`, and `honesty.software_renderer` is `true` in all six.
