# Native motion smoothness evidence

Owner report: "movement appears staggered like its set at something like 15 hertz
or something, so its jumpy, but moving the mouse is perfectly smooth."

Diagnosis: the port-owned native authority stepped the source simulation at 60 Hz
but emitted a full snapshot only on every third tick (20 Hz). The Godot client
applies the authoritative eye pose to `camera.position` only when a snapshot
arrives (`godot/world/session.gd` `on_snapshot`), while yaw/pitch are applied
every render frame, so translation stepped at the snapshot clock and look stayed
smooth.

Fix: the native-arena authority now sends one full protocol-3 snapshot per source
tick (60 Hz). No delta frames, no protocol change, no gameplay change. Client
code and the remote-actor interpolation path are unchanged. The identity-zone
and horde authorities still ship the old every-third-tick cadence and are owned
by their own lanes (see "Cross-lane follow-ups").

## Cadence at the wire (real authority + real WebSocket client)

`measure-wire.mjs` forks `authority-child.mjs` (real generated `prism-foundry`,
real source `Match`), drives ordinary 60 Hz movement input and timestamps every
`snapshot` frame at the socket. CPU is the authority process's own
`process.cpuUsage()` delta over the measured window.

| run | bots | snapshots/s | interval mean | interval p95 | frame bytes | authority CPU |
|---|---|---|---|---|---|---|
| before (`wire-before-bots2.json`) | 2 | 20.147 | 50.052 ms | 64.469 ms | 9653 | 79.251 ms/s |
| after (`wire-after-bots2.json`)   | 2 | 60.000 | 16.713 ms | 19.338 ms | 9752 | 92.478 ms/s |
| before (`wire-before-bots7.json`) | 7 | 20.111 | 50.143 ms | 64.132 ms | 23361 | 150.978 ms/s |
| after (`wire-after-bots7.json`)   | 7 | 60.014 | 16.709 ms | 19.758 ms | 23040 | 168.322 ms/s |

Measured authority CPU delta for 20 Hz -> 60 Hz: **+13.2 ms/s (2 bots)** and
**+17.3 ms/s (7 bots, 8 actors)** = **+1.3% / +1.7% of one core**. The extra
cadence also removed the old 20 Hz timer's interval tail (p95 64 ms -> 19 ms).

Reproduce (repository root, `GODOT_BIN` not needed):

```sh
node port/native-motion-smoothness/measure-wire.mjs --bots=2 --seconds=6
node port/native-motion-smoothness/measure-wire.mjs --bots=7 --seconds=6
```

## Per-snapshot cost

`serialize-cost.mjs` runs the exact pieces the authority executes per snapshot
against a real arena + source `Match`: `match.snapshot()`, full-frame
`JSON.stringify`, the observer `JSON.parse` copy `send()` already performs, and
`structuredClone` of an input frame (reference).

| roster | frame bytes | state | stringify | observer parse | total/snapshot | at 60 Hz |
|---|---|---|---|---|---|---|
| 3 actors | 9895 | 0.018 ms | 0.037 ms | 0.042 ms | 0.097 ms | 5.8 ms/s |
| 8 actors | 24625 | 0.029 ms | 0.084 ms | 0.101 ms | 0.215 ms | 12.9 ms/s |

Worst reviewed roster (botCount 7) costs about 1.3% of one core at 60 Hz, and the
live 8-actor round measured +17.3 ms/s versus the 20 Hz baseline. On an llvmpipe
client that CPU is trivial next to software-rendered frame time: a real
Xvfb/`gl_compatibility` native-DM round (`run-client-trace.mjs --rendering=xvfb`,
`evidence/client-trace-after-xvfb-autostart.jsonl`) measured **91.0 ms/s
authority CPU over a 7.27 s live round** (629 ms user + 34 ms system), the same
as the headless round at the same roster. On that oversubscribed measurement
host (load ~17 on 32 cores) the llvmpipe client itself rendered at roughly 25-30
software frames per second with occasional stalls, so the client drained
snapshots in bursts; that is a renderer/host artifact, and every rendered frame
still received the newest of the 60 Hz snapshots. Loopback bandwidth is ~1.4 MB/s
at the 8-actor frame size, and the outbound limit check still passes. **Chosen
cadence: every tick (60 Hz).** Full `record/serialize` remains in
`evidence/serialize-cost.json`.

## Camera-level trace (real Godot client + real authority)

`run-client-trace.mjs` runs `res://native_arenas/demo.tscn` with `--native-trace`
against a real authority; each trace record is the camera position *after* the
snapshot was applied, timestamped with `Time.get_ticks_usec()`.
`analyze-camera-trace.mjs` turns the JSONL into cadence and step size:

| trace | snapshots | camera update rate | mean camera gap | mean move step |
|---|---|---|---|---|
| `client-trace-before-autostart.jsonl` | 141 over 6.97 s | 20.2 Hz | 49.8 ms | stationary |
| `client-trace-after-autostart.jsonl` | 433 over 7.16 s | 60.5 Hz | 16.6 ms | stationary |
| `client-trace-before-smoke.jsonl` | 7 over 0.26 s | 22.8 Hz | 43.9 ms | 0.305 m |
| `client-trace-after-smoke.jsonl` | 17 over 0.24 s | 59.3 Hz | 14.7 ms | 0.110 m |

The moving trace holds W under the route's own smoke stimulus; before the fix
the camera advanced in ~0.3-0.43 m steps roughly 20 times a second, after it
advances in ~0.11 m steps ~60 times a second (about one source tick of travel).
Rendered frame captures were not taken: the trace samples the exact transform the
renderer consumes, and the route's capture surface belongs to other lanes.

## Optional client-side smoothing: evaluated, **not shipped**

`evaluate-smoothing.mjs` replays the measured authoritative pose timeline at a
60 fps render clock for the shipped direct policy and for a first-order
critically damped catch-up (no extrapolation; zero overshoot measured):

At 60 Hz snapshots (`pose-60hz.jsonl`, mean speed 6.9 m/s):

| policy | per-frame step p99 | per-frame step max | zero-motion frames | added lag to newest pose (mean / p95) | settle after final target |
|---|---|---|---|---|---|
| direct (shipped) | 0.235 m | 0.287 m | 271/480 | 0 | 0 frames |
| catch-up tau=20 ms | 0.171 m | 0.208 m | 218/480 | 0.040 m / 0.111 m (~6 / 16 ms) | 0 frames (17 ms at 20 Hz) |
| catch-up tau=50 ms | 0.152 m | 0.155 m | 143/480 | 0.130 m / 0.366 m (~19 / 53 ms) | 6 frames / 100 ms |

Lag in milliseconds is the measured distance divided by the measured mean speed
(6.9 m/s); overshoot was zero for every policy (critically damped first order).

Decision: **not shipped.** The filter does reduce the residual 60 Hz step size,
but it adds measured input-to-view latency (tau=20 ms costs ~6 ms mean/~16 ms p95
of travel) and it is semantically incompatible with the route contracts this lane
does not own: `godot/native_arenas/demo.gd:239` and
`godot/native_arenas/identity_zone_demo.gd:318` require
`camera.position.is_equal_approx(presentation.eye_position())` at snapshot time,
which is false by construction while a lagging camera is moving. Shipping it
would silently weaken two other routes' smoke acceptance. The primary 60 Hz fix
already removes the reported 20 Hz stepping without any added latency.

## Cross-lane follow-ups (not edited here)

- `port/native-identity-zones/authority.mjs:256` and
  `port/native-horde/authority.mjs:463` still send snapshots every third tick
  (`++ticks % 3 === 0`). The owner's identity-zone and horde routes have the same
  20 Hz translation stepping; the same one-line change applies, with the same
  measured cost envelope. Owned by those lanes.
- The locked source server already defaults to `snapshotHz: 30`
  (`server/room.mjs:90`, rate-only budget drops to 20 Hz above 32 actors), so the
  source routes are less affected; raising it is an upstream change.
- If the route owners ever want local smoothing, tau=20 ms is the measured
  candidate (no overshoot), but the camera-equality contract above must change
  first.

## Reproduce everything

```sh
export GODOT_BIN=/path/to/Godot_v4.5.2-stable_linux.x86_64
node port/native-motion-smoothness/serialize-cost.mjs
node port/native-motion-smoothness/measure-wire.mjs --bots=2 --seconds=6 --pose-out=port/native-motion-smoothness/evidence/pose-60hz.jsonl
node port/native-motion-smoothness/run-client-trace.mjs --mode=smoke --out=/tmp/smoke.jsonl
node port/native-motion-smoothness/run-client-trace.mjs --mode=autostart --run-seconds=10 --out=/tmp/autostart.jsonl
node port/native-motion-smoothness/run-client-trace.mjs --mode=autostart --rendering=xvfb --run-seconds=12 --out=/tmp/xvfb.jsonl
node port/native-motion-smoothness/analyze-camera-trace.mjs <trace.jsonl>...
node port/native-motion-smoothness/evaluate-smoothing.mjs port/native-motion-smoothness/evidence/pose-60hz.jsonl
```

Gate commands and their one-line results are recorded in `evidence/gates.txt`.
