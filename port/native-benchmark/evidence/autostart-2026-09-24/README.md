# Autostart repair evidence — 2026-09-24

Owner report: the documented env-armed benchmark run parked at the native setup
screen ("stuck at the menu with the game settings"), while pressing **F7** in a
live match produced a result.

## Root cause

The native route never honoured the documented benchmark arming itself:
`godot/native_arenas/demo.gd` derived `auto_start` only from `--autostart`/`--smoke`,
so the only node that could start an env-armed match was the benchmark driver's
one-shot `_autostart_step()` — a passenger created as a side effect of the combat
composition. When that step did not fire, the run parked at the setup HUD and the
console only repeated the wait reason:

```
BENCHMARK_WAITING the match has not been started yet (native setup phase -2)
BENCHMARK_REFUSED the authoritative round did not become controllable within 30 seconds
```

Fix (commit on `lane/benchmark-autostart`): `demo.gd` derives `auto_start` from
`launch_starts_match()`, true for `--autostart`/`--smoke` **or** the documented
benchmark arming (`COCS_BENCHMARK=1`, or `--benchmark` in the session user args),
and prints `BENCHMARK_AUTOSTART ... source=native-route`. Interactive launches and
F7 are unchanged; the driver's autostart remains the fallback for a session route
that does not start itself.

## Reported symptom, reproduced under a controlled probe

`park-probe.patch` disables the driver's autostart step in a scratch checkout at
HEAD (`if true: return false` at the top of `_autostart_step`), i.e. the "driver
arms but its autostart step never fires" candidate. Both runs use the documented
run-sheet composition, env-only arming, a private Xvfb and llvmpipe.

| Probe run | `demo.gd` | Result |
|---|---|---|
| `park-probe-before-fix.log` | HEAD | parks at the setup screen; 6 × `BENCHMARK_WAITING ... (native setup phase -2)`, then `BENCHMARK_REFUSED ...`; exit 1, incomplete result with 0 samples |
| `park-probe-after-fix.log` | fixed | `BENCHMARK_AUTOSTART ... source=native-route` at once, complete `BENCHMARK_RESULT`, exit 0 |

Honest note: the **unmodified** native route does not park in this checkout,
because the driver's autostart happens to fire — that is why the run sheet ever
worked (`pre-fix-armed-driver-autostart.log`). The other half of the field report
is an environment that never reaches the game process at all (for example `set`
typed in PowerShell, where it creates a PowerShell variable, not an environment
variable); the run sheet now documents the `$env:` form.

## Recorded runs (llvmpipe, private Xvfb)

* `run-sheet-armed-prism-foundry.log` — the run-sheet command through the dev
  launcher, environment only: `COCS_BENCHMARK=1 COCS_BENCHMARK_LEVEL=high
  node tools/godot-dev/launch.mjs --experience=native-dm --map=prism-foundry
  --bots=4 --round-seconds=180`. Route marker, complete result, exit 0.
* `run-sheet-armed-aurora-basin-bots6.log` — the same, variant
  `--map=aurora-basin --bots=6`.
* `gate-all.log` — the registerable gate command
  `node port/native-benchmark/run_benchmark.mjs --gate=all --resolution=1280x800
  --out=/tmp/opencode/benchmark-autostart-gate`: both `BENCHMARK_GATE_OK` lines
  (armed run measured and validated; un-armed run printed no benchmark marker),
  exit 0, no engine errors. `gate-autostart-result.json` / `.txt` are that run's
  parsed result and printed line.
* `f7-rendered.log` — no arming at all; the match starts via `--autostart`, an
  XTEST F7 press in the focused window starts the interactive benchmark, the
  result prints and the game stays open (`F7_CHECK` all true).
* `pre-fix-armed-driver-autostart.log` — pristine HEAD, env-only: the driver
  performs the autostart (marker has no `source=`), which the fix no longer
  depends on.

These are software-renderer figures and prove code paths only, never hardware
performance.

## Reproduce

```sh
export GODOT_BIN=/path/to/Godot_v4.5.2-stable_linux.x86_64
node port/native-benchmark/run_benchmark.mjs --gate=all --resolution=1280x800 \
  --out=/tmp/opencode/benchmark-autostart-gate
```
