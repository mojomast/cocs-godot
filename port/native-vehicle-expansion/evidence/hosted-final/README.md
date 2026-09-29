# Hosted crew fixture repair — 2026-09-29

Base: `593a68dd` (runtime/package base `156cd370`). Changes are confined to the
three-client runner, observation script and validator. These are local Linux
software-rendering results; remote CI still needs to execute the repair.

## Diagnosis and repair

- CI `36565120535` host tail repeatedly reports W-down but queues zero X/Z at
  ACK 42–71. The controls retain a held-key record after releasing movement;
  another down cannot rearm it. The fixture now sends physical W-up before
  W-down when W is absent from the active keys. No control fields are assigned.
- Three renderers use `LP_NUM_THREADS=1`, 640×360 windows and a 30 FPS cap.
  Both retained runs constrain the complete runner and all children to CPUs
  0 and 1. Source Room timing remains unchanged.
- X11 handoff waits for a receipt written only after the previous rider's
  physical Esc has been consumed, controls are disengaged and capture is
  visible. Receipts live in the isolated temporary directory. Source vehicle,
  seat and shot observations remain prerequisites for advancing.
- The observation node runs immediately after Demo's process callback and
  before its network child polls the next snapshot. Previously the SceneTree
  callback compared the previous camera with newer actor state. The exact
  source/root and camera-distance assertions are unchanged.
- Completion requires twelve mounted frames overlapping the passive wire
  witness's existing sampling rule. The validator still independently checks
  all source/native correlations, camera, hands, seats, shots and brake edge.

## Retained passing runs

| Run | Total seconds | Host / gunner / passenger correlations | Mounted samples | Hull displacement | Shared hull snapshots | Brake edges |
| --- | ---: | --- | --- | ---: | ---: | ---: |
| `two-cpu` | 101.13 | 128 / 80 / 92 | 119 / 21 / 12 | 27.791 m | 55 | 1 |
| `two-cpu-held-release` | 102.42 | 104 / 72 / 93 | 100 / 22 / 12 | 27.832 m | 57 | 1 |

Commands from this worktree:

```sh
taskset -c 0,1 python3 port/native-vehicle-expansion/run.py
VEHICLE_RECOVER_HELD_INPUT=1 taskset -c 0,1 python3 port/native-vehicle-expansion/run.py
```

The probe presses physical Esc during each rider's walk while W is held.
On the next frame the independent validator requires a retained W-down,
inactive W and disengaged controls, followed by successful natural boarding
and completion. All three native clients render, walk from source spawn,
occupy the same Puma and send their own wire inputs. Gunner vehicle fire,
passenger personal fire, driver travel and exactly one held-Space brake edge
all pass. Both runs pass controls, fleet, shared shots, source and Room edge
oracles; all owned processes are reaped and private copies removed.

`summary.json` indexes SHA-256 and byte counts of the full logs and compressed
wire evidence retained at its absolute `evidence` path. `hashes.json` records
source/native bytes. Earlier exploratory failures remain in
`/tmp/opencode/crew-final-2cpu*.log` and their indexed raw evidence directories:
insufficient mounted correlations, probe logging before buffered input was
consumed, X11 NO GRAB, crew wait/death, and mismatched camera sampling. These
were not accepted as passes. The earlier 5 FPS result has not been rerun and
is not claimed green.
