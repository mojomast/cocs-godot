# Independent sports victory and local-goal acceptance

Runtime: `8a58c97` (delivery `33f5257`). Pinned engine/source and complete input
manifests are recorded with each run. No physics, authority state, clock or seed
changes were used. Driving came through native Godot input events on normal-rate
owned servers; these are input-path milestones, not human-controller acceptance.

## Ion: one-lap target victory and restart

```sh
PORT=0 TMPDIR=/tmp/opencode python3 -B port/native-sports-victory/run.py --race
```

[Run `dea1d370-7fba-4280-8e4c-8e06850b9159`](../../native-sports-victory/evidence/dea1d370-7fba-4280-8e4c-8e06850b9159/summary.json):
all 185 focused checks pass, plus two real graphical cases.

| Native size | Source finish | Input receipts | Neutral restart receipts | Fresh displacement at capture |
|---|---:|---:|---:|---:|
| 960×640 | 43.028 s | 1,123 | 101 | 6.367 m |
| 1280×800 | 43.129 s | 1,035 | 89 | 6.175 m |

Both cross gates `0..16,0`, emit `race-finish` for local actor 0, and reach
`winnerId:0` with one completed lap before the 180-second clock expires.
Both pass F5 cleanup, held-W blocking, Enter-only neutrality and fresh-W movement.
ACK advances from 100→123 / 88→107 alongside observed position changes.
Source/wall rates are 1.0030 / 0.9920; no accelerated simulation.

Directly opened both `results.png`, small `restart-enter-neutral.png`, and large
`restart-fresh-driving.png`. Victory panels fit, read “Lap target reached” and
“#1 You”, and clearly explain restart. Neutral restart shows 0.0 m/s; fresh input
shows 11.1 m/s. Results retain the last authoritative speed, not resumed driving.

## Aurora: genuine local goal in ordinary 2v2

```sh
PORT=0 TMPDIR=/tmp/opencode python3 -B port/native-sports-victory/run.py --attempt 1
```

[Run `9c72f6c8-6b15-4a90-a7b3-11c64c68c7f8`](../../native-sports-victory/evidence/9c72f6c8-6b15-4a90-a7b3-11c64c68c7f8/summary.json):
first independent bounded attempt succeeds; no second attempt needed.

- Source event **5**, match time **141.867 s** / playing elapsed **138.867 s**,
  owned-server wall **144.975 s**. Human Red actor **0** scores at Blue's goal
  `(44,0)`; this is not an own goal or bot goal.
- Snapshot **4254→4258**, ACK **3102→3105**: Red **0→1**, Blue remains **0**,
  local credited goals **0→1**; ball resets exactly to `(0,1.1,0)` at zero velocity.
- **3,127** input arrivals; ten ordinary driving recoveries. The run stops after
  the local notification at wall 146.287 s, below its 175-second bound.
- Directly opened `driving.png` and `end.png`: actionable shot coaching, correct
  OWN/ATTACK roles, **Red 1 / Blue 0**, “Red GOAL · Ball reset to centre” and
  released controls. The ball is behind the camera after resetting; source
  snapshots establish its exact reset position.
- Effective public roster remains one human and three bots. The source forces
  soccer to four players even when `botCount:0` was requested. Solo practice is
  unavailable. The new coaching row does not change game rules or steer the car.

The agent's separate 960×640 `guidance.png` was also directly opened and reviewed;
it fits the complete coaching row. That stationary capture is retained agent
evidence, not a second independent local-goal attempt.

## Audit and cleanup

```sh
python3 -B port/native-sports-victory/audit.py \
  --output port/reports/sports-victory-independent/audit.json
```

[Audit](audit.json): five runs / eight native cases across delivery and lead
verification; **two scoring attempts, two local goals, seven bot goals, zero
local own goals**. Original failed older attempts remain in their original
directories and are not reclassified. Production/source hash differences: zero.
Every owned process is reaped, server sockets close and private projects are
removed. The original agent audit remains untouched; the new optional output
argument allows independent audits without overwriting it.

Audit SHA-256:
`48aff1770d661906653375a431589424927bd34d819b8c770642313b91eea04e`.

The Linux package was rebuilt with this runtime; fresh extraction and exported
setup/combat/world plus failure cleanup pass in
[`linux-sports-world-independent`](../linux-sports-world-independent/).
That package check does not replay the sports victories in a release export.
Human audio, camera usability, hardware/Wayland and longer sports matches remain
separate checks. Campaign implementation remains deferred for planning.
